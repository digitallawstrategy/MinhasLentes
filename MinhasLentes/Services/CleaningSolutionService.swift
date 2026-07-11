import Foundation
import SwiftData
import WidgetKit

/// Regras de negócio do ciclo de vida da solução de limpeza. No máximo um `CleaningSolution`
/// fica `.active` por vez — abrir um novo frasco encerra automaticamente o anterior
/// (`.finished`), exatamente como `LensCaseService` faz com o estojo.
@MainActor
enum CleaningSolutionService {

    enum ServiceError: LocalizedError {
        case persistenceFailed(String)
        case notificationSchedulingFailed(String)

        var errorDescription: String? {
            switch self {
            case .persistenceFailed(let detail):
                return "Não foi possível salvar a solução de limpeza. \(detail)"
            case .notificationSchedulingFailed(let detail):
                return "O frasco foi registrado, mas não foi possível reagendar as notificações. \(detail)"
            }
        }
    }

    static func allSolutions(context: ModelContext) throws -> [CleaningSolution] {
        let descriptor = FetchDescriptor<CleaningSolution>(sortBy: [SortDescriptor(\.openedDate, order: .reverse)])
        do {
            return try context.fetch(descriptor)
        } catch {
            throw ServiceError.persistenceFailed(error.localizedDescription)
        }
    }

    static func activeSolution(context: ModelContext) throws -> CleaningSolution? {
        var descriptor = FetchDescriptor<CleaningSolution>(predicate: #Predicate { $0.statusRawValue == "active" })
        descriptor.fetchLimit = 1
        do {
            return try context.fetch(descriptor).first
        } catch {
            throw ServiceError.persistenceFailed(error.localizedDescription)
        }
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

    /// Abre um novo frasco. Se já houver um frasco ativo, ele é automaticamente finalizado
    /// (`.finished`, com `finishedAt = openedDate`) — nunca fica mais de um ativo.
    @discardableResult
    static func startNewSolution(
        brand: String,
        product: String,
        lot: String?,
        purchaseDate: Date?,
        openedDate: Date,
        printedExpiryDate: Date?,
        postOpeningShelfLifeDays: Int,
        initialVolumeML: Int?,
        notes: String?,
        settings: AppSettings,
        context: ModelContext
    ) async throws -> CleaningSolution {
        if let current = try activeSolution(context: context) {
            current.status = .finished
            current.finishedAt = openedDate
            logEvent(
                .solutionClosed,
                date: openedDate,
                descriptionText: "Frasco de \(current.brand) \(current.product) finalizado em \(DateFormatting.short.string(from: openedDate)).",
                context: context
            )
        }

        let solution = CleaningSolution(
            brand: brand, product: product, lot: lot, purchaseDate: purchaseDate, openedDate: openedDate,
            printedExpiryDate: printedExpiryDate, postOpeningShelfLifeDays: postOpeningShelfLifeDays,
            initialVolumeML: initialVolumeML, remainingVolumeML: initialVolumeML, notes: notes
        )
        context.insert(solution)
        logEvent(
            .solutionOpened,
            date: openedDate,
            descriptionText: "Novo frasco de \(brand) \(product) aberto em \(DateFormatting.short.string(from: openedDate)).",
            context: context
        )

        try save(context: context)

        await NotificationManager.shared.cancelCleaningSolutionNotifications()
        do {
            try await NotificationManager.shared.scheduleCleaningSolutionNotifications(discardDate: solution.discardDate, settings: settings)
        } catch NotificationManager.NotificationError.authorizationDenied {
            // Usuário ainda não autorizou notificações; o frasco permanece salvo normalmente.
        } catch {
            let failureEvent = HistoryEvent(
                eventType: .settingsChanged,
                eventDate: Date(),
                descriptionText: "Falha ao reagendar notificações da solução de limpeza: \(error.localizedDescription)"
            )
            context.insert(failureEvent)
            try? context.save()
            throw ServiceError.notificationSchedulingFailed(error.localizedDescription)
        }

        return solution
    }

    /// Corrige os dados de um frasco já registrado, sem alterar se ele está ativo ou
    /// finalizado. Reagenda as notificações se o frasco editado for o ativo.
    static func editSolution(
        _ solution: CleaningSolution,
        brand: String,
        product: String,
        lot: String?,
        purchaseDate: Date?,
        openedDate: Date,
        printedExpiryDate: Date?,
        postOpeningShelfLifeDays: Int,
        initialVolumeML: Int?,
        remainingVolumeML: Int?,
        notes: String?,
        settings: AppSettings,
        context: ModelContext
    ) async throws {
        solution.brand = brand
        solution.product = product
        solution.lot = lot
        solution.purchaseDate = purchaseDate
        solution.openedDate = openedDate
        solution.printedExpiryDate = printedExpiryDate
        solution.postOpeningShelfLifeDays = postOpeningShelfLifeDays
        solution.initialVolumeML = initialVolumeML
        solution.remainingVolumeML = remainingVolumeML
        solution.notes = notes
        logEvent(.solutionEdited, date: Date(), descriptionText: "Frasco de \(brand) \(product) editado.", context: context)

        try save(context: context)

        guard solution.status == .active else { return }
        await NotificationManager.shared.cancelCleaningSolutionNotifications()
        do {
            try await NotificationManager.shared.scheduleCleaningSolutionNotifications(discardDate: solution.discardDate, settings: settings)
        } catch NotificationManager.NotificationError.authorizationDenied {
            // Usuário ainda não autorizou notificações; a edição permanece salva normalmente.
        } catch {
            let failureEvent = HistoryEvent(
                eventType: .settingsChanged,
                eventDate: Date(),
                descriptionText: "Falha ao reagendar notificações da solução de limpeza: \(error.localizedDescription)"
            )
            context.insert(failureEvent)
            try? context.save()
            throw ServiceError.notificationSchedulingFailed(error.localizedDescription)
        }
    }

    /// Exclui permanentemente um frasco lançado por engano. Se for o frasco ativo, as
    /// notificações são canceladas e nenhum frasco fica ativo até que um novo seja aberto.
    static func deleteSolution(_ solution: CleaningSolution, context: ModelContext) async throws {
        let wasActive = solution.status == .active
        let label = "\(solution.brand) \(solution.product)"
        context.delete(solution)
        logEvent(.solutionDeleted, date: Date(), descriptionText: "Frasco de \(label) excluído.", context: context)
        try save(context: context)

        if wasActive {
            await NotificationManager.shared.cancelCleaningSolutionNotifications()
        }
    }

    private static func logEvent(_ type: HistoryEventType, date: Date, descriptionText: String, context: ModelContext) {
        let event = HistoryEvent(eventType: type, eventDate: date, descriptionText: descriptionText)
        context.insert(event)
    }
}
