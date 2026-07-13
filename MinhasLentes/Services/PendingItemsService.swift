import Foundation

/// Identidade estável de cada tipo de pendência — não `UUID()`, pelo mesmo motivo de
/// `HomeView.ReminderKind`: preserva animação/estado de lista entre atualizações.
enum PendingItemKind: Hashable {
    case dailyCare, wearSession, caseCleaningDue, caseReplacementDue, solutionDiscardNear, inventoryExpiry, appointment
}

/// O que a ação direta de uma pendência faz, quando existe uma — `NotificationsCenterView`
/// decide como executar cada caso (chamando o view model certo ou navegando de aba).
enum PendingItemAction {
    case registerDailyCare
    case endWearSession
    case navigate(AppTab)
}

struct PendingItem: Identifiable {
    let id: PendingItemKind
    let icon: String
    let title: String
    let detail: String
    let tone: AppStatusTone
    let action: PendingItemAction?
    let actionLabel: String?
}

/// Tudo que `PendingItemsService.pendingItems(input:)` precisa — montado pelo chamador (hoje,
/// `HomeView`) a partir de dados que ele já busca via `@Query`, para esta função continuar pura e
/// sem depender de `ModelContext`.
struct PendingItemsInput {
    let hasCareToday: Bool
    let dailyCareReminderEnabled: Bool
    let dailyCareReminderHour: Int
    let activeWearSession: WearSession?
    let wearingReminderHours: Int
    let lastCleaning: CaseCleaning?
    let activeCase: LensCase?
    let cleaningIntervalDays: Int
    let advanceReminderDays: Int
    let activeSolution: CleaningSolution?
    let nextAppointment: EyeAppointment?
    let expiringInventoryItems: [LensInventoryItem]
}

/// Agrega pendências reais do app numa lista única, para a central de avisos aberta pelo sino da
/// Home (`NotificationsCenterView`) e para o badge do próprio sino. Deliberadamente separado do
/// cartão "Lembretes" já existente em `HomeView` (que continua do jeito que está, sem
/// refatoração) — aqui o critério é mais amplo (inclui sessão de uso excessiva e cuidado diário,
/// que o cartão da Home não mostra) e toda pendência tem uma ação direta associada quando faz
/// sentido, não só navegação de aba.
@MainActor
enum PendingItemsService {
    static func pendingItems(
        input: PendingItemsInput,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> [PendingItem] {
        var items: [PendingItem] = []

        if input.dailyCareReminderEnabled,
           RoutineCareService.isDailyCareReminderDue(
               referenceDate: referenceDate, reminderHour: input.dailyCareReminderHour,
               hasCareToday: input.hasCareToday, calendar: calendar
           ) {
            items.append(PendingItem(
                id: .dailyCare, icon: "checklist", title: "Cuidado diário",
                detail: "Ainda não registrado hoje.", tone: .warning,
                action: .registerDailyCare, actionLabel: "Registrar cuidado"
            ))
        }

        if let session = input.activeWearSession {
            let elapsedHours = referenceDate.timeIntervalSince(session.startedAt) / 3600
            if elapsedHours >= Double(input.wearingReminderHours) {
                items.append(PendingItem(
                    id: .wearSession, icon: "eye.trianglebadge.exclamationmark", title: "Sessão de uso",
                    detail: "Lentes em uso há mais de \(Pluralization.count(input.wearingReminderHours, "hora", "horas")).",
                    tone: .warning, action: .endWearSession, actionLabel: "Retirei as lentes"
                ))
            }
        }

        if let activeCase = input.activeCase {
            let daysUntilReplacement = LensStatisticsService.daysUntil(
                activeCase.nextRecommendedReplacementDate, referenceDate: referenceDate, calendar: calendar
            )
            if daysUntilReplacement <= input.advanceReminderDays {
                items.append(PendingItem(
                    id: .caseReplacementDue, icon: "shippingbox", title: "Substituição do estojo",
                    detail: dueDetail(days: daysUntilReplacement, verb: "Substituição recomendada"),
                    tone: tone(daysRemaining: daysUntilReplacement, advanceReminderDays: input.advanceReminderDays),
                    action: .navigate(.cuidados), actionLabel: "Ver estojo"
                ))
            }

            if let lastCleaning = input.lastCleaning {
                let nextCleaningDate = LensStatisticsService.nextCleaningDate(
                    lastCleaningDate: lastCleaning.cleaningDate, intervalDays: input.cleaningIntervalDays
                )
                let daysUntilCleaning = LensStatisticsService.daysUntil(nextCleaningDate, referenceDate: referenceDate, calendar: calendar)
                if daysUntilCleaning <= input.advanceReminderDays {
                    items.append(PendingItem(
                        id: .caseCleaningDue, icon: "sparkles", title: "Limpeza periódica",
                        detail: dueDetail(days: daysUntilCleaning, verb: "Limpeza recomendada"),
                        tone: tone(daysRemaining: daysUntilCleaning, advanceReminderDays: input.advanceReminderDays),
                        action: .navigate(.cuidados), actionLabel: "Ver estojo"
                    ))
                }
            }
        }

        if let activeSolution = input.activeSolution {
            let daysUntilDiscard = LensStatisticsService.daysUntil(activeSolution.discardDate, referenceDate: referenceDate, calendar: calendar)
            if daysUntilDiscard <= input.advanceReminderDays {
                items.append(PendingItem(
                    id: .solutionDiscardNear, icon: "flask", title: "Solução de limpeza",
                    detail: dueDetail(days: daysUntilDiscard, verb: "Descarte recomendado"),
                    tone: tone(daysRemaining: daysUntilDiscard, advanceReminderDays: input.advanceReminderDays),
                    action: .navigate(.cuidados), actionLabel: "Ver solução"
                ))
            }
        }

        if !input.expiringInventoryItems.isEmpty {
            items.append(PendingItem(
                id: .inventoryExpiry, icon: "tray.full", title: "Estoque",
                detail: input.expiringInventoryItems.count == 1
                    ? "1 caixa perto da validade."
                    : "\(input.expiringInventoryItems.count) caixas perto da validade.",
                tone: .warning, action: .navigate(.lentes), actionLabel: "Ver estoque"
            ))
        }

        if let nextAppointment = input.nextAppointment {
            let daysUntil = LensStatisticsService.daysUntil(nextAppointment.date, referenceDate: referenceDate, calendar: calendar)
            if daysUntil <= input.advanceReminderDays {
                let dateText = DateFormatting.short.string(from: nextAppointment.date)
                let professionalName: String? = nextAppointment.professional?.name
                let detail: String
                if let professionalName {
                    detail = "\(dateText) com \(professionalName)."
                } else {
                    detail = "\(dateText)."
                }
                items.append(PendingItem(
                    id: .appointment, icon: "calendar.badge.clock", title: "Consulta",
                    detail: detail,
                    tone: tone(daysRemaining: daysUntil, advanceReminderDays: input.advanceReminderDays),
                    action: .navigate(.consultas), actionLabel: "Ver consultas"
                ))
            }
        }

        return items
    }

    private static func tone(daysRemaining: Int, advanceReminderDays: Int) -> AppStatusTone {
        if daysRemaining <= 0 { return .critical }
        if daysRemaining <= advanceReminderDays { return .warning }
        return .informative
    }

    private static func dueDetail(days: Int, verb: String) -> String {
        if days > 0 { return "\(verb) em \(Pluralization.count(days, "dia", "dias"))." }
        if days == 0 { return "\(verb) para hoje." }
        return "\(verb) há \(Pluralization.count(-days, "dia", "dias"))."
    }
}
