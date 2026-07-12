import SwiftUI

/// Casco comum das telas-dashboard do app (Início, Lentes, Cuidados e, a partir desta rodada,
/// Estoque/Solução): `ScrollView` + `AmbientBackground` + folga real acima da tab bar +
/// respiro padrão nas bordas. Existir como um componente único, em vez de cada tela repetir os
/// mesmos quatro modificadores, é o que garante que a mesma linguagem visual apareça em toda
/// tela-dashboard sem exigir disciplina manual — telas em `Form`/`List` puro (Configurações,
/// Consultas, Histórico) não usam isto, de propósito: são listas operacionais, não dashboards.
struct ScreenScaffold<Content: View>: View {
    var spacing: CGFloat = AppSpacing.md
    @ViewBuilder var content: () -> Content

    var body: some View {
        ScrollView {
            VStack(spacing: spacing, content: content)
                .padding(.horizontal)
                .padding(.top, AppSpacing.xs)
                .padding(.bottom, AppSpacing.sm)
        }
        .tabBarScrollInset()
        .background(AmbientBackground())
    }
}

#Preview {
    NavigationStack {
        ScreenScaffold {
            AppCard { Text("Cartão de exemplo") }
            AppCard { Text("Outro cartão") }
        }
        .navigationTitle("Exemplo")
    }
}
