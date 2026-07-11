import SwiftUI

/// Marca do app em traço — os dois anéis sobrepostos do ícone, como glifo simples (não a imagem
/// do ícone em si, que tem fundo em gradiente). Usado só onde faz sentido reforçar identidade
/// (cabeçalho do Início), nunca repetido como decoração pela tela.
struct AppLogoMark: View {
    var size: CGFloat = 22
    var lineWidth: CGFloat = 2.5

    var body: some View {
        ZStack {
            Circle()
                .stroke(AppColor.primary, lineWidth: lineWidth)
                .frame(width: size, height: size)
            Circle()
                .stroke(AppColor.secondary, lineWidth: lineWidth)
                .frame(width: size, height: size)
                .offset(x: size * 0.32)
        }
        .frame(width: size * 1.32, height: size, alignment: .leading)
        .accessibilityHidden(true)
    }
}

#Preview {
    AppLogoMark(size: 32)
        .padding()
}
