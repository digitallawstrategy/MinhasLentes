import Foundation
import SwiftData

/// Retrato somente-leitura do par em uso mais antigo, usado para desenhar o widget sem expor
/// os modelos SwiftData diretamente às views (que rodam num processo separado do app).
struct LensSnapshot {
    var pairID: UUID?
    var pairName: String?
    var usesRemaining: Int
    var usesCount: Int
    var maximumUses: Int
    var daysSinceCleaning: Int?
    var daysUntilNextCleaning: Int?
    var hasActivePair: Bool
    /// Preenchido quando há uma sessão "Estou usando as lentes" ativa — lido do `WearSession`
    /// persistido (fonte de verdade), não da Live Activity, que pode ter sido encerrada pelo
    /// sistema sem a sessão em si ter terminado.
    var wearingSince: Date?
    var daysUntilCaseReplacement: Int?
    var daysUntilSolutionDiscard: Int?
    var daysUntilNextAppointment: Int?
    /// Espelha `RoutineCareService.hasCareToday` — mesma checagem (`Calendar.isDate(_:inSameDayAs:)`
    /// sobre todos os `RoutineCareLog`), sem nenhuma regra nova, só para o medium widget poder
    /// mostrar "cuidado diário em dia/pendente" como um dos 3 sinais secundários.
    var hasRoutineCareToday: Bool
    /// Limiares configurados pelo usuário em Configurações (`AppSettings.health*BelowPercent`) —
    /// o widget nunca inventa seus próprios limiares, usa os mesmos do app para decidir a cor do
    /// anel (`WidgetTone.forUsage`).
    var healthGoodBelowPercent: Int
    var healthWarningBelowPercent: Int
    var healthCriticalBelowPercent: Int
    /// Só preenchido em builds DEBUG quando `hasActivePair` é falso — mostrado na própria tela
    /// do widget para dar visibilidade a um problema que, de outra forma, ficaria completamente
    /// silencioso (não há como anexar o depurador a um widget rodando na tela de início).
    var debugMessage: String?

    var remainingFraction: Double {
        guard maximumUses > 0 else { return 0 }
        return Double(usesRemaining) / Double(maximumUses)
    }

    static let placeholder = LensSnapshot(
        pairID: UUID(), pairName: "Par nº 1", usesRemaining: 59, usesCount: 1, maximumUses: 60,
        daysSinceCleaning: 3, daysUntilNextCleaning: 12, hasActivePair: true,
        wearingSince: nil, daysUntilCaseReplacement: 45, daysUntilSolutionDiscard: 20, daysUntilNextAppointment: 90,
        hasRoutineCareToday: true, healthGoodBelowPercent: 80, healthWarningBelowPercent: 40, healthCriticalBelowPercent: 15,
        debugMessage: nil
    )

    static let empty = LensSnapshot(
        pairID: nil, pairName: nil, usesRemaining: 0, usesCount: 0, maximumUses: 0,
        daysSinceCleaning: nil, daysUntilNextCleaning: nil, hasActivePair: false,
        wearingSince: nil, daysUntilCaseReplacement: nil, daysUntilSolutionDiscard: nil, daysUntilNextAppointment: nil,
        hasRoutineCareToday: false, healthGoodBelowPercent: 80, healthWarningBelowPercent: 40, healthCriticalBelowPercent: 15,
        debugMessage: nil
    )
}

