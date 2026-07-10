import SwiftUI

extension LensHealthStatus {
    var tintColor: Color {
        switch self {
        case .excellent: return .green
        case .good: return .yellow
        case .warning: return .orange
        case .critical: return .red
        }
    }
}

/// Indicador de saúde do par. Nunca depende só da cor: sempre mostra o emoji e o texto juntos.
struct HealthBadgeView: View {
    let status: LensHealthStatus

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
        .accessibilityLabel("Saúde das lentes: \(status.label)")
    }
}

#Preview {
    VStack(spacing: 8) {
        ForEach(LensHealthStatus.allCases, id: \.self) { status in
            HealthBadgeView(status: status)
        }
    }
    .padding()
}
