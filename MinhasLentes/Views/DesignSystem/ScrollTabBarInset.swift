import SwiftUI

extension View {
    /// Reserva espaço real de safe area abaixo de um `ScrollView` de tela raiz, para o conteúdo
    /// nunca ficar atrás da tab bar — nem em repouso, nem no fim do scroll. Isto é
    /// `.safeAreaInset`, não `.padding` dentro do `VStack`: um espaçador dentro do conteúdo rolável
    /// só empurra a *posição* do conteúdo, mas não garante clareza real quando o card final cresce
    /// (Dynamic Type maior, estado com mais ações visíveis) — foi exatamente isso que continuou
    /// cortando o fim do cartão "Cuidados de hoje" mesmo depois de aumentar esse padding duas vezes.
    /// `safeAreaInset` resolve isso de vez porque participa do cálculo de safe area do próprio
    /// `ScrollView`, não do tamanho do conteúdo.
    func tabBarScrollInset() -> some View {
        safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 110)
        }
    }
}
