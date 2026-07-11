import SwiftUI

/// Barra de progresso em segmentos (em vez de uma barra contínua) — reforço visual rápido do
/// mesmo valor que o anel/número já mostram. Puramente decorativo: o VoiceOver já recebe essa
/// informação pelo anel (`accessibilityValue`) e pelo texto ao lado, então isto fica oculto para
/// não duplicar o anúncio.
struct SegmentedProgressBar: View {
    var segments: Int = 14
    let filledFraction: Double
    var tone: AppStatusTone = .success

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<segments, id: \.self) { index in
                Capsule()
                    .fill(isFilled(index) ? tone.color : Color.secondary.opacity(0.18))
                    .frame(width: 4, height: 16)
            }
        }
        .accessibilityHidden(true)
    }

    private func isFilled(_ index: Int) -> Bool {
        Double(index) < (filledFraction * Double(segments)).rounded()
    }
}

#Preview {
    VStack(alignment: .leading, spacing: AppSpacing.md) {
        SegmentedProgressBar(filledFraction: 0.85, tone: .success)
        SegmentedProgressBar(filledFraction: 0.4, tone: .warning)
        SegmentedProgressBar(filledFraction: 0.1, tone: .critical)
    }
    .padding()
}
