import Foundation
import SwiftData

/// Backup/restauração completos em JSON — ao contrário do CSV/PDF (que são relatórios de
/// leitura), este formato preserva identificadores e relacionamentos e pode ser reimportado
/// para restaurar integralmente os dados do aplicativo.
///
/// A importação é feita em memória sobre o `ModelContext` e só é persistida por um único
/// `context.save()` ao final; qualquer falha durante o processo aciona `context.rollback()`,
/// descartando tudo o que foi preparado — não há gravação parcial em disco.
@MainActor
enum BackupService {

    nonisolated static let currentSchemaVersion = 1

    enum BackupError: LocalizedError {
        case encodingFailed(String)
        case writeFailed(String)
        case readFailed(String)
        case decodingFailed(String)
        case invalidFile(String)
        case unsupportedSchemaVersion(Int)
        case persistenceFailed(String)

        var errorDescription: String? {
            switch self {
            case .encodingFailed(let detail):
                return "Não foi possível preparar o backup. \(detail)"
            case .writeFailed(let detail):
                return "Não foi possível salvar o arquivo de backup. \(detail)"
            case .readFailed(let detail):
                return "Não foi possível ler o arquivo selecionado. \(detail)"
            case .decodingFailed(let detail):
                return "O arquivo não está em um formato de backup reconhecível. \(detail)"
            case .invalidFile(let detail):
                return "Arquivo de backup inválido: \(detail)"
            case .unsupportedSchemaVersion(let version):
                return "Este backup foi criado em uma versão do esquema (\(version)) não suportada por este aplicativo (versão atual: \(currentSchemaVersion))."
            case .persistenceFailed(let detail):
                return "Não foi possível salvar os dados importados. Nenhuma alteração foi aplicada. \(detail)"
            }
        }
    }

    enum ImportMode {
        /// Apaga todos os dados atuais antes de importar o conteúdo do backup.
        case replace
        /// Mantém os dados atuais e adiciona apenas os registros do backup cujo identificador
        /// ainda não existe no aplicativo.
        case merge
    }

    struct ImportReport: Sendable, Equatable {
        var pairsImported = 0
        var usagesImported = 0
        var cleaningsImported = 0
        var eventsImported = 0
        var settingsImported = false
        var pairsSkippedAsDuplicate = 0
        var usagesSkippedAsDuplicate = 0
        var cleaningsSkippedAsDuplicate = 0
        var eventsSkippedAsDuplicate = 0
        var casesImported = 0
        var casesSkippedAsDuplicate = 0
        var routineCareLogsImported = 0
        var routineCareLogsSkippedAsDuplicate = 0
        var solutionsImported = 0
        var solutionsSkippedAsDuplicate = 0
        var inventoryItemsImported = 0
        var inventoryItemsSkippedAsDuplicate = 0
        var professionalsImported = 0
        var professionalsSkippedAsDuplicate = 0
        var appointmentsImported = 0
        var appointmentsSkippedAsDuplicate = 0
        var wearSessionsImported = 0
        var wearSessionsSkippedAsDuplicate = 0
    }

    // MARK: - Estrutura do arquivo (versionada)

    struct BackupEnvelope: Codable {
        var schemaVersion: Int
        var createdAt: Date
        var pairs: [PairDTO]
        var usages: [UsageDTO]
        var cleanings: [CleaningDTO]
        var events: [EventDTO]
        var settings: SettingsDTO?
        /// Opcional para preservar compatibilidade com backups criados antes da versão que
        /// introduziu o ciclo de vida do estojo (ausente = nenhum registro, não "erro").
        var cases: [CaseDTO]? = nil
        var routineCareLogs: [RoutineCareLogDTO]? = nil
        var solutions: [SolutionDTO]? = nil
        var inventoryItems: [InventoryItemDTO]? = nil
        var professionals: [ProfessionalDTO]? = nil
        var appointments: [AppointmentDTO]? = nil
        var wearSessions: [WearSessionDTO]? = nil
    }

