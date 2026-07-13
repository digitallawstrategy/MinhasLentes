import SwiftUI
import SwiftData

/// Aba Cuidados: dashboard do estojo e da solução de limpeza em profundidade — resumo de cada
/// um, calendário consolidado de cuidado diário/limpeza periódica e orientações gerais. Os
/// registros rápidos do dia a dia (uso das lentes, cuidado diário) ficam na aba Início; aqui é
/// onde se olha o panorama e se administra o que já foi registrado.
struct CuidadosView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Query(sort: \LensCase.startDate, order: .reverse) private var cases: [LensCase]
    @Query(sort: \CleaningSolution.openedDate, order: .reverse) private var solutions: [CleaningSolution]
    @Query(sort: \CaseCleaning.cleaningDate, order: .reverse) private var cleanings: [CaseCleaning]
    @Query(sort: \RoutineCareLog.date, order: .reverse) private var routineCareLogs: [RoutineCareLog]
    @Query private var allSettings: [AppSettings]
    #if DEBUG
    @State private var uiTestShowSolution = false
    @State private var uiTestShowCase = false
    #endif

    private var settings: AppSettings {
        allSettings.first ?? AppSettings()
    }

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

    private func situationText(daysRemaining days: Int, dueVerb: String) -> String {
        if days > 0 { return "\(Pluralization.word(days, "Falta", "Faltam")) \(Pluralization.count(days, "dia", "dias"))" }
        if days == 0 { return "\(dueVerb) hoje" }
        return "\(dueVerb) há \(Pluralization.count(-days, "dia", "dias"))"
    }

    private func situationTone(daysRemaining days: Int) -> AppStatusTone {
        if days <= 0 { return .critical }
        if days <= settings.advanceReminderDays { return .warning }
        return .success
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
                .padding(.bottom, AppSpacing.sm)
            }
            .tabBarScrollInset()
            .background(AmbientBackground())
            .navigationTitle("Cuidados")
            #if DEBUG
            .task {
                if UITestSupport.requestedRoute() == .solucao {
                    uiTestShowSolution = true
                } else if UITestSupport.requestedRoute() == .estojo {
                    uiTestShowCase = true
                }
            }
            .navigationDestination(isPresented: $uiTestShowSolution) {
                CleaningSolutionView()
            }
            .navigationDestination(isPresented: $uiTestShowCase) {
                CaseView()
            }
            #endif
        }
    }

    // Antes, cada fato (ciclo iniciado, substituição, situação, última limpeza, último cuidado)
    // era uma linha rótulo/valor com o mesmo peso — cinco StatRow seguidas sem hierarquia, uma
    // lendo igual à outra. Agora só a situação (o que importa para decidir alguma coisa agora)
    // tem destaque visual (badge colorido ao lado do título); o resto vira texto de apoio menor,
    // mesmo padrão já usado no card de "Frasco atual" de Solução.
    // O cartão inteiro é o alvo de toque (regra 3: card/linha com chevron, não um link de texto
    // solto no rodapé que não competia visualmente com nada) — `NavigationLink` não desenha
    // chevron sozinho fora de `List`/`Form`, então o ícone é manual, mesma receita de
    // `LensPairsView.pairHistoryLink`.
    private var caseSummaryCard: some View {
        NavigationLink {
            CaseView()
        } label: {
            AppCard {
                if let activeCase {
                    let titleBlock = VStack(alignment: .leading, spacing: 2) {
                        Text("Estojo")
                            .font(AppTypography.headline)
                        Text("Ciclo iniciado em \(DateFormatting.short.string(from: activeCase.startDate))")
                            .font(AppTypography.footnote)
                            .foregroundStyle(.secondary)
                    }
                    let badge = daysUntilCaseReplacement.map { days in
                        StatusBadge(text: situationText(daysRemaining: days, dueVerb: "Substituição recomendada"), tone: situationTone(daysRemaining: days), systemImage: "shippingbox.fill")
                    }
                    if dynamicTypeSize.isAccessibilitySize {
                        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                            titleBlock
                            badge
                            summaryChevron
                        }
                    } else {
                        HStack(alignment: .top) {
                            titleBlock
                            Spacer(minLength: AppSpacing.xs)
                            badge
                            summaryChevron
                        }
                    }
                    if let lastCleaning {
                        Text("Última limpeza periódica: \(DateFormatting.short.string(from: lastCleaning.cleaningDate))")
                            .font(AppTypography.footnote)
                            .foregroundStyle(.secondary)
                    }
                    if let lastRoutineCare {
                        Text("Último cuidado diário: \(DateFormatting.shortWithTime.string(from: lastRoutineCare.date))")
                            .font(AppTypography.footnote)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    SectionHeader("Estojo") { summaryChevron }
                    Text("Nenhum ciclo de estojo iniciado ainda.")
                        .font(AppTypography.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            // `NavigationLink` propõe ao próprio label uma altura de controle padrão (~1 linha),
            // não a altura natural do conteúdo — `lineLimit(nil)` sozinho permite múltiplas
            // linhas mas não muda essa proposta, então o texto continuava cortando com "…"
            // mesmo sem limite de linhas. `fixedSize(vertical: true)` força o label a pedir sua
            // altura ideal (a de todo o conteúdo empilhado), resolvendo o corte na raiz.
            .fixedSize(horizontal: false, vertical: true)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Abre os detalhes do estojo")
    }

    private var solutionSummaryCard: some View {
        NavigationLink {
            CleaningSolutionView()
        } label: {
            AppCard {
                if let activeSolution {
                    let titleBlock = VStack(alignment: .leading, spacing: 2) {
                        Text("Solução de limpeza")
                            .font(AppTypography.headline)
                        Text("Aberta em \(DateFormatting.short.string(from: activeSolution.openedDate))")
                            .font(AppTypography.footnote)
                            .foregroundStyle(.secondary)
                    }
                    let badge = daysUntilSolutionDiscard.map { days in
                        StatusBadge(text: situationText(daysRemaining: days, dueVerb: "Descarte recomendado"), tone: situationTone(daysRemaining: days), systemImage: "flask.fill")
                    }
                    if dynamicTypeSize.isAccessibilitySize {
                        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                            titleBlock
                            badge
                            summaryChevron
                        }
                    } else {
                        HStack(alignment: .top) {
                            titleBlock
                            Spacer(minLength: AppSpacing.xs)
                            badge
                            summaryChevron
                        }
                    }
                } else {
                    SectionHeader("Solução de limpeza") { summaryChevron }
                    Text("Nenhum frasco de solução registrado ainda.")
                        .font(AppTypography.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            // Ver comentário equivalente em `caseSummaryCard` — `NavigationLink` propõe altura de
            // controle padrão ao label, não a altura natural do conteúdo empilhado.
            .fixedSize(horizontal: false, vertical: true)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Abre os detalhes da solução de limpeza")
    }

    private var summaryChevron: some View {
        Image(systemName: "chevron.right")
            .font(.caption)
            .foregroundStyle(.tertiary)
            .accessibilityHidden(true)
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

    // Recolhida por padrão: 4 dicas sempre visíveis competiam com estojo/solução/calendário pelo
    // ponto focal do dashboard. O conteúdo continua todo aqui, só não abre a tela sozinho.
    private var orientationsCard: some View {
        AppCard {
            DisclosureGroup("Orientações") {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    orientationRow("Nunca complete solução antiga com solução nova — descarte e use sempre solução fresca.")
                    orientationRow("Deixe o estojo secar ao ar livre depois de cada uso, sem tampar molhado.")
                    orientationRow("Siga sempre a validade e as instruções do fabricante das lentes e da solução.")
                    orientationRow("Procure um oftalmologista em caso de dor, vermelhidão ou alteração na visão.")
                }
                .padding(.top, AppSpacing.xs)
            }
            .font(AppTypography.subheadlineMedium)
            .tint(AppColor.primary)
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
