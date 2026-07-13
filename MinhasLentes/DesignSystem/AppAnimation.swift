import SwiftUI

/// Durações e curvas de animação/transição do design system — o suficiente para dar
/// naturalidade a mudanças de estado, nunca chamativo a ponto de atrasar a próxima ação.
enum AppAnimation {
    static let quick: Animation = .snappy(duration: 0.2)
    static let standard: Animation = .snappy(duration: 0.35)
    static let emphasized: Animation = .spring(duration: 0.5)
}