    struct WearSessionDTO: Codable {
        var id: UUID
        var lensPairID: UUID?
        var startedAt: Date
        var endedAt: Date?
        var status: String
        var createdAt: Date
    }

    struct ProfessionalDTO: Codable {
        var id: UUID
        var name: String
        var clinic: String?
        var phone: String?
        var whatsapp: String?
        var email: String?
        var address: String?
        var notes: String?
        var createdAt: Date
    }

    struct AppointmentDTO: Codable {
        var id: UUID
        var professionalID: UUID?
        var date: Date
        var type: String
        var notes: String?
        var prescription: String?
        var attachmentData: Data?
        var recommendedFollowUpMonths: Int
        var status: String
        var createdAt: Date
    }

    struct InventoryItemDTO: Codable {
        var id: UUID
        var brand: String
        var model: String
        var prescriptionOD: String?
        var prescriptionOS: String?
        var side: String
        var lot: String?
        var expiryDate: Date?
        var initialQuantity: Int
        var remainingQuantity: Int
        var photoData: Data?
        var notes: String?
        var status: String
        var createdAt: Date
    }

    struct SolutionDTO: Codable {
        var id: UUID
        var brand: String
        var product: String
        var lot: String?
        var purchaseDate: Date?
        var openedDate: Date
        var printedExpiryDate: Date?
        var postOpeningShelfLifeDays: Int
        var initialVolumeML: Int?
        var remainingVolumeML: Int?
        var notes: String?
        var status: String
        var finishedAt: Date?
        var createdAt: Date
    }

    struct CaseDTO: Codable {
        var id: UUID
        var startDate: Date
        var replacedAt: Date?
        var intervalDays: Int
        var notes: String?
        var status: String
        var createdAt: Date
    }

    struct RoutineCareLogDTO: Codable {
        var id: UUID
        var date: Date
        var discardedSolution: Bool
        var cleanedCase: Bool
        var airDried: Bool
        var notes: String?
        var createdAt: Date
    }

    struct PairDTO: Codable {
        var id: UUID
        var name: String
        var sequenceNumber: Int
        var startDate: Date
        var endDate: Date?
        var maximumUses: Int
        var status: String
        var discardReason: String?
        var notes: String?
        var trackingMode: String
        var side: String
        var createdAt: Date
    }

    struct UsageDTO: Codable {
        var id: UUID
        var lensPairID: UUID?
        var date: Date
        var side: String
        var notes: String?
        var createdAt: Date
    }

    struct CleaningDTO: Codable {
        var id: UUID
        var cleaningDate: Date
        var notes: String?
        var createdAt: Date
    }

    struct EventDTO: Codable {
        var id: UUID
        var eventType: String
        var eventDate: Date
        var lensPairID: UUID?
        var lensPairName: String?
        var side: String?
        var descriptionText: String
        var createdAt: Date
    }

    struct SettingsDTO: Codable {
        var maximumUses: Int
        var cleaningIntervalDays: Int
        var advanceReminderDays: Int
        var notificationHour: Int
        var notificationMinute: Int
        var allowMultipleUsesPerDay: Bool
        var advanceReminderEnabled: Bool
        var deadlineReminderEnabled: Bool
        var soundEnabled: Bool
        var badgeEnabled: Bool
        var trackingMode: String
        var healthGoodBelowPercent: Int? = nil
        var healthWarningBelowPercent: Int? = nil
        var healthCriticalBelowPercent: Int? = nil
        var wearingReminderHours: Int? = nil
        var wearingExcessiveRepeatIntervalHours: Int? = nil
        var caseReplacementIntervalDays: Int? = nil
        var caseReminderEnabled: Bool? = nil
        var caseOverdueReminderIntervalDays: Int? = nil
        var solutionReminderEnabled: Bool? = nil
        var solutionOverdueReminderIntervalDays: Int? = nil
        var inventoryReminderEnabled: Bool? = nil
        var appointmentReminderEnabled: Bool? = nil
        var defaultAppointmentIntervalMonths: Int? = nil
    }

