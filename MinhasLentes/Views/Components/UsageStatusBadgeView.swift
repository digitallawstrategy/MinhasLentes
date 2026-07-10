import SwiftUI

extension LensUsageStatus {
    var tintColor: Color {
        switch self {
        case .excellent: return .green
        case .good: return .yellow
        case .warning: return .orange
        case .critical: return .red
        }
    }
}

/// Indicador do status de utilização do par (leitura da contagem de usos restantes — não uma
/// avaliação clínica ou de integridade física da lente). Nunca depende só da cor: sempre
/// mostra o emoji e o texto juntos.
struct UsageStatusBadgeView: View {
    let status: LensUsageStatus

    var body: some View {
        Label {
            Text(status.label)
                .font(.subheadline.weight(.semibold))
        } icon: {
            Text(status.emoji)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(status.tintColor.opacity(0.15), in: Capsule())
        .foregroundStyle(status.tintColor)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Status de utilização: \(status.label)")
    }
}

#Preview {
    VStack(spacing: 8) {
        ForEach(LensUsageStatus.allCases, id: \.self) { status in
            UsageStatusBadgeView(status: status)
        }
    }
    .padding()
}
