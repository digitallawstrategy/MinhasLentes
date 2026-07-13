import XCTest
@testable import MinhasLentes

/// `AppRouter.shared` é um singleton — resetamos o estado em `setUp`/`tearDown` para um teste
/// nunca vazar estado para o próximo.
@MainActor
final class AppRouterTests: XCTestCase {
    override func setUp() {
        super.setUp()
        AppRouter.shared.selectedTab = .home
        AppRouter.shared.pendingPairID = nil
        AppRouter.shared.pendingEndWearingSession = false
    }

    override func tearDown() {
        AppRouter.shared.selectedTab = .home
        AppRouter.shared.pendingPairID = nil
        AppRouter.shared.pendingEndWearingSession = false
        super.tearDown()
    }

    func testHandleURLWithValidPairUUIDSelectsLentesAndStashesPendingID() {
        let id = UUID()
        AppRouter.shared.handle(url: URL(string: "minhaslentes://pair/\(id.uuidString)")!)
        XCTAssertEqual(AppRouter.shared.selectedTab, .lentes)
        XCTAssertEqual(AppRouter.shared.pendingPairID, id)
    }

    func testHandleURLWithMalformedPairUUIDFallsBackToHome() {
        AppRouter.shared.handle(url: URL(string: "minhaslentes://pair/not-a-uuid")!)
        XCTAssertEqual(AppRouter.shared.selectedTab, .home)
        XCTAssertNil(AppRouter.shared.pendingPairID)
    }

    func testHandleURLWithEstojoHostSelectsCuidados() {
        AppRouter.shared.handle(url: URL(string: "minhaslentes://estojo")!)
        XCTAssertEqual(AppRouter.shared.selectedTab, .cuidados)
    }

    func testHandleURLWithUnknownHostFallsBackToHome() {
        AppRouter.shared.selectedTab = .consultas
        AppRouter.shared.handle(url: URL(string: "minhaslentes://desconhecido")!)
        XCTAssertEqual(AppRouter.shared.selectedTab, .home)
    }

    func testHandleURLWithUnknownSchemeIsNoOp() {
        AppRouter.shared.selectedTab = .consultas
        AppRouter.shared.handle(url: URL(string: "https://example.com/pair/123")!)
        XCTAssertEqual(AppRouter.shared.selectedTab, .consultas, "Esquema diferente de minhaslentes:// não deve mudar o estado")
    }

    func testOpenPairSetsSelectedTabAndPendingID() {
        let id = UUID()
        AppRouter.shared.openPair(id)
        XCTAssertEqual(AppRouter.shared.selectedTab, .lentes)
        XCTAssertEqual(AppRouter.shared.pendingPairID, id)
    }
}
