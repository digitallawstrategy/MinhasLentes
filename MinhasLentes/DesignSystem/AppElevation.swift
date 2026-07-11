import SwiftUI

/// Materiais usados para "elevar" cartões e superfícies flutuantes acima do fundo — `Material`
/// se adapta sozinho a claro/escuro/contraste, sem precisar de nenhum valor manual por modo.
enum AppElevation {
    static let surface: Material = .regularMaterial
    static let surfaceElevated: Material = .thickMaterial
}

/// Sombra sutil para elementos flutuantes (toasts, botões destacados) — deliberadamente leve,
/// nunca a sombra pesada de "cartão de PDF" que faz um app parecer um template genérico.
enum AppShadow {
    static let floatingColor = Color.black.opacity(0.12)
    static let floatingRadius: CGFloat = 8
    static let floatingY: CGFloat = 3
}
