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

        var errorDescription: String? {
            switch self {
            case .persistenceFailed(let detail):
                return "Não foi possível salvar o item do estoque. \(detail)"
            case .notificationSchedulingFailed(let detail):
                return "O item foi registrado, mas não foi possível agendar as notificações. \(detail)"
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

    static func editItem(
        _ item: LensInventoryItem,
        brand: String,
        model: String,
        prescriptionOD: String?,
        prescriptionOS: String?,
        side: LensSide,
        lot: String?,
        expiryDate: Date?,
        remainingQuantity: Int,
        photoData: Data?,
        notes: String?,
        settings: AppSettings,
        context: ModelContext
    ) async throws {
        item.brand = brand
        item.model = model
        item.prescriptionOD = prescriptionOD
        item.prescriptionOS = prescriptionOS
        item.side = side
        item.lot = lot
        item.expiryDate = expiryDate
        item.remainingQuantity = max(0, remainingQuantity)
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

    static func deleteItem(_ item: LensInventoryItem, context: ModelContext) async throws {
        let label = "\(item.brand) \(item.model)"
        let id = item.id
        context.delete(item)
        logEvent(.inventoryItemDeleted, date: Date(), descriptionText: "\(label) excluído do estoque.", context: context)
        try save(context: context)
        await NotificationManager.shared.cancelLensInventoryNotifications(for: id)
    }

    /// Reduz a quantidade restante em 1 ao usar uma lente do estoque para iniciar um novo par.
    /// Ao chegar a zero, marca o item como esgotado e cancela os avisos de validade pendentes
    /// (uma lente esgotada não precisa mais de aviso de vencimento).
    static func consumeOne(_ item: LensInventoryItem, forPairNamed pairName: String, context: ModelContext) async throws {
        guard item.remainingQuantity > 0 else { return }
        item.remainingQuantity -= 1
        logEvent(
            .inventoryItemUsed,
            date: Date(),
            descriptionText: "Uma unidade de \(item.brand) \(item.model) usada para iniciar \(pairName). Restam \(item.remainingQuantity).",
            context: context
        )
        if item.remainingQuantity == 0 {
            item.status = .exhausted
            logEvent(
                .inventoryItemExhausted,
                date: Date(),
                descriptionText: "\(item.brand) \(item.model) esgotado no estoque.",
                context: context
            )
        }
        try save(context: context)
        if item.status == .exhausted {
            await NotificationManager.shared.cancelLensInventoryNotifications(for: item.id)
        }
    }

    private static func logEvent(_ type: HistoryEventType, date: Date, descriptionText: String, context: ModelContext) {
        let event = HistoryEvent(eventType: type, eventDate: date, descriptionText: descriptionText)
        context.insert(event)
    }
}
