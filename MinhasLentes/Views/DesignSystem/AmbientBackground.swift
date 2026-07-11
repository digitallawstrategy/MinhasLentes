import SwiftUI

/// Fundo de tela: o gradiente ambiente sutil + duas manchas desfocadas, estáticas, de marca —
/// a "atmosfera" da referência visual (`modelodesign.png`), sem nenhuma animação nem partícula em
/// movimento. Só forma e opacidade, renderizadas uma vez; não há custo contínuo de bateria/CPU
/// nisso, então a preocupação que levou a descartar partículas animadas não se aplica aqui.
struct AmbientBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    private var spotOpacity: Double {
        colorScheme == .dark ? 0.12 : 0.05
    }

    var body: some View {
        ZStack {
            AppGradient.ambientBackground(colorScheme: colorScheme)
            GeometryReader { proxy in
                Circle()
                    .fill(AppColor.primary.opacity(spotOpacity))
                    .frame(width: proxy.size.width * 0.7)
                    .blur(radius: 70)
                    .offset(x: proxy.size.width * 0.55, y: -proxy.size.height * 0.08)
                Circle()
                    .fill(AppColor.secondary.opacity(spotOpacity * 0.8))
                    .frame(width: proxy.size.width * 0.6)
                    .blur(radius: 80)
                    .offset(x: -proxy.size.width * 0.35, y: proxy.size.height * 0.55)
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

#Preview {
    AmbientBackground()
}