    // MARK: - Exportação

    static func exportJSON(context: ModelContext) throws -> URL {
        let pairs = try LensPairService.allPairs(context: context)
        let cleanings = try CaseCleaningService.allCleanings(context: context)
        let cases = try LensCaseService.allCases(context: context)
        let routineCareLogs = try RoutineCareService.allLogs(context: context)
        let solutions = try CleaningSolutionService.allSolutions(context: context)
        let inventoryItems = try LensInventoryService.allItems(context: context)
        let professionals = try EyeCareProfessionalService.allProfessionals(context: context)
        let appointments = try EyeAppointmentService.allAppointments(context: context)
        let wearSessions = try WearSessionService.allSessions(context: context)

        let events: [HistoryEvent]
        do {
            events = try context.fetch(FetchDescriptor<HistoryEvent>(sortBy: [SortDescriptor(\.eventDate, order: .reverse)]))
        } catch {
            throw BackupError.readFailed(error.localizedDescription)
        }

        let settings: AppSettings?
        do {
            settings = try context.fetch(FetchDescriptor<AppSettings>()).first
        } catch {
            throw BackupError.readFailed(error.localizedDescription)
        }

        var usageDTOs: [UsageDTO] = []
        for pair in pairs {
            for usage in pair.usages ?? [] {
                usageDTOs.append(UsageDTO(
                    id: usage.id,
                    lensPairID: pair.id,
                    date: usage.date,
                    side: usage.sideRawValue,
                    notes: usage.notes,
                    createdAt: usage.createdAt
                ))
            }
        }

        let envelope = BackupEnvelope(
            schemaVersion: currentSchemaVersion,
            createdAt: Date(),
            pairs: pairs.map { pair in
                PairDTO(
                    id: pair.id,
                    name: pair.name,
                    sequenceNumber: pair.sequenceNumber,
                    startDate: pair.startDate,
                    endDate: pair.endDate,
                    maximumUses: pair.maximumUses,
                    status: pair.statusRawValue,
                    discardReason: pair.discardReason,
                    notes: pair.notes,
                    trackingMode: pair.trackingModeRawValue,
                    side: pair.sideRawValue,
                    createdAt: pair.createdAt
                )
            },
            usages: usageDTOs,
            cleanings: cleanings.map {
                CleaningDTO(id: $0.id, cleaningDate: $0.cleaningDate, notes: $0.notes, createdAt: $0.createdAt)
            },
            events: events.map {
                EventDTO(
                    id: $0.id,
                    eventType: $0.eventTypeRawValue,
                    eventDate: $0.eventDate,
                    lensPairID: $0.lensPairID,
                    lensPairName: $0.lensPairName,
                    side: $0.sideRawValue,
                    descriptionText: $0.descriptionText,
                    createdAt: $0.createdAt
                )
            },
            settings: settings.map { s in
                SettingsDTO(
                    maximumUses: s.maximumUses,
                    cleaningIntervalDays: s.cleaningIntervalDays,
                    advanceReminderDays: s.advanceReminderDays,
                    notificationHour: s.notificationHour,
                    notificationMinute: s.notificationMinute,
                    allowMultipleUsesPerDay: s.allowMultipleUsesPerDay,
                    advanceReminderEnabled: s.advanceReminderEnabled,
                    deadlineReminderEnabled: s.deadlineReminderEnabled,
                    soundEnabled: s.soundEnabled,
                    badgeEnabled: s.badgeEnabled,
                    trackingMode: s.trackingModeRawValue,
                    healthGoodBelowPercent: s.healthGoodBelowPercent,
                    healthWarningBelowPercent: s.healthWarningBelowPercent,
                    healthCriticalBelowPercent: s.healthCriticalBelowPercent,
                    wearingReminderHours: s.wearingReminderHours,
                    wearingExcessiveRepeatIntervalHours: s.wearingExcessiveRepeatIntervalHours,
                    caseReplacementIntervalDays: s.caseReplacementIntervalDays,
                    caseReminderEnabled: s.caseReminderEnabled,
                    caseOverdueReminderIntervalDays: s.caseOverdueReminderIntervalDays,
                    solutionReminderEnabled: s.solutionReminderEnabled,
                    solutionOverdueReminderIntervalDays: s.solutionOverdueReminderIntervalDays,
                    inventoryReminderEnabled: s.inventoryReminderEnabled,
                    appointmentReminderEnabled: s.appointmentReminderEnabled,
                    defaultAppointmentIntervalMonths: s.defaultAppointmentIntervalMonths
                )
            },
            cases: cases.map {
                CaseDTO(
                    id: $0.id, startDate: $0.startDate, replacedAt: $0.replacedAt, intervalDays: $0.intervalDays,
                    notes: $0.notes, status: $0.statusRawValue, createdAt: $0.createdAt
                )
            },
            routineCareLogs: routineCareLogs.map {
                RoutineCareLogDTO(
                    id: $0.id, date: $0.date, discardedSolution: $0.discardedSolution, cleanedCase: $0.cleanedCase,
                    airDried: $0.airDried, notes: $0.notes, createdAt: $0.createdAt
                )
            },
            solutions: solutions.map {
                SolutionDTO(
                    id: $0.id, brand: $0.brand, product: $0.product, lot: $0.lot, purchaseDate: $0.purchaseDate,
                    openedDate: $0.openedDate, printedExpiryDate: $0.printedExpiryDate,
                    postOpeningShelfLifeDays: $0.postOpeningShelfLifeDays, initialVolumeML: $0.initialVolumeML,
                    remainingVolumeML: $0.remainingVolumeML, notes: $0.notes, status: $0.statusRawValue,
                    finishedAt: $0.finishedAt, createdAt: $0.createdAt
                )
            },
            inventoryItems: inventoryItems.map {
                InventoryItemDTO(
                    id: $0.id, brand: $0.brand, model: $0.model, prescriptionOD: $0.prescriptionOD,
                    prescriptionOS: $0.prescriptionOS, side: $0.sideRawValue, lot: $0.lot, expiryDate: $0.expiryDate,
                    initialQuantity: $0.initialQuantity, remainingQuantity: $0.remainingQuantity,
                    photoData: $0.photoData, notes: $0.notes, status: $0.statusRawValue, createdAt: $0.createdAt
                )
            },
            professionals: professionals.map {
                ProfessionalDTO(
                    id: $0.id, name: $0.name, clinic: $0.clinic, phone: $0.phone, whatsapp: $0.whatsapp,
                    email: $0.email, address: $0.address, notes: $0.notes, createdAt: $0.createdAt
                )
            },
            appointments: appointments.map {
                AppointmentDTO(
                    id: $0.id, professionalID: $0.professional?.id, date: $0.date, type: $0.typeRawValue,
                    notes: $0.notes, prescription: $0.prescription, attachmentData: $0.attachmentData,
                    recommendedFollowUpMonths: $0.recommendedFollowUpMonths, status: $0.statusRawValue,
                    createdAt: $0.createdAt
                )
            },
            wearSessions: wearSessions.map {
                WearSessionDTO(
                    id: $0.id, lensPairID: $0.lensPair?.id, startedAt: $0.startedAt, endedAt: $0.endedAt,
                    status: $0.statusRawValue, createdAt: $0.createdAt
                )
            }
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data: Data
        do {
            data = try encoder.encode(envelope)
        } catch {
            throw BackupError.encodingFailed(error.localizedDescription)
        }

        let filename = "MinhasLentes_Backup_\(DateFormatting.fileTimestamp.string(from: Date())).json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            throw BackupError.writeFailed(error.localizedDescription)
        }
        return url
    }

