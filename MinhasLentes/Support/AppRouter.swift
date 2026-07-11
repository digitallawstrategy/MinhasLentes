import Foundation
import Observation

enum AppTab: Hashable {
    case home, lentes, cuidados, consultas, settings
}

/// Roteamento de app inteiro: para onde a TabView deve ir e qual par deve ser aberto, vindo de
/// um deep link do widget (`minhaslentes://pair/<uuid>`) ou do toque numa notificação. É um
/// singleton de propósito — tanto o delegate de notificações (`NotificationManager`, fora da
/// árvore de Views) quanto `onOpenURL` (dentro dela) precisam escrever no mesmo lugar.
@MainActor
@Observable
final class AppRouter {
    static let shared = AppRouter()

    var selectedTab: AppTab = .home
    var pendingPairID: UUID?
    /// Setado pelo botão "Retirei agora" de uma notificação de tempo de uso excessivo — a aba
    /// Início observa isso e sincroniza o estado local da sessão assim que a view aparece (a
    /// sessão em si já foi encerrada no banco antes disso, ver `NotificationManager`).
    var pendingEndWearingSession = false

    private init() {}

    func openPair(_ id: UUID) {
        selectedTab = .lentes
        pendingPairID = id
    }

    /// Estojo e Solução moraram em abas próprias antes, mas viraram destinos dentro de
    /// Cuidados — um toque de notificação sobre qualquer um dos dois leva até a aba e para na
    /// tela de escolha; não há como pular direto para a subtela sem uma pilha de navegação
    /// própria por aba, o que não vale a complexidade extra para este caso.
    func openEstojo() {
        selectedTab = .cuidados
    }

    func openSolution() {
        selectedTab = .cuidados
    }

    func openHome() {
        selectedTab = .home
    }

    func openLentes() {
        selectedTab = .lentes
    }

    func openSettings() {
        selectedTab = .settings
    }

    func openConsultas() {
        selectedTab = .consultas
    }

    /// Trata `minhaslentes://pair/<uuid>` (widget médio, com par identificado) e
    /// `minhaslentes://estojo` (widget sem par específico, ex.: estado vazio).
    func handle(url: URL) {
        guard url.scheme == "minhaslentes" else { return }
        switch url.host {
        case "pair":
            if let uuidString = url.pathComponents.last(where: { $0 != "/" }), let id = UUID(uuidString: uuidString) {
                openPair(id)
            } else {
                openHome()
            }
        case "estojo":
            openEstojo()
        default:
            openHome()
        }
    }
}
