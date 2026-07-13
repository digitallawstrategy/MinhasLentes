import SwiftUI

/// Anel de progresso no estilo do app Fitness da Apple. Representa a fração de usos
/// restantes: começa cheio e vai diminuindo conforme o par é utilizado.
struct ProgressRingView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let remainingFraction: Double
    var tint: Color = .accentColor
    var lineWidth: CGFloat = 14

    private var clampedFraction: Double {
        min(max(remainingFraction, 0), 1)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.15), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: clampedFraction)
                .stroke(
                    tint,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.6), value: clampedFraction)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Usos restantes")
        .accessibilityValue("\(Int((clampedFraction * 100).rounded())) por cento")
    }
}

#Preview {
    ProgressRingView(remainingFraction: 0.72)
        .frame(width: 160, height: 160)
        .padding()
}
