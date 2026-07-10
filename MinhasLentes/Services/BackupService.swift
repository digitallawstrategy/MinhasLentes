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
    }

    // MARK: - Exportação

    static func exportJSON(context: ModelContext) throws -> URL {
        let pairs = try LensPairService.allPairs(context: context)
        let cleanings = try CaseCleaningService.allCleanings(context: context)

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
                    healthCriticalBelowPercent: s.healthCriticalBelowPercent
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
        guard !envelope.pairs.isEmpty || !envelope.cleanings.isEmpty || envelope.settings != nil else {
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
    }
}
