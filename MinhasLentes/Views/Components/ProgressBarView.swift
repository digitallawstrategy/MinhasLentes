import SwiftUI

/// Indicador visual do percentual de vida útil já utilizado por um par de lentes.
struct ProgressBarView: View {
    let fraction: Double
    var tint: Color = .accentColor

    private var clampedFraction: Double {
        min(max(fraction, 0), 1)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.secondary.opacity(0.2))
                Capsule()
                    .fill(tint)
                    .frame(width: geometry.size.width * clampedFraction)
            }
        }
        .frame(height: 10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Progresso de uso das lentes")
        .accessibilityValue("\(Int((clampedFraction * 100).rounded())) por cento")
    }
}

#Preview {
    ProgressBarView(fraction: 0.42)
        .padding()
}
