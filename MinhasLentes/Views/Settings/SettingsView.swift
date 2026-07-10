import SwiftUI
import SwiftData
import UserNotifications
import UniformTypeIdentifiers

/// Aba Configurações: preferências de uso, notificações, backup/exportação, gerenciamento de
/// dados e, apenas em builds DEBUG, ferramentas de desenvolvimento para testar notificações.
struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allSettings: [AppSettings]
    @Query(sort: \LensPair.sequenceNumber) private var pairs: [LensPair]
    @Query(sort: \CaseCleaning.cleaningDate) private var cleanings: [CaseCleaning]

    @State private var viewModel = SettingsViewModel()
    @State private var showFileImporter = false

    private var settings: AppSettings {
        allSettings.first ?? AppSettings()
    }

    private var notificationTimeBinding: Binding<Date> {
        Binding(
            get: {
                var components = DateComponents()
                components.hour = settings.notificationHour
                components.minute = settings.notificationMinute
                return Calendar.current.date(from: components) ?? Date()
            },
            set: { newValue in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                settings.notificationHour = components.hour ?? 9
                settings.notificationMinute = components.minute ?? 0
                reschedule()
            }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                lentesSection
                healthSection
                caseSection
                notificationStatusSection
                notificationPreferencesSection
                backupSection
                exportSection
                persistenceInfoSection
                dataSection
                #if DEBUG
                developerToolsSection
                #endif
            }
            .navigationTitle("Configurações")
            .task { await viewModel.refreshAuthorizationStatus() }
            .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.json]) { result in
                viewModel.handlePickedBackupFile(result)
            }
            .confirmationDialog(
                "Como deseja importar este backup?",
                isPresented: $viewModel.showImportModeChoice,
                titleVisibility: .visible
            ) {
                Button("Substituir todos os dados", role: .destructive) {
                    viewModel.performImport(mode: .replace, context: modelContext)
                }
                Button("Mesclar sem duplicar") {
                    viewModel.performImport(mode: .merge, context: modelContext)
                }
                Button("Cancelar", role: .cancel) {
                    viewModel.cancelImport()
                }
            } message: {
                Text("Substituir apaga permanentemente os dados atuais antes de importar. Mesclar mantém os dados atuais e adiciona apenas os registros do backup que ainda não existem (por identificador).")
            }
            .alert(
                "Importação concluída",
                isPresented: Binding(
                    get: { viewModel.importReport != nil },
                    set: { if !$0 { viewModel.importReport = nil } }
                ),
                presenting: viewModel.importReport
            ) { _ in
                Button("OK", role: .cancel) {}
            } message: { report in
                Text(importReportSummary(report))
            }
            .confirmationDialog(
                "Alterar o modo de controle pode afetar como os pares existentes são exibidos. Deseja continuar?",
                isPresented: $viewModel.showTrackingModeChangeWarning,
                titleVisibility: .visible
            ) {
                Button("Alterar modo", role: .destructive) {
                    viewModel.confirmTrackingModeChange(settings: settings, context: modelContext)
                }
                Button("Cancelar", role: .cancel) {
                    viewModel.cancelTrackingModeChange()
                }
            }
            .alert("Apagar todos os dados?", isPresented: $viewModel.showEraseConfirmation) {
                Button("Cancelar", role: .cancel) {}
                Button("Apagar tudo permanentemente", role: .destructive) {
                    Task { await viewModel.eraseAllData(context: modelContext) }
                }
            } message: {
                Text("Esta ação apagará permanentemente todo o histórico de usos, pares e limpezas. Deseja continuar?")
            }
            .alert(
                "Não foi possível concluir a ação",
                isPresented: Binding(
                    get: { viewModel.presentedError != nil },
                    set: { if !$0 { viewModel.presentedError = nil } }
                ),
                presenting: viewModel.presentedError
            ) { _ in
                Button("OK", role: .cancel) {}
            } message: { error in
                Text(error.message)
            }
        }
    }

    private func importReportSummary(_ report: BackupService.ImportReport) -> String {
        var lines: [String] = []
        lines.append("Pares: \(report.pairsImported) importado(s), \(report.pairsSkippedAsDuplicate) ignorado(s) por já existir.")
        lines.append("Usos: \(report.usagesImported) importado(s), \(report.usagesSkippedAsDuplicate) ignorado(s) por já existir.")
        lines.append("Limpezas: \(report.cleaningsImported) importada(s), \(report.cleaningsSkippedAsDuplicate) ignorada(s) por já existir.")
        lines.append("Eventos de histórico: \(report.eventsImported) importado(s), \(report.eventsSkippedAsDuplicate) ignorado(s) por já existir.")
        lines.append("Configurações: \(report.settingsImported ? "importadas" : "mantidas as atuais").")
        return lines.joined(separator: "\n")
    }

    // MARK: - Seções

    @ViewBuilder
    private var notificationStatusSection: some View {
        if viewModel.notificationAuthorizationStatus == .denied {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("As notificações estão desativadas. Ative-as nos Ajustes do iPhone para receber os lembretes.")
                        .font(.subheadline)
                    Button("Abrir Ajustes do iPhone") {
                        viewModel.openSystemSettings()
                    }
                }
            }
        }
    }

    private var lentesSection: some View {
        Section {
            Stepper("Limite máximo de usos: \(settings.maximumUses)", value: Binding(
                get: { settings.maximumUses },
                set: { settings.maximumUses = $0; saveSettings() }
            ), in: 1...500)

            Toggle("Permitir múltiplos usos no mesmo dia", isOn: Binding(
                get: { settings.allowMultipleUsesPerDay },
                set: { settings.allowMultipleUsesPerDay = $0; saveSettings() }
            ))

            Picker("Modo de controle", selection: Binding(
                get: { settings.trackingMode },
                set: { viewModel.requestTrackingModeChange(to: $0, current: settings.trackingMode) }
            )) {
                ForEach(TrackingMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }

            Stepper("Lembrete de remoção: \(settings.wearingReminderHours)h", value: Binding(
                get: { settings.wearingReminderHours },
                set: { settings.wearingReminderHours = $0; saveSettings() }
            ), in: 1...24)
        } header: {
            Text("Lentes")
        } footer: {
            Text("O lembrete de remoção vale para a sessão \"Estou usando as lentes\", iniciada pela tela Início.")
        }
    }

    private var healthSection: some View {
        Section {
            Stepper("Vida útil alta acima de \(settings.healthGoodBelowPercent)%", value: Binding(
                get: { settings.healthGoodBelowPercent },
                set: { settings.healthGoodBelowPercent = $0; saveSettings() }
            ), in: (settings.healthWarningBelowPercent + 1)...99)

            Stepper("Vida útil moderada acima de \(settings.healthWarningBelowPercent)%", value: Binding(
                get: { settings.healthWarningBelowPercent },
                set: { settings.healthWarningBelowPercent = $0; saveSettings() }
            ), in: (settings.healthCriticalBelowPercent + 1)...(settings.healthGoodBelowPercent - 1))

            Stepper("Poucos usos restantes acima de \(settings.healthCriticalBelowPercent)%", value: Binding(
                get: { settings.healthCriticalBelowPercent },
                set: { settings.healthCriticalBelowPercent = $0; saveSettings() }
            ), in: 1...(settings.healthWarningBelowPercent - 1))
        } header: {
            Text("Faixas de status de utilização")
        } footer: {
            Text("Definem, pelo percentual de usos restantes, quando o status muda de Vida útil alta para Vida útil moderada, Poucos usos restantes e Limite de usos atingido. É uma leitura da contagem de usos, não uma avaliação da condição física da lente.")
        }
    }

    private var caseSection: some View {
        Section {
            Stepper("Intervalo de limpeza: \(settings.cleaningIntervalDays) dias", value: Binding(
                get: { settings.cleaningIntervalDays },
                set: { newValue in
                    settings.cleaningIntervalDays = newValue
                    if settings.advanceReminderDays >= newValue {
                        settings.advanceReminderDays = max(0, newValue - 1)
                    }
                    reschedule()
                }
            ), in: 1...90)

            Stepper("Antecedência do aviso: \(settings.advanceReminderDays) dias", value: Binding(
                get: { settings.advanceReminderDays },
                set: { settings.advanceReminderDays = $0; reschedule() }
            ), in: 0...max(0, settings.cleaningIntervalDays - 1))

            DatePicker("Horário das notificações", selection: notificationTimeBinding, displayedComponents: .hourAndMinute)
        } header: {
            Text("Estojo")
        } footer: {
            Text("A antecedência do aviso nunca alcança ou ultrapassa o intervalo de limpeza — se você reduzir o intervalo, a antecedência é ajustada automaticamente.")
        }
    }

    private var notificationPreferencesSection: some View {
        Section("Notificações") {
            Toggle("Aviso antecipado", isOn: Binding(
                get: { settings.advanceReminderEnabled },
                set: { settings.advanceReminderEnabled = $0; reschedule() }
            ))
            Toggle("Aviso no prazo", isOn: Binding(
                get: { settings.deadlineReminderEnabled },
                set: { settings.deadlineReminderEnabled = $0; reschedule() }
            ))
            Toggle("Som", isOn: Binding(
                get: { settings.soundEnabled },
                set: { settings.soundEnabled = $0; reschedule() }
            ))
            Toggle("Badge", isOn: Binding(
                get: { settings.badgeEnabled },
                set: { settings.badgeEnabled = $0; reschedule() }
            ))
            if viewModel.notificationAuthorizationStatus == .notDetermined {
                Button("Autorizar notificações") {
                    Task { await viewModel.requestNotificationAuthorization() }
                }
            }
        }
    }

    private var backupSection: some View {
        Section {
            Button("Exportar backup em JSON") {
                viewModel.exportBackup(context: modelContext)
            }
            Button("Importar backup de um arquivo JSON") {
                showFileImporter = true
            }
        } header: {
            Text("Backup completo (JSON)")
        } footer: {
            Text("O backup em JSON contém todos os pares, usos, limpezas, eventos de histórico e configurações, com seus identificadores e relacionamentos — diferente do CSV/PDF, ele pode ser reimportado para restaurar os dados neste ou em outro aparelho.")
        }
    }

    private var exportSection: some View {
        Section("Relatórios (somente leitura)") {
            Button("Exportar histórico em CSV") {
                viewModel.exportCSV(pairs: pairs, cleanings: cleanings)
            }
            Button("Exportar histórico em PDF") {
                viewModel.exportPDF(pairs: pairs, cleanings: cleanings)
            }
            if let url = viewModel.exportedFileURL {
                ShareLink(item: url) {
                    Label("Compartilhar arquivo gerado", systemImage: "square.and.arrow.up")
                }
                .id(url)
            }
        }
    }

    private var persistenceInfoSection: some View {
        Section("Persistência dos dados") {
            VStack(alignment: .leading, spacing: 8) {
                Label("Atualizar o app ou reinstalar pela mesma conta normalmente preserva os dados.", systemImage: "arrow.triangle.2.circlepath")
                Label("Apagar o aplicativo do iPhone remove os dados locais imediatamente e sem volta.", systemImage: "trash")
                Label("Alterar o Bundle Identifier no Xcode cria um novo contêiner vazio — os dados antigos não aparecem no app com o novo identificador.", systemImage: "shippingbox")
                Label("A forma segura de preservar seus dados é exportar um backup em JSON antes de apagar o app ou trocar o Bundle Identifier.", systemImage: "checkmark.shield")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .labelStyle(.titleAndIcon)
        }
    }

    private var dataSection: some View {
        Section("Dados") {
            NavigationLink {
                TrashView()
            } label: {
                LabeledContent("Lixeira") {
                    let trashedCount = pairs.filter { $0.deletedAt != nil }.count
                    if trashedCount > 0 {
                        Text("\(trashedCount)")
                    }
                }
            }
            Button("Restaurar configurações padrão") {
                viewModel.restoreDefaults(settings: settings, context: modelContext)
            }
            Button("Apagar todos os dados", role: .destructive) {
                viewModel.showEraseConfirmation = true
            }
        }
    }

    #if DEBUG
    private var developerToolsSection: some View {
        Section {
            Button("Agendar notificação de teste em 1 minuto") {
                Task { await viewModel.scheduleSingleTestNotification() }
            }
            Button("Agendar duas notificações de teste em 1 e 2 minutos") {
                Task { await viewModel.scheduleTwoTestNotifications() }
            }
            Button("Cancelar notificações de teste", role: .destructive) {
                Task { await viewModel.cancelTestNotifications() }
            }
            Button("Listar notificações pendentes") {
                Task { await viewModel.listPendingNotifications() }
            }
            Button("Listar Live Activities em execução") {
                viewModel.listLiveActivities()
            }
            Button("Encerrar todas as Live Activities", role: .destructive) {
                Task { await viewModel.endAllLiveActivities() }
            }
            if let message = viewModel.devToolsMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if let summary = viewModel.pendingNotificationsSummary {
                Text(summary)
                    .font(.footnote.monospaced())
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Ferramentas de desenvolvimento")
        } footer: {
            Text("Visível apenas em builds DEBUG. Não altera o intervalo de limpeza, a última limpeza registrada, as configurações do usuário, nem as notificações reais do ciclo de limpeza.")
        }
    }
    #endif

    private func saveSettings() {
        do {
            try modelContext.save()
        } catch {
            viewModel.presentedError = IdentifiableError(message: "Não foi possível salvar a configuração. \(error.localizedDescription)")
        }
    }

    private func reschedule() {
        Task { await viewModel.rescheduleNotifications(settings: settings, context: modelContext) }
    }
}

#Preview {
    SettingsView()
        .modelContainer(PreviewData.container)
}
