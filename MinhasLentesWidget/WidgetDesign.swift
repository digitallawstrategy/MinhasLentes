import SwiftUI

/// Tokens visuais mínimos do widget, deliberadamente locais — não importa `AppCard`/`AppColor`
/// do alvo do app (módulos separados; ver comentário em `LensSnapshotLoader.swift` sobre por
/// que este target evita depender de arquivos do app). Os valores aqui são os MESMOS hex da
/// paleta "indigo e violeta" do app (`AppColor.swift`/`AppGradient.swift`), só que redeclarados
/// como assets próprios do target do widget (`Assets.xcassets`), para o widget parecer da mesma
/// família visual sem acoplar os dois targets.
enum WidgetColor {
    /// Indigo de marca — já é o `AccentColor` deste target, com os mesmos valores do app.
    static let primary = Color.accentColor
    /// Violeta de marca — uso pontual, nunca como cor de status (mesma regra do app).
    static let secondary = Color("WidgetSecondary")
    static let success = Color("WidgetSuccess")
    static let warning = Color(uiColor: .systemOrange)
    static let critical = Color(uiColor: .systemRed)
    /// Fundo do próprio widget (`containerBackground`) — quase-branco lavanda no claro,
    /// quase-preto azulado no escuro.
    static let background = Color("WidgetBackground")
    /// Superfície interna sutilmente elevada (trilho do anel, fundo do selo de status).
    static let surfaceElevated = Color("WidgetSurfaceElevated")
    /// Fundo da Live Activity na tela bloqueada — sempre escuro, independente do modo claro/
    /// escuro do sistema (convenção do próprio `ActivityKit`: a tela bloqueada já é escura por
    /// natureza). Mesmo hex do `AppBackground` escuro (`#0D0D12`, quase-preto azulado), não um
    /// preto puro genérico — para a Live Activity continuar na mesma família visual do resto do
    /// app mesmo nesse contexto de opacidade fixa.
    static let liveActivityBackground = Color(red: 0x0D / 255, green: 0x0D / 255, blue: 0x12 / 255).opacity(0.92)
}

enum WidgetGradient {
    /// Fundo do widget inteiro: um gradiente diagonal muito sutil de indigo para violeta sobre
    /// o fundo de marca — mesmo espírito de `AppGradient.ambientBackground`, mais discreto ainda
    /// porque aqui é a superfície inteira do widget (sem cartão por cima), não um plano de fundo
    /// de tela com cartões flutuando à frente.
    static func background(colorScheme: ColorScheme) -> LinearGradient {
        let opacity = colorScheme == .dark ? 0.14 : 0.05
        return LinearGradient(
            colors: [
                WidgetColor.primary.opacity(opacity),
                WidgetColor.background,
                WidgetColor.secondary.opacity(opacity * 0.6),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

enum WidgetSpacing {
    static let xxs: CGFloat = 3
    static let xs: CGFloat = 6
    static let sm: CGFloat = 10
    static let md: CGFloat = 14
}

/// Espelha `LensStatisticsService.usageStatus` + `LensUsageStatus.tone` (excellent/good → success,
/// warning → warning, critical → critical) — mesmos limiares configurados em `AppSettings`, sem
/// nenhuma regra nova. Só reduz para 3 tons (o widget não tem espaço para diferenciar "alta" de
/// "moderada" como o selo do app faz).
enum WidgetTone {
    static func forUsage(remaining: Int, maximum: Int, goodBelowPercent: Int, warningBelowPercent: Int, criticalBelowPercent: Int) -> Color {
        guard maximum > 0, remaining > 0 else { return WidgetColor.critical }
        let remainingPercent = Int((Double(remaining) / Double(maximum) * 100).rounded())
        if remainingPercent < criticalBelowPercent { return WidgetColor.critical }
        if remainingPercent < warningBelowPercent { return WidgetColor.warning }
        return WidgetColor.success
    }
}

/// Anel de usos restantes, no mesmo espírito de `UsageCountRing` (Views/Components, alvo do
/// app) — reimplementado localmente porque widgets não compartilham Views com o app (só
/// modelos/serviços puros, ver exceção de membership no `project.pbxproj`). Sem animação: o
/// processo do widget não fica vivo entre atualizações de timeline, então uma transição animada
/// nunca chega a ser vista de verdade.
struct WidgetUsageRing: View {
    let value: Int
    let remainingFraction: Double
    var tint: Color = WidgetColor.primary
    var diameter: CGFloat = 60
    var lineWidth: CGFloat = 7

    private var clampedFraction: Double {
        min(max(remainingFraction, 0), 1)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.15), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: clampedFraction)
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(value)")
                .font(.system(size: (diameter * 0.34).rounded(), weight: .bold, design: .rounded))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .foregroundStyle(.primary)
                .padding(.horizontal, lineWidth)
        }
        .frame(width: diameter, height: diameter)
    }
}

/// Selo compacto de um sinal secundário (medium widget) — ícone + texto curto, mesmo peso visual
/// para os três sinais possíveis, para nenhum brigar por atenção com os outros.
struct WidgetSignalRow: View {
    let systemImage: String
    let text: String
    var tone: Color = .secondary

    var body: some View {
        Label {
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.9)
        } icon: {
            Image(systemName: systemImage)
                .font(.caption)
                .foregroundStyle(tone)
        }
        .labelStyle(.titleAndIcon)
    }
}