    // MARK: - Validação (executada antes de qualquer alteração no armazenamento)

    static func validate(url: URL) throws -> BackupEnvelope {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw BackupError.readFailed(error.localizedDescription)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let envelope: BackupEnvelope
        do {
            envelope = try decoder.decode(BackupEnvelope.self, from: data)
        } catch {
            throw BackupError.decodingFailed(error.localizedDescription)
        }

        guard envelope.schemaVersion <= currentSchemaVersion else {
            throw BackupError.unsupportedSchemaVersion(envelope.schemaVersion)
        }
        guard !envelope.pairs.isEmpty || !envelope.cleanings.isEmpty || envelope.settings != nil
            || !(envelope.cases ?? []).isEmpty || !(envelope.routineCareLogs ?? []).isEmpty || !(envelope.solutions ?? []).isEmpty
            || !(envelope.inventoryItems ?? []).isEmpty || !(envelope.professionals ?? []).isEmpty
            || !(envelope.wearSessions ?? []).isEmpty
        else {
            throw BackupError.invalidFile("O arquivo não contém nenhum dado reconhecível.")
        }

        let pairIDs = Set(envelope.pairs.map(\.id))
        for usage in envelope.usages {
            if let pairID = usage.lensPairID, !pairIDs.contains(pairID) {
                throw BackupError.invalidFile("Um registro de uso referencia um par inexistente no próprio arquivo.")
            }
        }

        return envelope
    }

