import CoreGraphics

/// Escala de espaçamento do design system — toda margem, gap ou padding nas Views deve vir
/// daqui, nunca de um número solto, para manter o ritmo visual consistente entre todas as telas.
enum AppSpacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}
