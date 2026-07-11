import SwiftUI
import SwiftData

/// Destino "Estojo" dentro da aba Cuidados: ciclo de vida, cuidado diário, limpeza periódica e
/// histórico.
struct CaseView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \CaseCleaning.cleaningDate, order: .reverse) private var cleanings: [CaseCleaning]
    @Query(sort: \LensCase.startDate, order: .reverse) private var cases: [LensCase]
    @Query(sort: \RoutineCareLog.date, order: .reverse) private var routineCareLogs: [RoutineCareLog]
    @Query private var allSettings: [AppSettings]

    @State private var cleaningViewModel = CaseCleaningViewModel()
    @State private var lensCaseViewModel = LensCaseViewModel()
    @State private var routineCareViewModel = RoutineCareViewModel()
    @State private var showRegisterOtherDate = false
    @State private var customDate = Date()
    @State private var customNotes = ""
    @State private var cleaningToDelete: CaseCleaning?
    @State private var cleaningToEdit: CaseCleaning?
    @State private var showStartOrReplaceCase = false
    @State private var showRegisterRoutineCareDetails = false
    @State private var routineDate = Date()
    @State private var routineDiscardedSolution = true
    @State private var routineCleanedCase = true
    @State private var routineAirDried = true
    @State private var routineNotes = ""

    private var settings: AppSettings {
        allSettings.first ?? AppSettings()
    }

    private var activeCase: LensCase? { cases.first { $0.status == .active } }
    private var lastRoutineCare: RoutineCareLog? { routineCareLogs.first }

    private var daysUntilCaseReplacement: Int? {
        guard let activeCase else { return nil }
        return LensStatisticsService.daysUntil(activeCase.nextRecommendedReplacementDate)
    }

    private func caseSituationText(_ days: Int) -> String {
        if days > 0 { return "Faltam \(days) dia(s)" }
        if days == 0 { return "Substituição recomendada para hoje" }
        return "Substituição recomendada há \(-days) dia(s)"
    }

    private var lastCleaning: CaseCleaning? { cleanings.first }

    private var daysSinceLastCleaning: Int? {
        guard let lastCleaning else { return nil }
        return LensStatisticsService.daysSince(lastCleaning.cleaningDate)
    }

    private var daysUntilNextCleaning: Int? {
        guard let nextCleaningDate else { return nil }
        return LensStatisticsService.daysUntil(nextCleaningDate)
    }

    private var countdownFraction: Double {
        guard let daysUntilNextCleaning, settings.cleaningIntervalDays > 0 else { return 0 }
        return min(max(Double(daysUntilNextCleaning) / Double(settings.cleaningIntervalDays), 0), 1)
    }

    private var countdownTone: AppStatusTone {
        guard let daysUntilNextCleaning else { return .informative }
        if daysUntilNextCleaning <= 0 { return .critical }
        if daysUntilNextCleaning <= settings.advanceReminderDays { return .warning }
        return .success
    }

    private var nextCleaningDate: Date? {
        guard let lastCleaning else { return nil }
        return LensStatisticsService.nextCleaningDate(
            lastCleaningDate: lastCleaning.cleaningDate,
            intervalDays: settings.cleaningIntervalDays
        )
    }

    private var advanceReminderDate: Date? {
        guard let lastCleaning else { return nil }
        return LensStatisticsService.advanceReminderDate(
            lastCleaningDate: lastCleaning.cleaningDate,
            intervalDays: settings.cleaningIntervalDays,
            advanceDays: settings.advanceReminderDays
        )
    }

    @ViewBuilder
    private var caseLifecycleCard: some View {
        AppCard {
            SectionHeader("Ciclo do estojo")
            if let activeCase {
                VStack(spacing: AppSpacing.xxs) {
                    StatRow(label: "Início do ciclo atual", value: DateFormatting.short.string(from: activeCase.startDate))
                    StatRow(label: "Substituição recomendada", value: DateFormatting.short.string(from: activeCase.nextRecommendedReplacementDate))
                    StatRow(label: "Intervalo configurado", value: "\(activeCase.intervalDays) dias")
                    if let daysUntilCaseReplacement {
                        StatRow(label: "Situação", value: caseSituationText(daysUntilCaseReplacement))
                    }
                }
                PrimaryActionButton(title: "Substituí o estojo", systemImage: "shippingbox") {
                    showStartOrReplaceCase = true
                }
                .padding(.top, AppSpacing.xxs)
            } else {
                Text("Nenhum ciclo de estojo iniciado ainda.")
                    .font(AppTypography.subheadline)
                    .foregroundStyle(.secondary)
                PrimaryActionButton(title: "Iniciar acompanhamento do estojo", systemImage: "shippingbox") {
                    showStartOrReplaceCase = true
                }
                .padding(.top, AppSpacing.xxs)
            }

            NavigationLink("Ver histórico de ciclos") {
                LensCaseHistoryView()
            }
            .font(AppTypography.subheadline)
            .padding(.top, AppSpacing.xxs)
        }
    }

    @ViewBuilder
    private var routineCareCard: some View {
        AppCard {
            SectionHeader("Cuidado diário")
            if let lastRoutineCare {
                StatRow(label: "Último registro", value: DateFormatting.shortWithTime.string(from: lastRoutineCare.date))
            } else {
                Text("Nenhum cuidado diário registrado ainda.")
                    .font(AppTypography.subheadline)
                    .foregroundStyle(.secondary)
            }
            Text("Descartar a solução usada, limpar o estojo e deixá-lo secar ao ar livre, todos os dias após remover as lentes. O registro rápido do dia fica na aba Início — aqui dá para registrar com mais detalhes ou revisar o histórico.")
                .font(AppTypography.footnote)
                .foregroundStyle(.secondary)

            SecondaryActionButton(title: "Registrar em outro dia", fullWidth: false) {
                routineDate = Date()
                routineDiscardedSolution = true
                routineCleanedCase = true
                routineAirDried = true
                routineNotes = ""
                showRegisterRoutineCareDetails = true
            }
            .controlSize(.small)
            .padding(.top, AppSpacing.xxs)

            Divider()
                .padding(.vertical, AppSpacing.xxs)
            MonthlyCareCalendarView(
                loggedDates: routineCareLogs.map(\.date),
                secondaryLoggedDates: cleanings.map(\.cleaningDate)
            )
        }
    }

    @ViewBuilder
    private var periodicCleaningCard: some View {
        AppCard {
            SectionHeader("Estojo")
            VStack(spacing: AppSpacing.xxs) {
                if let lastCleaning {
                    StatRow(label: "Última limpeza", value: DateFormatting.short.string(from: lastCleaning.cleaningDate))
                } else {
                    StatRow(label: "Última limpeza", value: "Nenhuma registrada")
                }
                if let daysSinceLastCleaning {
                    StatRow(label: "Dias desde a limpeza", value: "\(daysSinceLastCleaning) dia(s)")
                }
                if let advanceReminderDate {
                    StatRow(label: "Aviso antecipado", value: DateFormatting.short.string(from: advanceReminderDate))
                }
                if let nextCleaningDate {
                    StatRow(label: "Prazo da limpeza", value: DateFormatting.short.string(from: nextCleaningDate))
                }
                StatRow(label: "Intervalo configurado", value: "\(settings.cleaningIntervalDays) dias")
            }

            if let daysUntilNextCleaning {
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(daysUntilNextCleaning <= 0 ? "Limpeza atrasada" : "Faltam \(daysUntilNextCleaning) dia(s) para a próxima limpeza")
                        .font(AppTypography.footnote.weight(.medium))
                        .foregroundStyle(countdownTone.color)
                    ProgressBarView(fraction: countdownFraction, tint: countdownTone.color)
                        .animation(reduceMotion ? nil : AppAnimation.standard, value: countdownFraction)
                }
                .padding(.top, AppSpacing.xxs)
            }

            VStack(spacing: AppSpacing.sm) {
                PrimaryActionButton(title: "Limpei o estojo hoje", systemImage: "sparkles") {
                    Task { await cleaningViewModel.registerCleaningToday(settings: settings, context: modelContext) }
                }

                SecondaryActionButton(title: "Registrar em outra data", fullWidth: false) {
                    customDate = Date()
                    customNotes = ""
                    showRegisterOtherDate = true
                }
                .controlSize(.small)
            }
            .padding(.top, AppSpacing.xxs)
        }
    }

    @ViewBuilder
    private var cleaningHistoryCard: some View {
        AppCard {
            SectionHeader("Histórico de limpezas")
            if cleanings.isEmpty {
                Text("Nenhuma limpeza registrada ainda.")
                    .font(AppTypography.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    ForEach(cleanings) { cleaning in
                        HStack(alignment: .top) {
                            Image(systemName: "sparkles")
                                .foregroundStyle(AppColor.primary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(DateFormatting.shortWithTime.string(from: cleaning.cleaningDate))
                                    .font(AppTypography.subheadlineMedium)
                                if let notes = cleaning.notes, !notes.isEmpty {
                                    Text(notes)
                                        .font(AppTypography.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Button {
                                cleaningToEdit = cleaning
                            } label: {
                                Image(systemName: "pencil")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Editar limpeza de \(DateFormatting.shortWithTime.string(from: cleaning.cleaningDate))")

                            Button(role: .destructive) {
                                cleaningToDelete = cleaning
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Excluir limpeza de \(DateFormatting.shortWithTime.string(from: cleaning.cleaningDate))")
                        }
                    }
                }
            }
        }
    }

    private var toastTransition: AnyTransition {
        reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity)
    }

    var body: some View {
            ScrollView {
                VStack(spacing: AppSpacing.md) {
                    caseLifecycleCard
                    routineCareCard
                    periodicCleaningCard
                    cleaningHistoryCard
                }
                .padding(.horizontal)
                .padding(.top, AppSpacing.xs)
                .padding(.bottom, AppSpacing.xxl)
            }
            .navigationTitle("Estojo")
            .overlay(alignment: .bottom) {
                if cleaningViewModel.showUndoToast, let message = cleaningViewModel.toastMessage {
                    ConfirmationToast(message: message, actionTitle: "Desfazer") {
                        Task { await cleaningViewModel.undoLastRegisteredCleaning(settings: settings, context: modelContext) }
                    }
                    .padding(.bottom, AppSpacing.xs)
                    .transition(toastTransition)
                } else if routineCareViewModel.showUndoToast, let message = routineCareViewModel.toastMessage {
                    ConfirmationToast(message: message, actionTitle: "Desfazer") {
                        routineCareViewModel.undoLastRegisteredRoutineCare(context: modelContext)
                    }
                    .padding(.bottom, AppSpacing.xs)
                    .transition(toastTransition)
                }
            }
            .animation(reduceMotion ? nil : AppAnimation.standard, value: cleaningViewModel.showUndoToast)
            .animation(reduceMotion ? nil : AppAnimation.standard, value: routineCareViewModel.showUndoToast)
            .sheet(isPresented: $showRegisterOtherDate) {
                NavigationStack {
                    Form {
                        DatePicker("Data da limpeza", selection: $customDate, displayedComponents: [.date, .hourAndMinute])
                        TextField("Observação (opcional)", text: $customNotes, axis: .vertical)
                            .lineLimit(2...4)
                    }
                    .navigationTitle("Registrar limpeza")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancelar") { showRegisterOtherDate = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Salvar") {
                                Task {
                                    await cleaningViewModel.registerCleaning(
                                        date: customDate,
                                        notes: customNotes.isEmpty ? nil : customNotes,
                                        settings: settings,
                                        context: modelContext
                                    )
                                    showRegisterOtherDate = false
                                }
                            }
                        }
                    }
                }
                .presentationDetents([.medium])
            }
            .sheet(item: $cleaningToEdit) { cleaning in
                EditCleaningSheet(cleaning: cleaning) { date, notes in
                    Task { await cleaningViewModel.editCleaning(cleaning, newDate: date, newNotes: notes, settings: settings, context: modelContext) }
                }
            }
            .sheet(isPresented: $showStartOrReplaceCase) {
                StartOrReplaceCaseSheet(
                    isReplacing: activeCase != nil,
                    defaultIntervalDays: settings.caseReplacementIntervalDays
                ) { startDate, intervalDays, notes in
                    Task { await lensCaseViewModel.startOrReplaceCase(startDate: startDate, intervalDays: intervalDays, notes: notes, settings: settings, context: modelContext) }
                }
            }
            .sheet(isPresented: $showRegisterRoutineCareDetails) {
                NavigationStack {
                    Form {
                        DatePicker("Data", selection: $routineDate, displayedComponents: [.date, .hourAndMinute])
                        Toggle("Descartei a solução usada", isOn: $routineDiscardedSolution)
                        Toggle("Limpei o estojo", isOn: $routineCleanedCase)
                        Toggle("Deixei secar ao ar livre", isOn: $routineAirDried)
                        TextField("Observação (opcional)", text: $routineNotes, axis: .vertical)
                            .lineLimit(2...4)
                    }
                    .navigationTitle("Cuidado diário")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancelar") { showRegisterRoutineCareDetails = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Salvar") {
                                routineCareViewModel.registerRoutineCare(
                                    date: routineDate, discardedSolution: routineDiscardedSolution,
                                    cleanedCase: routineCleanedCase, airDried: routineAirDried,
                                    notes: routineNotes.isEmpty ? nil : routineNotes, context: modelContext
                                )
                                showRegisterRoutineCareDetails = false
                            }
                        }
                    }
                }
                .presentationDetents([.medium])
            }
            .alert(
                "Não foi possível concluir a ação",
                isPresented: Binding(
                    get: { cleaningViewModel.presentedError != nil },
                    set: { if !$0 { cleaningViewModel.presentedError = nil } }
                ),
                presenting: cleaningViewModel.presentedError
            ) { _ in
                Button("OK", role: .cancel) {}
            } message: { error in
                Text(error.message)
            }
            .alert(
                "Não foi possível concluir a ação",
                isPresented: Binding(
                    get: { lensCaseViewModel.presentedError != nil },
                    set: { if !$0 { lensCaseViewModel.presentedError = nil } }
                ),
                presenting: lensCaseViewModel.presentedError
            ) { _ in
                Button("OK", role: .cancel) {}
            } message: { error in
                Text(error.message)
            }
            .alert(
                "Não foi possível concluir a ação",
                isPresented: Binding(
                    get: { routineCareViewModel.presentedError != nil },
                    set: { if !$0 { routineCareViewModel.presentedError = nil } }
                ),
                presenting: routineCareViewModel.presentedError
            ) { _ in
                Button("OK", role: .cancel) {}
            } message: { error in
                Text(error.message)
            }
            .confirmationDialog(
                "Já existe um cuidado diário registrado nesta data. Registrar mesmo assim?",
                isPresented: $routineCareViewModel.showDuplicateConfirmation,
                titleVisibility: .visible
            ) {
                Button("Registrar mesmo assim") {
                    routineCareViewModel.confirmDuplicateRegistration(context: modelContext)
                }
                Button("Cancelar", role: .cancel) {
                    routineCareViewModel.cancelDuplicateRegistration()
                }
            }
            .alert(
                "Excluir limpeza?",
                isPresented: Binding(
                    get: { cleaningToDelete != nil },
                    set: { if !$0 { cleaningToDelete = nil } }
                )
            ) {
                Button("Cancelar", role: .cancel) { cleaningToDelete = nil }
                Button("Excluir", role: .destructive) {
                    if let cleaning = cleaningToDelete {
                        Task { await cleaningViewModel.deleteCleaning(cleaning, settings: settings, context: modelContext) }
                    }
                    cleaningToDelete = nil
                }
            } message: {
                Text("Os avisos de limpeza serão recalculados a partir do registro anterior, se houver.")
            }
    }
}

#Preview {
    NavigationStack {
        CaseView()
    }
    .modelContainer(PreviewData.container)
}