/// Lê o banco compartilhado do App Group para montar o retrato mostrado no widget.
///
/// O schema aqui declara TODOS os modelos persistidos, mesmo os que este loader nunca busca
/// (`HistoryEvent`, `RoutineCareLog`, `LensInventoryItem`) — isto já foi a causa real de um bug
/// de perda de dados: uma versão anterior deste arquivo usava um schema reduzido, sem essas três
/// tabelas, e abria o `ModelContainer` em modo leitura/escrita (o padrão). Um `ModelContainer`
/// aberto assim não é "somente leitura" das tabelas que ele desconhece — qualquer checkpoint/
/// validação que o SwiftData faça ao abrir ou salvar o store pode reconciliar o arquivo real com
/// o modelo do processo que o abriu, e um modelo que não sabe de uma tabela pode fazer o
/// conteúdo dela desaparecer. Isso batia exatamente com o sintoma relatado (cuidados diários
/// somem do calendário após reinstalar/relançar o app): o processo da extensão é reiniciado
/// junto com o app a cada novo Run, reabre o container com o schema reduzido antigo, e as
/// tabelas de fora dele ficavam em risco.
///
/// `RoutineCareLog.swift`/`LensInventoryItem.swift` precisaram ser adicionados às exceções de
/// membership do alvo da extensão em `project.pbxproj` para compilar aqui — `HistoryEvent.swift`
/// já estava disponível, só não era usado no schema.
enum LensSnapshotLoader {
    /// Reaberto uma vez por processo da extensão, não a cada atualização do widget — abrir o
    /// arquivo do App Group repetidas vezes, de um processo separado do app, é justamente o
    /// tipo de coisa que pode colidir com uma gravação do app acontecendo no mesmo instante.
    private static var cachedContainer: ModelContainer?

    private static func sharedContainer() throws -> ModelContainer {
        if let cachedContainer { return cachedContainer }
        let schema = Schema([
            LensPair.self, LensUsage.self, CaseCleaning.self, AppSettings.self,
            LensCase.self, CleaningSolution.self, EyeAppointment.self, EyeCareProfessional.self,
            WearSession.self, HistoryEvent.self, RoutineCareLog.self, LensInventoryItem.self,
        ])
        // Mesma flag que `AppContainer` usa para decidir qual dos dois stores é o canônico —
        // depois que `CloudSyncMigrationService` migrou o conteúdo (ver o app principal), o
        // widget precisa passar a ler o arquivo novo, senão mostraria dados parados no instante
        // da migração para sempre. `cloudKitDatabase: .none` mesmo lendo o arquivo com CloudKit:
        // este alvo não tem o entitlement, e só precisa LER as tabelas de dado — quem sincroniza
        // de verdade é sempre o processo do app principal, nunca o widget.
        let url = try AppGroup.isCloudMigrationComplete ? AppGroup.cloudStoreURL() : AppGroup.storeURL()
        let configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        cachedContainer = container
        return container
    }

