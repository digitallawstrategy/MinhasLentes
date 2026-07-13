import Foundation
import SwiftData
import WidgetKit

/// Regras de negócio do estoque de lentes — caixas compradas e guardadas, distintas dos pares
/// em uso (`LensPair`). Ao contrário de `LensCaseService`/`CleaningSolutionService`, vários
/// itens podem estar `.available` ao mesmo tempo: não há "só um ativo por vez" aqui.
@MainActor
enum LensInventoryService {

    enum ServiceError: LocalizedError {
        case persistenceFailed(String)
        case notificationSchedulingFailed(String)
        case invalidQuantities
        case insufficientStock(String)

        var errorDescription: String? {
            switch self {
            case .persistenceFailed(let detail):
                return "Não foi possível salvar o item do estoque. \(detail)"
            case .notificationSchedulingFailed(let detail):
                return "O item foi registrado, mas não foi possível agendar as notificações. \(detail)"
            case .invalidQuantities:
                return "A quantidade restante não pode ser maior que a quantidade total."
            case .insufficientStock(let detail):
                return "Estoque insuficiente em \(detail)."
            }
        }
    }

    static func allItems(context: ModelContext) throws -> [LensInventoryItem] {
        let descriptor = FetchDescriptor<LensInventoryItem>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        do {
            return try context.fetch(descriptor)
        } catch {
            throw ServiceError.persistenceFailed(error.localizedDescription)
        }
    }

    /// Itens com quantidade restante para oferecer como opção ao iniciar um novo par — nunca
    /// inclui itens esgotados, mesmo que ainda existam no histórico.
    static func availableItems(context: ModelContext) throws -> [LensInventoryItem] {
        try allItems(context: context).filter { $0.status == .available && $0.remainingQuantity > 0 }
    }

