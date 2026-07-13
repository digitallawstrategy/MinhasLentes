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

    private func row(for item: PendingItem) -> some View {
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
            if let actionLabel = item.actionLabel {
                SecondaryActionButton(title: actionLabel, tint: item.tone.color, fullWidth: false, compact: true) {
                    perform(item)
                }
            }
        }
        .padding(.vertical, AppSpacing.xxs)
        .listRowBackground(Color.clear)
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