    // MARK: - Importação

    @discardableResult
    static func importBackup(from url: URL, mode: ImportMode, context: ModelContext) throws -> ImportReport {
        let envelope = try validate(url: url)
        var report = ImportReport()

        do {
            let existingPairs = mode == .merge ? try LensPairService.allPairs(context: context) : []
            let existingPairsByID = Dictionary(uniqueKeysWithValues: existingPairs.map { ($0.id, $0) })

            if mode == .replace {
                for usage in try context.fetch(FetchDescriptor<LensUsage>()) { context.delete(usage) }
                for pair in try context.fetch(FetchDescriptor<LensPair>()) { context.delete(pair) }
                for cleaning in try context.fetch(FetchDescriptor<CaseCleaning>()) { context.delete(cleaning) }
                for event in try context.fetch(FetchDescriptor<HistoryEvent>()) { context.delete(event) }
                for settings in try context.fetch(FetchDescriptor<AppSettings>()) { context.delete(settings) }
                for lensCase in try context.fetch(FetchDescriptor<LensCase>()) { context.delete(lensCase) }
                for log in try context.fetch(FetchDescriptor<RoutineCareLog>()) { context.delete(log) }
                for solution in try context.fetch(FetchDescriptor<CleaningSolution>()) { context.delete(solution) }
                for item in try context.fetch(FetchDescriptor<LensInventoryItem>()) { context.delete(item) }
                for appointment in try context.fetch(FetchDescriptor<EyeAppointment>()) { context.delete(appointment) }
                for professional in try context.fetch(FetchDescriptor<EyeCareProfessional>()) { context.delete(professional) }
                for session in try context.fetch(FetchDescriptor<WearSession>()) { context.delete(session) }
            }

            // Pares — mantém um mapa id → LensPair (novo ou já existente) para religar os usos.
            var pairsByID: [UUID: LensPair] = [:]
            for dto in envelope.pairs {
                if mode == .merge, let existing = existingPairsByID[dto.id] {
                    report.pairsSkippedAsDuplicate += 1
                    pairsByID[dto.id] = existing
                    continue
                }
                let pair = LensPair(
                    id: dto.id,
                    name: dto.name,
                    sequenceNumber: dto.sequenceNumber,
                    startDate: dto.startDate,
                    maximumUses: dto.maximumUses,
                    trackingMode: TrackingMode(rawValue: dto.trackingMode) ?? .pair,
                    side: LensSide(rawValue: dto.side) ?? .both
                )
                pair.endDate = dto.endDate
                pair.statusRawValue = dto.status
                pair.discardReason = dto.discardReason
                pair.notes = dto.notes
                pair.createdAt = dto.createdAt
                context.insert(pair)
                pairsByID[dto.id] = pair
                report.pairsImported += 1
            }

            // Usos
            let existingUsageIDs: Set<UUID> = mode == .merge
                ? Set(try context.fetch(FetchDescriptor<LensUsage>()).map(\.id))
                : []
            for dto in envelope.usages {
                if mode == .merge, existingUsageIDs.contains(dto.id) {
                    report.usagesSkippedAsDuplicate += 1
                    continue
                }
                let pair = dto.lensPairID.flatMap { pairsByID[$0] }
                let usage = LensUsage(
                    id: dto.id,
                    date: dto.date,
                    side: LensSide(rawValue: dto.side) ?? .both,
                    notes: dto.notes,
                    lensPair: pair
                )
                usage.createdAt = dto.createdAt
                context.insert(usage)
                report.usagesImported += 1
            }

            // Limpezas do estojo
            let existingCleaningIDs: Set<UUID> = mode == .merge
                ? Set(try context.fetch(FetchDescriptor<CaseCleaning>()).map(\.id))
                : []
            for dto in envelope.cleanings {
                if mode == .merge, existingCleaningIDs.contains(dto.id) {
                    report.cleaningsSkippedAsDuplicate += 1
                    continue
                }
                let cleaning = CaseCleaning(id: dto.id, cleaningDate: dto.cleaningDate, notes: dto.notes)
                cleaning.createdAt = dto.createdAt
                context.insert(cleaning)
                report.cleaningsImported += 1
            }

            // Eventos de histórico
            let existingEventIDs: Set<UUID> = mode == .merge
                ? Set(try context.fetch(FetchDescriptor<HistoryEvent>()).map(\.id))
                : []
            for dto in envelope.events {
                if mode == .merge, existingEventIDs.contains(dto.id) {
                    report.eventsSkippedAsDuplicate += 1
                    continue
                }
                let event = HistoryEvent(
                    id: dto.id,
                    eventType: HistoryEventType(rawValue: dto.eventType) ?? .usageAdded,
                    eventDate: dto.eventDate,
                    lensPairID: dto.lensPairID,
                    lensPairName: dto.lensPairName,
                    side: dto.side.flatMap { LensSide(rawValue: $0) },
                    descriptionText: dto.descriptionText
                )
                event.createdAt = dto.createdAt
                context.insert(event)
                report.eventsImported += 1
            }

            // Ciclos do estojo
            let existingCaseIDs: Set<UUID> = mode == .merge
                ? Set(try context.fetch(FetchDescriptor<LensCase>()).map(\.id))
                : []
            for dto in envelope.cases ?? [] {
                if mode == .merge, existingCaseIDs.contains(dto.id) {
                    report.casesSkippedAsDuplicate += 1
                    continue
                }
                let lensCase = LensCase(id: dto.id, startDate: dto.startDate, intervalDays: dto.intervalDays, notes: dto.notes)
                lensCase.replacedAt = dto.replacedAt
                lensCase.statusRawValue = dto.status
                lensCase.createdAt = dto.createdAt
                context.insert(lensCase)
                report.casesImported += 1
            }

            // Cuidados diários (rotina pós-remoção)
            let existingRoutineCareIDs: Set<UUID> = mode == .merge
                ? Set(try context.fetch(FetchDescriptor<RoutineCareLog>()).map(\.id))
                : []
            for dto in envelope.routineCareLogs ?? [] {
                if mode == .merge, existingRoutineCareIDs.contains(dto.id) {
                    report.routineCareLogsSkippedAsDuplicate += 1
                    continue
                }
                let log = RoutineCareLog(
                    id: dto.id, date: dto.date, discardedSolution: dto.discardedSolution,
                    cleanedCase: dto.cleanedCase, airDried: dto.airDried, notes: dto.notes
                )
                log.createdAt = dto.createdAt
                context.insert(log)
                report.routineCareLogsImported += 1
            }

            // Soluções de limpeza
            let existingSolutionIDs: Set<UUID> = mode == .merge
                ? Set(try context.fetch(FetchDescriptor<CleaningSolution>()).map(\.id))
                : []
            for dto in envelope.solutions ?? [] {
                if mode == .merge, existingSolutionIDs.contains(dto.id) {
                    report.solutionsSkippedAsDuplicate += 1
                    continue
                }
                let solution = CleaningSolution(
                    id: dto.id, brand: dto.brand, product: dto.product, lot: dto.lot, purchaseDate: dto.purchaseDate,
                    openedDate: dto.openedDate, printedExpiryDate: dto.printedExpiryDate,
                    postOpeningShelfLifeDays: dto.postOpeningShelfLifeDays, initialVolumeML: dto.initialVolumeML,
                    remainingVolumeML: dto.remainingVolumeML, notes: dto.notes
                )
                solution.statusRawValue = dto.status
                solution.finishedAt = dto.finishedAt
                solution.createdAt = dto.createdAt
                context.insert(solution)
                report.solutionsImported += 1
            }

            // Itens do estoque
            let existingInventoryIDs: Set<UUID> = mode == .merge
                ? Set(try context.fetch(FetchDescriptor<LensInventoryItem>()).map(\.id))
                : []
            for dto in envelope.inventoryItems ?? [] {
                if mode == .merge, existingInventoryIDs.contains(dto.id) {
                    report.inventoryItemsSkippedAsDuplicate += 1
                    continue
                }
                let item = LensInventoryItem(
                    id: dto.id, brand: dto.brand, model: dto.model, prescriptionOD: dto.prescriptionOD,
                    prescriptionOS: dto.prescriptionOS, side: LensSide(rawValue: dto.side) ?? .both, lot: dto.lot,
                    expiryDate: dto.expiryDate, initialQuantity: dto.initialQuantity, photoData: dto.photoData,
                    notes: dto.notes
                )
                item.remainingQuantity = dto.remainingQuantity
                item.statusRawValue = dto.status
                item.createdAt = dto.createdAt
                context.insert(item)
                report.inventoryItemsImported += 1
            }

            // Profissionais — mantém um mapa id → EyeCareProfessional (novo ou já existente)
            // para religar as consultas.
            let existingProfessionals = mode == .merge ? try EyeCareProfessionalService.allProfessionals(context: context) : []
            let existingProfessionalsByID = Dictionary(uniqueKeysWithValues: existingProfessionals.map { ($0.id, $0) })
            var professionalsByID: [UUID: EyeCareProfessional] = [:]
            for dto in envelope.professionals ?? [] {
                if mode == .merge, let existing = existingProfessionalsByID[dto.id] {
                    report.professionalsSkippedAsDuplicate += 1
                    professionalsByID[dto.id] = existing
                    continue
                }
                let professional = EyeCareProfessional(
                    id: dto.id, name: dto.name, clinic: dto.clinic, phone: dto.phone, whatsapp: dto.whatsapp,
                    email: dto.email, address: dto.address, notes: dto.notes
                )
                professional.createdAt = dto.createdAt
                context.insert(professional)
                professionalsByID[dto.id] = professional
                report.professionalsImported += 1
            }

            // Consultas
            let existingAppointmentIDs: Set<UUID> = mode == .merge
                ? Set(try context.fetch(FetchDescriptor<EyeAppointment>()).map(\.id))
                : []
            for dto in envelope.appointments ?? [] {
                if mode == .merge, existingAppointmentIDs.contains(dto.id) {
                    report.appointmentsSkippedAsDuplicate += 1
                    continue
                }
                let professional = dto.professionalID.flatMap { professionalsByID[$0] }
                let appointment = EyeAppointment(
                    id: dto.id, date: dto.date, type: EyeAppointmentType(rawValue: dto.type) ?? .routine,
                    notes: dto.notes, prescription: dto.prescription, attachmentData: dto.attachmentData,
                    recommendedFollowUpMonths: dto.recommendedFollowUpMonths, professional: professional
                )
                appointment.statusRawValue = dto.status
                appointment.createdAt = dto.createdAt
                context.insert(appointment)
                report.appointmentsImported += 1
            }

            // Sessões de uso — religa ao par pelo mesmo mapa usado pelos usos.
            let existingWearSessionIDs: Set<UUID> = mode == .merge
                ? Set(try context.fetch(FetchDescriptor<WearSession>()).map(\.id))
                : []
            for dto in envelope.wearSessions ?? [] {
                if mode == .merge, existingWearSessionIDs.contains(dto.id) {
                    report.wearSessionsSkippedAsDuplicate += 1
                    continue
                }
                let pair = dto.lensPairID.flatMap { pairsByID[$0] }
                let session = WearSession(id: dto.id, startedAt: dto.startedAt, lensPair: pair)
                session.endedAt = dto.endedAt
                session.statusRawValue = dto.status
                session.createdAt = dto.createdAt
                context.insert(session)
                report.wearSessionsImported += 1
            }

            // Configurações — substitui em modo replace; em modo merge, só aplica se ainda não
            // houver nenhuma configuração local (preferências existentes nunca são sobrescritas
            // silenciosamente por uma mesclagem).
            if let settingsDTO = envelope.settings {
                let existingSettings = try context.fetch(FetchDescriptor<AppSettings>())
                if mode == .replace || existingSettings.isEmpty {
                    let settings = AppSettings()
                    applySettingsDTO(settingsDTO, to: settings)
                    context.insert(settings)
                    report.settingsImported = true
                }
            }

            try context.save()
        } catch let error as BackupError {
            context.rollback()
            throw error
        } catch {
            context.rollback()
            throw BackupError.persistenceFailed(error.localizedDescription)
        }

        return report
    }

