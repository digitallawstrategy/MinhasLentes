import SwiftUI
import SwiftData

/// Aba Cuidados: dashboard do estojo e da solução de limpeza em profundidade — resumo de cada
/// um, calendário consolidado de cuidado diário/limpeza periódica e orientações gerais. Os
/// registros rápidos do dia a dia (uso das lentes, cuidado diário) ficam na aba Início; aqui é
/// onde se olha o panorama e se administra o que já foi registrado.
struct CuidadosView: View {
    @Query(sort: \LensCase.startDate, order: .reverse) private var cases: [LensCase]
    @Query(sort: \CleaningSolution.openedDate, order: .reverse) private var solutions: [CleaningSolution]
    @Query(sort: \CaseCleaning.cleaningDate, order: .reverse) private var cleanings: [CaseCleaning]
    @Query(sort: \RoutineCareLog.date, order: .reverse) private var routineCareLogs: [RoutineCareLog]

    private var activeCase: LensCase? { cases.first { $0.status == .active } }
    private var activeSolution: CleaningSolution? { solutions.first { $0.status == .active } }
    private var lastCleaning: CaseCleaning? { cleanings.first }
    private var lastRoutineCare: RoutineCareLog? { routineCareLogs.first }

    private var daysUntilCaseReplacement: Int? {
        guard let activeCase else { return nil }
        return LensStatisticsService.daysUntil(activeCase.nextRecommendedReplacementDate)
    }

    private var daysUntilSolutionDiscard: Int? {
        guard let activeSolution else { return nil }
        return LensStatisticsService.daysUntil(activeSolution.discardDate)
    }

    private func caseSituationText(_ days: Int) -> String {
        if days > 0 { return "Faltam \(days) dia(s)" }
        if days == 0 { return "Substituição recomendada para hoje" }
        return "Substituição recomendada há \(-days) dia(s)"
    }

    private func solutionSituationText(_ days: Int) -> String {
        if days > 0 { return "Faltam \(days) dia(s)" }
        if days == 0 { return "Descarte recomendado para hoje" }
        return "Descarte recomendado há \(-days) dia(s)"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.md) {
                    caseSummaryCard
                    solutionSummaryCard
                    calendarCard
                    orientationsCard
                }
                .padding(.horizontal)
                .padding(.top, AppSpacing.xs)
                .padding(.bottom, AppSpacing.xxl)
            }
            .background(AmbientBackground())
            .navigationTitle("Cuidados")
        }
    }

    private var caseSummaryCard: some View {
        AppCard {
            SectionHeader("Estojo")
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                if let activeCase {
                    StatRow(label: "Ciclo atual iniciado em", value: DateFormatting.short.string(from: activeCase.startDate))
                    StatRow(label: "Substituição recomendada", value: DateFormatting.short.string(from: activeCase.nextRecommendedReplacementDate))
                    if let daysUntilCaseReplacement {
                        StatRow(label: "Situação", value: caseSituationText(daysUntilCaseReplacement))
                    }
                } else {
                    Text("Nenhum ciclo de estojo iniciado ainda.")
                        .font(AppTypography.subheadline)
                        .foregroundStyle(.secondary)
                }
                if let lastCleaning {
                    StatRow(label: "Última limpeza periódica", value: DateFormatting.short.string(from: lastCleaning.cleaningDate))
                }
                if let lastRoutineCare {
                    StatRow(label: "Último cuidado diário", value: DateFormatting.shortWithTime.string(from: lastRoutineCare.date))
                }
            }
            NavigationLink {
                CaseView()
            } label: {
                Text("Ver detalhes do estojo")
            }
            .font(AppTypography.subheadline)
            .padding(.top, AppSpacing.xxs)
        }
    }

    private var solutionSummaryCard: some View {
        AppCard {
            SectionHeader("Solução de limpeza")
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                if let activeSolution {
                    StatRow(label: "Aberto em", value: DateFormatting.short.string(from: activeSolution.openedDate))
                    StatRow(label: "Descarte recomendado", value: DateFormatting.short.string(from: activeSolution.discardDate))
                    if let daysUntilSolutionDiscard {
                        StatRow(label: "Situação", value: solutionSituationText(daysUntilSolutionDiscard))
                    }
                } else {
                    Text("Nenhum frasco de solução registrado ainda.")
                        .font(AppTypography.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            NavigationLink {
                CleaningSolutionView()
            } label: {
                Text("Ver detalhes da solução")
            }
            .font(AppTypography.subheadline)
            .padding(.top, AppSpacing.xxs)
        }
    }

    private var calendarCard: some View {
        AppCard {
            SectionHeader("Calendário de cuidados")
            MonthlyCareCalendarView(
                loggedDates: routineCareLogs.map(\.date),
                secondaryLoggedDates: cleanings.map(\.cleaningDate)
            )
        }
    }

    private var orientationsCard: some View {
        AppCard {
            SectionHeader("Orientações")
            orientationRow("Nunca complete solução antiga com solução nova — descarte e use sempre solução fresca.")
            orientationRow("Deixe o estojo secar ao ar livre depois de cada uso, sem tampar molhado.")
            orientationRow("Siga sempre a validade e as instruções do fabricante das lentes e da solução.")
            orientationRow("Procure um oftalmologista em caso de dor, vermelhidão ou alteração na visão.")
        }
    }

    private func orientationRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.xs) {
            Image(systemName: "info.circle")
                .foregroundStyle(AppColor.primary)
                .font(AppTypography.footnote)
            Text(text)
                .font(AppTypography.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    CuidadosView()
        .modelContainer(PreviewData.container)
}