    /// Dias corridos entre `date` e `referenceDate` (positivo se `date` for no futuro).
    /// Duplicado deliberadamente de `LensStatisticsService.daysUntil` — ver comentário no topo
    /// do arquivo sobre por que este loader não depende de arquivos do target do app.
    private static func daysUntil(_ date: Date, from referenceDate: Date, calendar: Calendar) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: referenceDate), to: calendar.startOfDay(for: date)).day ?? 0
    }

    static func load() -> LensSnapshot {
        do {
            let context = ModelContext(try sharedContainer())
            let calendar = Calendar.current
            let now = Date()

            let inUseDescriptor = FetchDescriptor<LensPair>(
                predicate: #Predicate { $0.statusRawValue == "inUse" && $0.deletedAt == nil },
                sortBy: [SortDescriptor(\.sequenceNumber)]
            )
            guard let pair = try context.fetch(inUseDescriptor).first else {
                #if DEBUG
                let allPairs = (try? context.fetch(FetchDescriptor<LensPair>())) ?? []
                let statuses = allPairs.map { "\($0.statusRawValue)\($0.deletedAt != nil ? "(lixeira)" : "")" }
                var snapshot = LensSnapshot.empty
                snapshot.debugMessage = "Sem par 'inUse'. \(allPairs.count) par(es) no banco: \(statuses)"
                return snapshot
                #else
                return .empty
                #endif
            }

            let settings = try context.fetch(FetchDescriptor<AppSettings>()).first
            let intervalDays = settings?.cleaningIntervalDays ?? 15
            let cleaningDescriptor = FetchDescriptor<CaseCleaning>(sortBy: [SortDescriptor(\.cleaningDate, order: .reverse)])
            let lastCleaning = try context.fetch(cleaningDescriptor).first

            var daysSinceCleaning: Int?
            var daysUntilNextCleaning: Int?
            if let lastCleaning {
                let startOfLastCleaning = calendar.startOfDay(for: lastCleaning.cleaningDate)
                let startOfToday = calendar.startOfDay(for: now)
                daysSinceCleaning = calendar.dateComponents([.day], from: startOfLastCleaning, to: startOfToday).day
                let nextDate = calendar.date(byAdding: .day, value: intervalDays, to: startOfLastCleaning) ?? now
                daysUntilNextCleaning = calendar.dateComponents([.day], from: startOfToday, to: calendar.startOfDay(for: nextDate)).day
            }

            let activeCaseDescriptor = FetchDescriptor<LensCase>(predicate: #Predicate { $0.statusRawValue == "active" })
            let daysUntilCaseReplacement = try context.fetch(activeCaseDescriptor).first.map {
                let replacementDate = calendar.date(byAdding: .day, value: $0.intervalDays, to: calendar.startOfDay(for: $0.startDate)) ?? $0.startDate
                return daysUntil(replacementDate, from: now, calendar: calendar)
            }

            let activeSolutionDescriptor = FetchDescriptor<CleaningSolution>(predicate: #Predicate { $0.statusRawValue == "active" })
            let daysUntilSolutionDiscard = try context.fetch(activeSolutionDescriptor).first.map { solution -> Int in
                let shelfLifeDate = calendar.date(byAdding: .day, value: solution.postOpeningShelfLifeDays, to: calendar.startOfDay(for: solution.openedDate)) ?? solution.openedDate
                let discardDate = solution.printedExpiryDate.map { min(shelfLifeDate, $0) } ?? shelfLifeDate
                return daysUntil(discardDate, from: now, calendar: calendar)
            }

            let scheduledAppointmentsDescriptor = FetchDescriptor<EyeAppointment>(
                predicate: #Predicate { $0.statusRawValue == "scheduled" },
                sortBy: [SortDescriptor(\.date)]
            )
            let daysUntilNextAppointment = try context.fetch(scheduledAppointmentsDescriptor)
                .first { $0.date >= now }
                .map { daysUntil($0.date, from: now, calendar: calendar) }

            let activeSessionDescriptor = FetchDescriptor<WearSession>(predicate: #Predicate { $0.statusRawValue == "active" })
            let wearingSince = try context.fetch(activeSessionDescriptor).first?.startedAt

            // Mesma checagem de `RoutineCareService.hasCareToday` (ver comentário no campo
            // `hasRoutineCareToday` de `LensSnapshot`), só sem depender do Service do app.
            let routineCareLogs = try context.fetch(FetchDescriptor<RoutineCareLog>())
            let hasRoutineCareToday = routineCareLogs.contains { calendar.isDate($0.date, inSameDayAs: now) }

            return LensSnapshot(
                pairID: pair.id,
                pairName: pair.name,
                usesRemaining: pair.usesRemaining,
                usesCount: pair.usesCount,
                maximumUses: pair.maximumUses,
                daysSinceCleaning: daysSinceCleaning,
                daysUntilNextCleaning: daysUntilNextCleaning,
                hasActivePair: true,
                wearingSince: wearingSince,
                daysUntilCaseReplacement: daysUntilCaseReplacement,
                daysUntilSolutionDiscard: daysUntilSolutionDiscard,
                daysUntilNextAppointment: daysUntilNextAppointment,
                hasRoutineCareToday: hasRoutineCareToday,
                healthGoodBelowPercent: settings?.healthGoodBelowPercent ?? 80,
                healthWarningBelowPercent: settings?.healthWarningBelowPercent ?? 40,
                healthCriticalBelowPercent: settings?.healthCriticalBelowPercent ?? 15
            )
        } catch {
            #if DEBUG
            var snapshot = LensSnapshot.empty
            snapshot.debugMessage = "Erro ao ler o App Group: \(error)"
            return snapshot
            #else
            return .empty
            #endif
        }
    }
}