    private static func applySettingsDTO(_ dto: SettingsDTO, to settings: AppSettings) {
        settings.maximumUses = dto.maximumUses
        settings.cleaningIntervalDays = dto.cleaningIntervalDays
        settings.advanceReminderDays = dto.advanceReminderDays
        settings.notificationHour = dto.notificationHour
        settings.notificationMinute = dto.notificationMinute
        settings.allowMultipleUsesPerDay = dto.allowMultipleUsesPerDay
        settings.advanceReminderEnabled = dto.advanceReminderEnabled
        settings.deadlineReminderEnabled = dto.deadlineReminderEnabled
        settings.soundEnabled = dto.soundEnabled
        settings.badgeEnabled = dto.badgeEnabled
        settings.trackingModeRawValue = dto.trackingMode
        settings.healthGoodBelowPercent = dto.healthGoodBelowPercent ?? 80
        settings.healthWarningBelowPercent = dto.healthWarningBelowPercent ?? 40
        settings.healthCriticalBelowPercent = dto.healthCriticalBelowPercent ?? 15
        settings.wearingReminderHours = dto.wearingReminderHours ?? 8
        settings.wearingExcessiveRepeatIntervalHours = dto.wearingExcessiveRepeatIntervalHours ?? 1
        settings.caseReplacementIntervalDays = dto.caseReplacementIntervalDays ?? 90
        settings.caseReminderEnabled = dto.caseReminderEnabled ?? true
        settings.caseOverdueReminderIntervalDays = dto.caseOverdueReminderIntervalDays ?? 7
        settings.solutionReminderEnabled = dto.solutionReminderEnabled ?? true
        settings.solutionOverdueReminderIntervalDays = dto.solutionOverdueReminderIntervalDays ?? 7
        settings.inventoryReminderEnabled = dto.inventoryReminderEnabled ?? true
        settings.appointmentReminderEnabled = dto.appointmentReminderEnabled ?? true
        settings.defaultAppointmentIntervalMonths = dto.defaultAppointmentIntervalMonths ?? 12
    }
}
