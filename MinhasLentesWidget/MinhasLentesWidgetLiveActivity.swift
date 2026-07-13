import ActivityKit
import WidgetKit
import SwiftUI

struct MinhasLentesWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LensActivityAttributes.self) { context in
            LockScreenLiveActivityView(attributes: context.attributes, state: context.state)
                .activityBackgroundTint(WidgetColor.liveActivityBackground)
                .activitySystemActionForegroundColor(Color.white)
        } dynamicIsland: { context in
            // Só as regiões leading/trailing, sem `.bottom`: mesmo expandida (seja pelo toque
            // do usuário, seja pelo aviso breve e automático de início/mudança que o próprio
            // iOS mostra), a apresentação fica pequena e discreta — ícone e valor, nada de
            // texto extra ocupando o topo da tela.
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: context.state.mode == .wearingSession ? "eye.circle.fill" : "checkmark.circle.fill")
                        .font(.body)
                        .foregroundStyle(.tint)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    TrailingValueView(state: context.state)
                        .font(.body.weight(.semibold))
                }
            } compactLeading: {
                Image(systemName: context.state.mode == .wearingSession ? "eye.circle.fill" : "checkmark.circle.fill")
            } compactTrailing: {
                // A pill compacta é o que fica visível o tempo todo, sem precisar segurar o
                // dedo — e é a apresentação mais próxima do que o Apple Watch espelha. Por isso
                // o tempo decorrido tem que aparecer aqui, não só na região expandida.
                TrailingValueView(state: context.state)
            } minimal: {
                Image(systemName: context.state.mode == .wearingSession ? "eye.circle.fill" : "checkmark.circle.fill")
            }
            .keylineTint(.accentColor)
        }
    }
}

private struct LockScreenLiveActivityView: View {
    let attributes: LensActivityAttributes
    let state: LensActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: state.mode == .wearingSession ? "eye.circle.fill" : "checkmark.circle.fill")
                .font(.largeTitle)
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 3) {
                Text(attributes.pairName)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))

                switch state.mode {
                case .usageConfirmation:
                    Text("Uso registrado")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("\(state.usesRemaining) de \(state.maximumUses) restantes")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                case .wearingSession:
                    // `.timer` em vez de `.relative`: é o estilo de `Text` mais testado pela
                    // Apple para conteúdo que se atualiza sozinho em Live Activity — o `.relative`
                    // não estava aparecendo no mirror do Apple Watch, mesmo com a view compacta.
                    if let wearingSince = state.wearingSince {
                        Text(wearingSince, style: .timer)
                            .font(.headline)
                            .foregroundStyle(.white)
                            .monospacedDigit()
                    }
                    Text("usando as lentes")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
            Spacer()
        }
        .padding()
    }
}

/// O valor de destaque nas regiões "trailing" da Dynamic Island (compacta e expandida): o
/// número de usos restantes normalmente, ou o cronômetro ao vivo durante uma sessão de uso —
/// a pill compacta é a apresentação padrão (sem precisar segurar o dedo) e a mais parecida com
/// o que o Apple Watch espelha, então o tempo decorrido precisa estar aqui, não só na tela
/// bloqueada.
private struct TrailingValueView: View {
    let state: LensActivityAttributes.ContentState

    var body: some View {
        if state.mode == .wearingSession, let wearingSince = state.wearingSince {
            // `.timer` conta pra cima sem um fim definido nessa sessão, o que pode fazer o
            // sistema reservar espaço de sobra pensando no pior caso de dígitos — por isso o
            // `frame` força um teto de largura em vez de deixar o layout decidir sozinho.
            Text(wearingSince, style: .timer)
                .font(.caption2)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .frame(maxWidth: 24)
        } else {
            Text("\(state.usesRemaining)")
                .contentTransition(.numericText())
        }
    }
}

extension LensActivityAttributes {
    fileprivate static var preview: LensActivityAttributes {
        LensActivityAttributes(pairID: UUID(), pairName: "Par nº 1")
    }
}

extension LensActivityAttributes.ContentState {
    fileprivate static var usageConfirmation: LensActivityAttributes.ContentState {
        LensActivityAttributes.ContentState(mode: .usageConfirmation, usesRemaining: 59, maximumUses: 60, wearingSince: nil, reminderAt: nil)
    }

    fileprivate static var wearingSession: LensActivityAttributes.ContentState {
        LensActivityAttributes.ContentState(
            mode: .wearingSession, usesRemaining: 59, maximumUses: 60,
            wearingSince: Date().addingTimeInterval(-3600), reminderAt: Date().addingTimeInterval(4 * 3600)
        )
    }
}

#Preview("Notification", as: .content, using: LensActivityAttributes.preview) {
   MinhasLentesWidgetLiveActivity()
} contentStates: {
    LensActivityAttributes.ContentState.usageConfirmation
    LensActivityAttributes.ContentState.wearingSession
}
