import SwiftUI
import SwiftData

/// Aba Início: resumo somente-leitura do estado atual — par(es) em uso e estojo. Nenhuma ação
/// de gerenciamento mora aqui; registrar uso, editar ou encerrar um par acontece na aba Lentes,
/// tocar num par aqui leva direto ao diário dele lá.
struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LensPair.sequenceNumber) private var allPairs: [LensPair]
    @Query private var allSettings: [AppSettings]
    @Query(sort: \CaseCleaning.cleaningDate, order: .reverse) private var cleanings: [CaseCleaning]
    @Query(sort: \LensCase.startDate, order: .reverse) private var cases: [LensCase]
    @Query(sort: \CleaningSolution.openedDate, order: .reverse) private var solutions: [CleaningSolution]
    @Query(sort: \EyeAppointment.date) private var appointments: [EyeAppointment]

    @State private var caseViewModel = CaseCleaningViewModel()
    @State private var router = AppRouter.shared

    private var settings: AppSettings {
        allSettings.first ?? AppSettings()
    }

    private var inUsePairs: [LensPair] {
        allPairs.filter { $0.status == .inUse && $0.deletedAt == nil }
    }

    private var reservePairs: [LensPair] {
        allPairs.filter { $0.status == .reserve && $0.deletedAt == nil }
    }

    private var lastCleaning: CaseCleaning? { cleanings.first }
    private var activeCase: LensCase? { cases.first { $0.status == .active } }
    private var activeSolution: CleaningSolution? { solutions.first { $0.status == .active } }
    private var nextAppointment: EyeAppointment? {
        appointments.first { $0.status == .scheduled && $0.date >= Date() }
    }

    private var hasReminders: Bool {
        activeCase != nil || activeSolution != nil || nextAppointment != nil
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 0..<12: return "Bom dia"
        case 12..<18: return "Boa tarde"
        default: return "Boa noite"
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Text(greeting)
                        .font(.title3.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if inUsePairs.isEmpty && reservePairs.isEmpty {
                        emptyState
                    } else {
                        summaryContent
                    }

                    if hasReminders {
                        remindersCard
                    }

                    CaseSummaryCardView(
                        lastCleaning: lastCleaning,
                        settings: settings,
                        onRegisterCleaningToday: {
                            Task { await caseViewModel.registerCleaningToday(settings: settings, context: modelContext) }
                        }
                    )
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .navigationTitle("Minhas Lentes")
            .overlay(alignment: .bottom) {
                if caseViewModel.showUndoToast, let message = caseViewModel.toastMessage {
                    ConfirmationToast(message: message, actionTitle: "Desfazer") {
                        Task { await caseViewModel.undoLastRegisteredCleaning(settings: settings, context: modelContext) }
                    }
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.snappy, value: caseViewModel.showUndoToast)
            .alert(
                "Não foi possível concluir a ação",
                isPresented: Binding(
                    get: { caseViewModel.presentedError != nil },
                    set: { if !$0 { caseViewModel.presentedError = nil } }
                ),
                presenting: caseViewModel.presentedError
            ) { _ in
                Button("OK", role: .cancel) {}
            } message: { error in
                Text(error.message)
            }
        }
    }

    @ViewBuilder
    private var summaryContent: some View {
        if !inUsePairs.isEmpty {
            SectionCard(title: "Em uso") {
                VStack(spacing: 10) {
                    ForEach(inUsePairs) { pair in
                        pairSummaryRow(for: pair)
                        if pair.id != inUsePairs.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
        if !reservePairs.isEmpty {
            Button {
                router.selectedTab = .lentes
            } label: {
                HStack {
                    Text("\(reservePairs.count) par(es) reserva disponível(is)")
                        .font(.subheadline)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
            }
            .buttonStyle(.plain)
        }
    }

    private var remindersCard: some View {
        SectionCard(title: "Lembretes") {
            VStack(spacing: 10) {
                if let activeCase {
                    reminderRow(
                        icon: "shippingbox",
                        title: "Estojo",
                        detail: caseReminderDetail(activeCase),
                        tab: .cuidados
                    )
                }
                if activeCase != nil && (activeSolution != nil || nextAppointment != nil) {
                    Divider()
                }
                if let activeSolution {
                    reminderRow(
                        icon: "flask",
                        title: "Solução",
                        detail: solutionReminderDetail(activeSolution),
                        tab: .cuidados
                    )
                }
                if activeSolution != nil && nextAppointment != nil {
                    Divider()
                }
                if let nextAppointment {
                    reminderRow(
                        icon: "stethoscope",
                        title: "Consulta",
                        detail: appointmentReminderDetail(nextAppointment),
                        tab: .consultas
                    )
                }
            }
        }
    }

    private func reminderRow(icon: String, title: String, detail: String, tab: AppTab) -> some View {
        Button {
            router.selectedTab = tab
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.medium))
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
    }

    private func caseReminderDetail(_ lensCase: LensCase) -> String {
        let days = LensStatisticsService.daysUntil(lensCase.nextRecommendedReplacementDate)
        return days <= 0 ? "Substituição recomendada já se aproximou" : "Substituição recomendada em \(days) dia(s)"
    }

    private func solutionReminderDetail(_ solution: CleaningSolution) -> String {
        let days = LensStatisticsService.daysUntil(solution.discardDate)
        return days <= 0 ? "Validade recomendada já se aproximou" : "Descarte recomendado em \(days) dia(s)"
    }

    private func appointmentReminderDetail(_ appointment: EyeAppointment) -> String {
        let dateText = DateFormatting.short.string(from: appointment.date)
        if let name = appointment.professional?.name {
            return "\(dateText) com \(name)"
        }
        return dateText
    }

    private func pairSummaryRow(for pair: LensPair) -> some View {
        let status = LensStatisticsService.usageStatus(
            usesRemaining: pair.usesRemaining,
            maximumUses: pair.maximumUses,
            goodBelowPercent: settings.healthGoodBelowPercent,
            warningBelowPercent: settings.healthWarningBelowPercent,
            criticalBelowPercent: settings.healthCriticalBelowPercent
        )
        return Button {
            router.openPair(pair.id)
        } label: {
            HStack(spacing: 10) {
                Text(status.emoji)
                VStack(alignment: .leading, spacing: 2) {
                    Text(pair.name)
                        .font(.subheadline.weight(.medium))
                    Text("\(pair.usesRemaining) de \(pair.maximumUses) usos restantes — \(status.label)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            ContentUnavailableView(
                "Nenhum par cadastrado",
                systemImage: "eyeglasses",
                description: Text("Vá para a aba Lentes para iniciar seu primeiro par.")
            )
            Button {
                router.selectedTab = .lentes
            } label: {
                Label("Ir para Lentes", systemImage: "arrow.right.circle.fill")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.top, 40)
    }
}

#Preview {
    HomeView()
        .modelContainer(PreviewData.container)
}
