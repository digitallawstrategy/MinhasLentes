import SwiftUI

/// Cartão compacto de status — ícone semântico, título, detalhe opcional e um selo opcional à
/// direita. Não é tocável (é leitura de estado, não ação); usado para resumos como "tudo em
/// dia" na Home.
struct StatusCard: View {
    let title: String
    var detail: String?
    var badgeText: String?
    var tone: AppStatusTone = .success

    private var iconName: String {
        switch tone {
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .critical: return "exclamationmark.octagon.fill"
        case .informative: return "info.circle.fill"
        case .neutral: return "circle"
        }
    }

    var body: some View {
        AppCard {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: iconName)
                    .foregroundStyle(tone.color)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AppTypography.subheadlineMedium)
                    if let detail {
                        Text(detail)
                            .font(AppTypography.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if let badgeText {
                    StatusBadge(text: badgeText, tone: tone)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    VStack(spacing: AppSpacing.md) {
        StatusCard(title: "Você está com tudo em dia", tone: .success)
        StatusCard(title: "Estojo", detail: "Substituição em 3 dia(s)", badgeText: "Atenção", tone: .warning)
    }
    .padding()
}
