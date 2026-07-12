import SwiftUI

/// Selo de status compacto — texto e tom livres, usado tanto para o status de utilização de um
/// par quanto para qualquer outro selo do app. Nunca depende só da cor: sempre mostra o texto
/// junto.
struct StatusBadge: View {
    let text: String
    var tone: AppStatusTone = .neutral
    var systemImage: String?
    var emoji: String?
    /// Quando o selo divide uma linha com um botão de peso equivalente (ex.: "Uso registrado
    /// hoje" ao lado de "Retirei as lentes") — sem isto, o selo fica compacto de propósito, do
    /// tamanho do próprio texto, como em todo o resto do app.
    var fullWidth: Bool = false
    /// `1` (padrão) mantém o selo como uma pílula compacta de uma linha só, com
    /// `minimumScaleFactor` como rede de segurança para textos um pouco largos. Quem já sabe que
    /// está num tamanho de fonte extremo (accessibility sizes) e tem o selo sozinho na própria
    /// linha pode passar `nil` aqui: em vez de truncar (ou, com `.fixedSize()`, ficar maior que a
    /// própria tela e cortar visualmente), o texto quebra em 2+ linhas dentro da pílula — a
    /// pílula cresce em altura, mas nunca esconde ou corta o texto.
    var lineLimit: Int? = 1

    var body: some View {
        Group {
            if let emoji {
                Label {
                    Text(text)
                } icon: {
                    Text(emoji)
                }
            } else if let systemImage {
                Label(text, systemImage: systemImage)
            } else {
                Text(text)
            }
        }
        .font(AppTypography.badge)
        .lineLimit(lineLimit)
        .minimumScaleFactor(lineLimit == 1 ? 0.7 : 1)
        .multilineTextAlignment(.leading)
        .frame(maxWidth: fullWidth ? .infinity : nil)
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, fullWidth ? AppSpacing.xs : AppSpacing.xxs)
        .background {
            // Sucesso usa o gradiente dedicado (dois tons de verde, não uma opacidade só) —
            // é o selo de "já registrado hoje" que mais aparece na Home, então é o único que
            // vale a pena destacar com esse tratamento; os demais tons continuam com uma
            // opacidade chapada simples.
            if case .success = tone {
                Capsule().fill(AppGradient.successPillBackground)
            } else {
                Capsule().fill(tone.color.opacity(0.15))
            }
        }
        .foregroundStyle(tone.color)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    VStack(spacing: AppSpacing.sm) {
        StatusBadge(text: "Vida útil alta", tone: .success, emoji: "🟢")
        StatusBadge(text: "Em uso agora", tone: .informative, systemImage: "eye.circle.fill")
        StatusBadge(text: "Estoque baixo", tone: .warning)
    }
    .padding()
}
