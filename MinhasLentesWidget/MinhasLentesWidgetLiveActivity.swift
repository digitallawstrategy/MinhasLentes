import ActivityKit
import WidgetKit
import SwiftUI

struct MinhasLentesWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LensActivityAttributes.self) { context in
            LockScreenLiveActivityView(attributes: context.attributes, state: context.state)
                .activityBackgroundTint(Color.black.opacity(0.8))
                .activitySystemActionForegroundColor(Color.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: context.state.mode == .wearingSession ? "eye.circle.fill" : "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.tint)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(context.state.usesRemaining)")
                        .font(.title2.weight(.semibold))
                        .contentTransition(.numericText())
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ExpandedBottomView(attributes: context.attributes, state: context.state)
                }
            } compactLeading: {
                Image(systemName: context.state.mode == .wearingSession ? "eye.circle.fill" : "checkmark.circle.fill")
            } compactTrailing: {
                Text("\(context.state.usesRemaining)")
                    .contentTransition(.numericText())
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
                    Text("Usando as lentes")
                        .font(.headline)
                        .foregroundStyle(.white)
                    if let wearingSince = state.wearingSince {
                        Text(wearingSince, style: .relative)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    if let reminderAt = state.reminderAt {
                        Text("Lembrete às \(reminderAt.formatted(date: .omitted, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
            }
            Spacer()
        }
        .padding()
    }
}

private struct ExpandedBottomView: View {
    let attributes: LensActivityAttributes
    let state: LensActivityAttributes.ContentState

    var body: some View {
        switch state.mode {
        case .usageConfirmation:
            Text("Uso registrado em \(attributes.pairName)")
                .font(.footnote)
        case .wearingSession:
            HStack {
                if let wearingSince = state.wearingSince {
                    HStack(spacing: 4) {
                        Text("Usando há")
                            .font(.footnote)
                        Text(wearingSince, style: .relative)
                            .font(.footnote.weight(.medium))
                    }
                }
                Spacer()
                if let reminderAt = state.reminderAt {
                    Text("Lembrete às \(reminderAt.formatted(date: .omitted, time: .shortened))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

extension LensActivityAttributes {
    fileprivate static var preview: LensActivityAttributes {
        LensActivityAttributes(pairName: "Par nº 1")
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
