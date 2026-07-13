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
    #if DEBUG
    @State private var uiTestShowHistory = false
    @State private var uiTestShowDados = false
    #endif

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
                notificationStatusSection
                // `.minimumScaleFactor` não tem efeito dentro de uma linha de `List`/`Form` neste
                // iOS — testado tanto na `Section` quanto direto no `Text` interno do `Label`, o
                // texto truncava com reticências do mesmo jeito nos dois casos, validado por
                // screenshot real no simulador. A saída que a própria Apple recomenda para
                // elementos de navegação/chrome (abas, itens de lista curtos) é limitar o teto de
                // Dynamic Type desses rótulos, deixando o conteúdo de cada tela (o que precisa ser
                // lido) continuar escalando livremente até accessibility-XXXL. `accessibility1`
                // ainda é bem maior que o tamanho padrão — só não chega ao extremo em que
                // "Desenvolvimento" (a mais longa) não cabe ao lado do ícone e do indicador de
                // navegação sem hifenizar.
                Section {
                    NavigationLink { rotinaScreen } label: { Label("Rotina", systemImage: "gauge.with.dots.needle.67percent") }
                    NavigationLink { lembretesScreen } label: { Label("Lembretes", systemImage: "bell.badge") }
                    NavigationLink { dadosScreen } label: { Label("Dados", systemImage: "externaldrive") }
                    NavigationLink { avancadoScreen } label: { Label("Avançado", systemImage: "gearshape.2") }
                }
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                #if DEBUG
                Section {
                    NavigationLink { developerToolsScreen } label: { Label("Desenvolvimento", systemImage: "ladybug") }
                }
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                #endif
            }
            .navigationTitle("Configurações")
            .tabBarScrollInset()
            .task {
                await viewModel.refreshAuthorizationStatus()
                #if DEBUG
                if UITestSupport.requestedRoute() == .historico {
                    uiTestShowHistory = true
                }
                if UITestSupport.requestedRoute() == .dados {
                    uiTestShowDados = true
                }
                #endif
            }
            #if DEBUG
            .navigationDestination(isPresented: $uiTestShowHistory) {
                HistoryView()
            }
            .navigationDestination(isPresented: $uiTestShowDados) {
                dadosScreen
            }
            #endif
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
        lines.append("Pares: \(Pluralization.count(report.pairsImported, "importado", "importados")), \(Pluralization.count(report.pairsSkippedAsDuplicate, "ignorado", "ignorados")) por já existir.")
        lines.append("Usos: \(Pluralization.count(report.usagesImported, "importado", "importados")), \(Pluralization.count(report.usagesSkippedAsDuplicate, "ignorado", "ignorados")) por já existir.")
        lines.append("Limpezas: \(Pluralization.count(report.cleaningsImported, "importada", "importadas")), \(Pluralization.count(report.cleaningsSkippedAsDuplicate, "ignorada", "ignoradas")) por já existir.")
        lines.append("Eventos de histórico: \(Pluralization.count(report.eventsImported, "importado", "importados")), \(Pluralization.count(report.eventsSkippedAsDuplicate, "ignorado", "ignorados")) por já existir.")
        lines.append("Ciclos do estojo: \(Pluralization.count(report.casesImported, "importado", "importados")), \(Pluralization.count(report.casesSkippedAsDuplicate, "ignorado", "ignorados")) por já existir.")
        lines.append("Cuidados diários: \(Pluralization.count(report.routineCareLogsImported, "importado", "importados")), \(Pluralization.count(report.routineCareLogsSkippedAsDuplicate, "ignorado", "ignorados")) por já existir.")
        lines.append("Soluções de limpeza: \(Pluralization.count(report.solutionsImported, "importada", "importadas")), \(Pluralization.count(report.solutionsSkippedAsDuplicate, "ignorada", "ignoradas")) por já existir.")
        lines.append("Itens de estoque: \(Pluralization.count(report.inventoryItemsImported, "importado", "importados")), \(Pluralization.count(report.inventoryItemsSkippedAsDuplicate, "ignorado", "ignorados")) por já existir.")
        lines.append("Profissionais: \(Pluralization.count(report.professionalsImported, "importado", "importados")), \(Pluralization.count(report.professionalsSkippedAsDuplicate, "ignorado", "ignorados")) por já existir.")
        lines.append("Consultas: \(Pluralization.count(report.appointmentsImported, "importada", "importadas")), \(Pluralization.count(report.appointmentsSkippedAsDuplicate, "ignorada", "ignoradas")) por já existir.")
        lines.append("Sessões de uso: \(Pluralization.count(report.wearSessionsImported, "importada", "importadas")), \(Pluralization.count(report.wearSessionsSkippedAsDuplicate, "ignorada", "ignoradas")) por já existir.")
        lines.append("Configurações: \(report.settingsImported ? "importadas" : "mantidas as atuais").")
        return lines.joined(separator: "\n")
    }

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

    // MARK: - Grupos (Rotina, Lembretes, Dados, Avançado, Desenvolvimento)
    //
    // Antes, Configurações era um Form só com 12 seções soltas, uma atrás da outra — cada
    // preferência individual competindo pelo mesmo nível de atenção que uma ação destrutiva como
    // "Apagar todos os dados". Agrupar em 4-5 telas (mesmo padrão do próprio Ajustes da Apple:
    // "Geral", "Tela e Brilho" etc. como linhas que abrem outra tela, não uma lista plana) deixa
    // a tela raiz curta e cada sub-tela focada num só assunto.

    private var rotinaScreen: some View {
        Form { lentesSection }
            .navigationTitle("Rotina")
            .navigationBarTitleDisplayMode(.inline)
    }

    private var lembretesScreen: some View {
        Form {
            caseSection
            solutionSection
            inventorySection
            appointmentSection
            notificationPreferencesSection
        }
        .navigationTitle("Lembretes")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var dadosScreen: some View {
        Form {
            CloudSyncStatusSection()
            backupSection
            exportSection
            dataSection
        }
        .navigationTitle("Dados")
        .navigationBarTitleDisplayMode(.inline)
    }

    // Faixas de status e detalhes de persistência são informação de apoio, não algo que se
    // ajusta no dia a dia — ficam aqui, não na tela raiz.
    private var avancadoScreen: some View {
        Form {
            healthSection
            persistenceInfoSection
        }
        .navigationTitle("Avançado")
        .navigationBarTitleDisplayMode(.inline)
    }

    #if DEBUG
    private var developerToolsScreen: some View {
        Form { developerToolsSection }
            .navigationTitle("Desenvolvimento")
            .navigationBarTitleDisplayMode(.inline)
    }
    #endif

    // MARK: - Seções (conteúdo de cada grupo)

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

            Stepper("Tempo considerado excessivo: \(settings.wearingReminderHours)h", value: Binding(
                get: { settings.wearingReminderHours },
                set: { settings.wearingReminderHours = $0; saveSettings() }
            ), in: 1...24)

            Stepper("Repetir a cada: \(settings.wearingExcessiveRepeatIntervalHours)h", value: Binding(
                get: { settings.wearingExcessiveRepeatIntervalHours },
                set: { settings.wearingExcessiveRepeatIntervalHours = $0; saveSettings() }
            ), in: 1...12)
        } header: {
            Text("Lentes")
        } footer: {
            Text("Vale só para a próxima sessão iniciada.")
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
            Text("Baseado só na contagem de usos, não na condição física da lente.")
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

            Stepper("Substituir o estojo a cada: \(settings.caseReplacementIntervalDays) dias", value: Binding(
                get: { settings.caseReplacementIntervalDays },
                set: { settings.caseReplacementIntervalDays = $0; saveSettings() }
            ), in: 1...365)

            Toggle("Avisos de substituição do estojo", isOn: Binding(
                get: { settings.caseReminderEnabled },
                set: { settings.caseReminderEnabled = $0; rescheduleLensCaseNotifications() }
            ))

            Stepper("Repetir lembrete a cada: \(settings.caseOverdueReminderIntervalDays) dias", value: Binding(
                get: { settings.caseOverdueReminderIntervalDays },
                set: { settings.caseOverdueReminderIntervalDays = $0; rescheduleLensCaseNotifications() }
            ), in: 1...30)
        } header: {
            Text("Estojo")
        } footer: {
            Text("A antecedência do aviso e a substituição do estojo valem só para o ciclo atual em diante.")
        }
    }

    private var solutionSection: some View {
        Section {
            Toggle("Avisos de validade da solução de limpeza", isOn: Binding(
                get: { settings.solutionReminderEnabled },
                set: { settings.solutionReminderEnabled = $0; rescheduleCleaningSolutionNotifications() }
            ))

            Stepper("Repetir lembrete a cada: \(settings.solutionOverdueReminderIntervalDays) dias", value: Binding(
                get: { settings.solutionOverdueReminderIntervalDays },
                set: { settings.solutionOverdueReminderIntervalDays = $0; rescheduleCleaningSolutionNotifications() }
            ), in: 1...30)
        } header: {
            Text("Solução de limpeza")
        } footer: {
            Text("Sempre informada por frasco, nunca um prazo padrão do app.")
        }
    }

    private var inventorySection: some View {
        Section {
            Toggle("Avisos de validade do estoque", isOn: Binding(
                get: { settings.inventoryReminderEnabled },
                set: { settings.inventoryReminderEnabled = $0; rescheduleInventoryNotifications() }
            ))
        } header: {
            Text("Estoque de lentes")
        } footer: {
            Text("Sem lembrete repetido depois de vencido — o app só pede confirmação extra ao usar o item.")
        }
    }

    private var appointmentSection: some View {
        Section {
            Toggle("Lembretes de consulta", isOn: Binding(
                get: { settings.appointmentReminderEnabled },
                set: { settings.appointmentReminderEnabled = $0; rescheduleAppointmentNotifications() }
            ))
            Stepper("Prazo padrão até a próxima: \(settings.defaultAppointmentIntervalMonths) meses", value: Binding(
                get: { settings.defaultAppointmentIntervalMonths },
                set: { settings.defaultAppointmentIntervalMonths = $0; saveSettings() }
            ), in: 1...24)
        } header: {
            Text("Consultas")
        } footer: {
            Text("O prazo padrão vale só para novas consultas — siga a recomendação do seu oftalmologista.")
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
            Text("Backup completo, com relacionamentos preservados — diferente do CSV/PDF, pode ser reimportado para restaurar os dados neste ou em outro aparelho.")
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
                Label("Atualizar ou reinstalar pela mesma conta preserva os dados.", systemImage: "arrow.triangle.2.circlepath")
                Label("Apagar o app remove os dados locais sem volta.", systemImage: "trash")
                Label("Exporte um backup em JSON antes de apagar o app.", systemImage: "checkmark.shield")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .labelStyle(.titleAndIcon)
        }
    }

    private var dataSection: some View {
        Section("Dados") {
            NavigationLink {
                HistoryView()
            } label: {
                Label("Histórico", systemImage: "clock")
            }
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
            NavigationLink {
                DataDiagnosticsView()
            } label: {
                Label("Diagnóstico de dados", systemImage: "wrench.and.screwdriver")
            }
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

    private func rescheduleLensCaseNotifications() {
        Task { await viewModel.rescheduleLensCaseNotifications(settings: settings, context: modelContext) }
    }

    private func rescheduleCleaningSolutionNotifications() {
        Task { await viewModel.rescheduleCleaningSolutionNotifications(settings: settings, context: modelContext) }
    }

    private func rescheduleInventoryNotifications() {
        Task { await viewModel.rescheduleLensInventoryNotifications(settings: settings, context: modelContext) }
    }

    private func rescheduleAppointmentNotifications() {
        Task { await viewModel.rescheduleEyeAppointmentNotifications(settings: settings, context: modelContext) }
    }
}

#Preview {
    SettingsView()
        .modelContainer(PreviewData.container)
}
