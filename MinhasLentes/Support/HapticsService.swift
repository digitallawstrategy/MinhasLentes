import UIKit

/// Feedback háptico discreto usado ao registrar usos e limpezas — o catálogo de háptica do
/// design system; nenhuma View deve chamar `UIFeedbackGenerator` diretamente.
@MainActor
enum HapticsService {
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    static func lightImpact() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}
