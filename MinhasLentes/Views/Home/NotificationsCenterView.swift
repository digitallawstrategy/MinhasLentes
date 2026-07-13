import SwiftUI
import SwiftData

/// Central de avisos aberta pelo sino da Home — pendências reais do app (cuidado diário,
/// sessão de uso excessiva, estojo, solução, estoque, consulta), nunca um atalho para
/// Configurações. Estado vazio calmo quando não há nada pendente. `routineCareViewModel` e
/// `pairsViewModel` são as MESMAS instâncias que `HomeView` já possui — passadas direto, para o
/// estado (toasts de desfazer, sessão de uso) ficar em sincronia com os cards da própria Home,
/// em vez de duplicado aqui.
struct NotificationsCenterView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let items: [PendingItem]
    let routineCareViewModel: RoutineCareViewModel
    let pairsViewModel: LensPairsViewModel

    @State private var router = AppRouter.shared

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    EmptyStateView(
                        title: "Tudo em dia",
                        systemImage: "checkmark.circle",
                        description: "Nenhuma pendência no momento."
                    )
                } else {
                    List {
                        ForEach(items) { item in
                            row(for: item)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(AmbientBackground())
            .navigationTitle("Avisos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") { dismiss() }
                }
            }
        }
    }

    /// `.navigate` é navegação pura (só troca de aba) — vira linha inteira tocável com chevron,
    /// não um botão de destaque, que fica reservado para `.registerDailyCare`/`.endWearSession`
    /// (mudam estado de verdade). Antes os três tipos usavam o mesmo `SecondaryActionButton`,
    /// sem diferenciar visualmente "isto muda algo agora" de "isto só me leva a outro lugar".
    @ViewBuilder
    private func row(for item: PendingItem) -> some View {
        if case .navigate = item.action {
            Button {
                perform(item)
            } label: {
                rowContent(for: item, trailing: AnyView(
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                ))
                // `Button` propõe ao próprio label uma altura de controle padrão — sem isto,
                // `item.detail` cortaria com "…" em Dynamic Type grande (mesmo problema e
                // correção de `LensPairCardView`/`CuidadosView.caseSummaryCard`).
                .fixedSize(horizontal: false, vertical: true)
            }
            .buttonStyle(.plain)
            .listRowBackground(Color.clear)
        } else {
            rowContent(for: item, trailing: item.actionLabel.map { actionLabel in
                AnyView(
                    SecondaryActionButton(title: actionLabel, tint: item.tone.color, fullWidth: false, compact: true) {
                        perform(item)
                    }
                )
            } ?? AnyView(EmptyView()))
            .listRowBackground(Color.clear)
        }
    }

    private func rowContent(for item: PendingItem, trailing: AnyView) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: item.icon)
                .foregroundStyle(item.tone.color)
                .frame(width: 20)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(AppTypography.subheadlineMedium)
                Text(item.detail)
                    .font(AppTypography.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: AppSpacing.xs)
            trailing
        }
        .padding(.vertical, AppSpacing.xxs)
    }

    private func perform(_ item: PendingItem) {
        guard let action = item.action else { return }
        switch action {
        case .registerDailyCare:
            routineCareViewModel.registerRoutineCareToday(context: modelContext)
        case .endWearSession:
            Task { await pairsViewModel.endWearingSession(context: modelContext) }
        case .navigate(let tab):
            router.selectedTab = tab
            dismiss()
        }
    }
}

#Preview {
    NotificationsCenterView(
        items: [
            PendingItem(
                id: .dailyCare, icon: "checklist", title: "Cuidado diário",
                detail: "Ainda não registrado hoje.", tone: .warning,
                action: .registerDailyCare, actionLabel: "Registrar cuidado"
            ),
            PendingItem(
                id: .wearSession, icon: "eye.trianglebadge.exclamationmark", title: "Sessão de uso",
                detail: "Lentes em uso há mais de 8 horas.", tone: .warning,
                action: .endWearSession, actionLabel: "Retirei as lentes"
            ),
        ],
        routineCareViewModel: RoutineCareViewModel(),
        pairsViewModel: LensPairsViewModel()
    )
    .modelContainer(PreviewData.container)
}