    private static func save(context: ModelContext) throws {
        do {
            try context.save()
        } catch {
            do {
                try context.save()
            } catch {
                throw ServiceError.persistenceFailed(error.localizedDescription)
            }
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    @discardableResult
    static func addItem(
        brand: String,
        model: String,
        prescriptionOD: String?,
        prescriptionOS: String?,
        side: LensSide,
        lot: String?,
        expiryDate: Date?,
        initialQuantity: Int,
        photoData: Data?,
        notes: String?,
        settings: AppSettings,
        context: ModelContext
    ) async throws -> LensInventoryItem {
        let item = LensInventoryItem(
            brand: brand, model: model, prescriptionOD: prescriptionOD, prescriptionOS: prescriptionOS,
            side: side, lot: lot, expiryDate: expiryDate, initialQuantity: max(1, initialQuantity),
            photoData: photoData, notes: notes
        )
        context.insert(item)
        logEvent(
            .inventoryItemAdded,
            date: Date(),
            descriptionText: "\(brand) \(model) adicionado ao estoque (\(Pluralization.count(item.initialQuantity, "unidade", "unidades"))).",
            context: context
        )
        try save(context: context)

        do {
            try await NotificationManager.shared.scheduleLensInventoryNotifications(for: item, settings: settings)
        } catch NotificationManager.NotificationError.authorizationDenied {
            // Usuário ainda não autorizou notificações; o item permanece salvo normalmente.
        } catch {
            let failureEvent = HistoryEvent(
                eventType: .settingsChanged,
                eventDate: Date(),
                descriptionText: "Falha ao agendar notificações do estoque: \(error.localizedDescription)"
            )
            context.insert(failureEvent)
            try? context.save()
            throw ServiceError.notificationSchedulingFailed(error.localizedDescription)
        }

        return item
    }

    /// `initialQuantity` e `remainingQuantity` são ambas editáveis (corrigir a quantidade total
    /// comprada, não só quanto resta) — mas nunca de forma independente o bastante para produzir
    /// um estado impossível como "5 de 1": valida `remainingQuantity <= initialQuantity` antes de
    /// gravar qualquer coisa, e lança `.invalidQuantities` em vez de aceitar silenciosamente.
    static func editItem(
        _ item: LensInventoryItem,
        brand: String,
        model: String,
        prescriptionOD: String?,
        prescriptionOS: String?,
        side: LensSide,
        lot: String?,
        expiryDate: Date?,
        initialQuantity: Int,
        remainingQuantity: Int,
        photoData: Data?,
        notes: String?,
        settings: AppSettings,
        context: ModelContext
    ) async throws {
        let clampedInitial = max(1, initialQuantity)
        guard remainingQuantity >= 0, remainingQuantity <= clampedInitial else {
            throw ServiceError.invalidQuantities
        }
        item.brand = brand
        item.model = model
        item.prescriptionOD = prescriptionOD
        item.prescriptionOS = prescriptionOS
        item.side = side
        item.lot = lot
        item.expiryDate = expiryDate
        item.initialQuantity = clampedInitial
        item.remainingQuantity = remainingQuantity
        item.photoData = photoData
        item.notes = notes
        if item.remainingQuantity == 0 {
            item.status = .exhausted
        } else if item.status == .exhausted {
            item.status = .available
        }
        logEvent(.inventoryItemEdited, date: Date(), descriptionText: "\(brand) \(model) editado no estoque.", context: context)
        try save(context: context)

        await NotificationManager.shared.cancelLensInventoryNotifications(for: item.id)
        guard item.status == .available else { return }
        do {
            try await NotificationManager.shared.scheduleLensInventoryNotifications(for: item, settings: settings)
        } catch NotificationManager.NotificationError.authorizationDenied {
            // Usuário ainda não autorizou notificações; a edição permanece salva normalmente.
        } catch {
            let failureEvent = HistoryEvent(
                eventType: .settingsChanged,
                eventDate: Date(),
                descriptionText: "Falha ao reagendar notificações do estoque: \(error.localizedDescription)"
            )
            context.insert(failureEvent)
            try? context.save()
            throw ServiceError.notificationSchedulingFailed(error.localizedDescription)
        }
    }

    /// Corrige, de forma idempotente, itens com `remainingQuantity > initialQuantity` gravados
    /// antes da validação em `editItem` existir — nunca deveria acontecer daqui em diante, mas
    /// dados antigos podem estar assim. Chamado a cada reconciliação de notificações
    /// (`NotificationReconciliationService.rebuildAll`), então roda de novo a cada abertura ou
    /// retorno de foreground do app, sem custo perceptível quando não há nada para corrigir.
    @discardableResult
    static func repairInvalidQuantities(context: ModelContext) throws -> Int {
        let items = try allItems(context: context).filter { $0.remainingQuantity > $0.initialQuantity }
        guard !items.isEmpty else { return 0 }
        for item in items {
            item.remainingQuantity = item.initialQuantity
        }
        logEvent(
            .inventoryItemEdited,
            date: Date(),
            descriptionText: items.count == 1
                ? "1 item do estoque com quantidade inconsistente foi corrigido automaticamente."
                : "\(items.count) itens do estoque com quantidade inconsistente foram corrigidos automaticamente.",
            context: context
        )
        try save(context: context)
        return items.count
    }

    static func deleteItem(_ item: LensInventoryItem, context: ModelContext) async throws {
        let label = "\(item.brand) \(item.model)"
        let id = item.id
        context.delete(item)
        logEvent(.inventoryItemDeleted, date: Date(), descriptionText: "\(label) excluído do estoque.", context: context)
        try save(context: context)
        await NotificationManager.shared.cancelLensInventoryNotifications(for: id)
    }

    struct ConsumptionSelection {
        let item: LensInventoryItem
        let quantity: Int
    }

    /// Desconta uma ou duas seleções do estoque ao iniciar um par — uma seleção por olho quando
    /// são caixas separadas (OD + OE), ou uma seleção só com `quantity: 2` quando uma única caixa
    /// `.both` supre os dois olhos. Tudo ou nada: valida o saldo de TODAS as seleções antes de
    /// decrementar qualquer uma, para que uma seleção com saldo insuficiente nunca deixe a outra
    /// parcialmente consumida. Ao chegar a zero, marca o item como esgotado e cancela os avisos
    /// de validade pendentes (uma lente esgotada não precisa mais de aviso de vencimento).
    static func consume(
        selections: [ConsumptionSelection],
        forPairNamed pairName: String,
        context: ModelContext
    ) async throws {
        guard !selections.isEmpty else { return }
        for selection in selections {
            guard selection.item.remainingQuantity >= selection.quantity else {
                throw ServiceError.insufficientStock("\(selection.item.brand) \(selection.item.model)")
            }
        }

        var newlyExhaustedIDs: [UUID] = []
        for selection in selections {
            let item = selection.item
            item.remainingQuantity -= selection.quantity
            let verb = Pluralization.word(selection.quantity, "usada", "usadas")
            logEvent(
                .inventoryItemUsed,
                date: Date(),
                descriptionText: "\(Pluralization.count(selection.quantity, "unidade", "unidades")) de \(item.brand) \(item.model) \(verb) para iniciar \(pairName). Restam \(item.remainingQuantity).",
                context: context
            )
            if item.remainingQuantity == 0 {
                item.status = .exhausted
                newlyExhaustedIDs.append(item.id)
                logEvent(
                    .inventoryItemExhausted,
                    date: Date(),
                    descriptionText: "\(item.brand) \(item.model) esgotado no estoque.",
                    context: context
                )
            }
        }
        try save(context: context)
        for id in newlyExhaustedIDs {
            await NotificationManager.shared.cancelLensInventoryNotifications(for: id)
        }
    }

    /// Wrapper de compatibilidade — desconta 1 unidade de um único item, mesmo comportamento de
    /// antes de `consume(selections:forPairNamed:context:)` existir (o caso geral, usado quando
    /// um par de dois olhos consome de duas caixas ou de duas unidades da mesma caixa `.both`).
    static func consumeOne(_ item: LensInventoryItem, forPairNamed pairName: String, context: ModelContext) async throws {
        guard item.remainingQuantity > 0 else { return }
        try await consume(selections: [ConsumptionSelection(item: item, quantity: 1)], forPairNamed: pairName, context: context)
    }

    private static func logEvent(_ type: HistoryEventType, date: Date, descriptionText: String, context: ModelContext) {
        let event = HistoryEvent(eventType: type, eventDate: date, descriptionText: descriptionText)
        context.insert(event)
    }
}
