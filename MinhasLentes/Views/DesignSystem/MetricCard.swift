import SwiftUI

/// Cartão de métrica em destaque — número/anel grande + rótulo, com um detalhe secundário
/// opcional ao lado. Usado onde um valor precisa ser o ponto focal da tela (ex.: usos
/// restantes de um par).
struct MetricCard: View {
    let value: String
    let label: String
    var caption: String?
    /// Fração 0...1 para desenhar como anel de progresso; `nil` mostra só o texto.
    var progress: Double?
    var tone: AppStatusTone = .informative

    var body: some View {
        AppCard {
            HStack(spacing: AppSpacing.lg) {
                if let progress {
                    ZStack {
                        ProgressRingView(remainingFraction: progress, tint: tone.color)
                        VStack(spacing: 0) {
                            Text(value)
                                .font(AppTypography.metricValue)
                                .minimumScaleFactor(0.5)
                                .lineLimit(1)
                            Text(label)
                                .font(AppTypography.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 108, height: 108)
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(value)
                            .font(AppTypography.largeTitle)
                        Text(label)
                            .font(AppTypography.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                if let caption {
                    Spacer()
                    Text(caption)
                        .font(AppTypography.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: AppSpacing.md) {
        MetricCard(value: "51", label: "restantes", caption: "85% do limite", progress: 0.85, tone: .success)
        MetricCard(value: "12", label: "usos este mês")
    }
    .padding()
}
