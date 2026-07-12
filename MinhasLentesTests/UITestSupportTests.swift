import XCTest
import SwiftData
@testable import MinhasLentes

@MainActor
final class UITestSupportTests: XCTestCase {
    var context: ModelContext!

    override func setUp() {
        super.setUp()
        context = TestSupport.makeContext()
    }

    override func tearDown() {
        context = nil
        super.tearDown()
    }

    // MARK: - Parsing dos argumentos

    func testIsSkipOnboardingRequestedParsesArgument() {
        XCTAssertTrue(UITestSupport.isSkipOnboardingRequested(arguments: ["-UITestSkipOnboarding"]))
        XCTAssertFalse(UITestSupport.isSkipOnboardingRequested(arguments: ["-UITestSeedPreviewData"]))
        XCTAssertFalse(UITestSupport.isSkipOnboardingRequested(arguments: []))
    }

    func testIsSeedPreviewDataRequestedParsesArgument() {
        XCTAssertTrue(UITestSupport.isSeedPreviewDataRequested(arguments: ["-UITestSeedPreviewData"]))
        XCTAssertFalse(UITestSupport.isSeedPreviewDataRequested(arguments: ["-UITestSkipOnboarding"]))
    }

    func testIsUITestRunTrueWhenEitherArgumentIsPresent() {
        XCTAssertTrue(UITestSupport.isUITestRun(arguments: ["-UITestSkipOnboarding"]))
        XCTAssertTrue(UITestSupport.isUITestRun(arguments: ["-UITestSeedPreviewData"]))
        XCTAssertTrue(UITestSupport.isUITestRun(arguments: ["-UITestSkipOnboarding", "-UITestSeedPreviewData"]))
        XCTAssertFalse(UITestSupport.isUITestRun(arguments: ["-SomeOtherFlag"]))
        XCTAssertFalse(UITestSupport.isUITestRun(arguments: []))
    }

    func testRequestedTabParsesValidValues() {
        XCTAssertEqual(UITestSupport.requestedTab(arguments: ["-UITestSelectedTab", "home"]), .home)
        XCTAssertEqual(UITestSupport.requestedTab(arguments: ["-UITestSelectedTab", "lentes"]), .lentes)
        XCTAssertEqual(UITestSupport.requestedTab(arguments: ["-UITestSelectedTab", "cuidados"]), .cuidados)
        XCTAssertEqual(UITestSupport.requestedTab(arguments: ["-UITestSelectedTab", "consultas"]), .consultas)
        XCTAssertEqual(UITestSupport.requestedTab(arguments: ["-UITestSelectedTab", "settings"]), .settings)
    }

    func testRequestedTabReturnsNilWhenAbsentOrInvalid() {
        XCTAssertNil(UITestSupport.requestedTab(arguments: []))
        XCTAssertNil(UITestSupport.requestedTab(arguments: ["-UITestSelectedTab"]))
        XCTAssertNil(UITestSupport.requestedTab(arguments: ["-UITestSelectedTab", "unknown"]))
    }

    func testRequestedRouteParsesValidValues() {
        XCTAssertEqual(UITestSupport.requestedRoute(arguments: ["-UITestOpenRoute", "estoque"]), .estoque)
        XCTAssertEqual(UITestSupport.requestedRoute(arguments: ["-UITestOpenRoute", "solucao"]), .solucao)
        XCTAssertEqual(UITestSupport.requestedRoute(arguments: ["-UITestOpenRoute", "historico"]), .historico)
    }

    func testRequestedRouteReturnsNilWhenAbsentOrInvalid() {
        XCTAssertNil(UITestSupport.requestedRoute(arguments: []))
        XCTAssertNil(UITestSupport.requestedRoute(arguments: ["-UITestOpenRoute"]))
        XCTAssertNil(UITestSupport.requestedRoute(arguments: ["-UITestOpenRoute", "unknown"]))
    }

    func testRequestedRouteIsIndependentFromSelectedTab() {
        let arguments = ["-UITestSelectedTab", "lentes", "-UITestOpenRoute", "estoque"]
        XCTAssertEqual(UITestSupport.requestedTab(arguments: arguments), .lentes)
        XCTAssertEqual(UITestSupport.requestedRoute(arguments: arguments), .estoque)
    }

    // MARK: - applySkipOnboarding

    func testApplySkipOnboardingMarksSettingsComplete() throws {
        try UITestSupport.applySkipOnboarding(context: context)
        let settings = try AppSettingsStore.currentSettings(context: context)
        XCTAssertTrue(settings.hasCompletedOnboarding)
    }

    func testApplySkipOnboardingDoesNotCreateAnyPairOrOtherData() throws {
        try UITestSupport.applySkipOnboarding(context: context)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<LensPair>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<LensUsage>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<RoutineCareLog>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<LensCase>()), 0)
    }

    // MARK: - seedPreviewData: conteúdo

    func testSeedPreviewDataCreatesPairWithExpectedUsageCounters() throws {
        let referenceDate = TestSupport.date(2026, 7, 12)
        let pair = try UITestSupport.seedPreviewData(context: context, referenceDate: referenceDate)

        XCTAssertEqual(pair.name, "Par nº 1")
        XCTAssertEqual(pair.sequenceNumber, 1)
        XCTAssertEqual(pair.maximumUses, 60)
        XCTAssertEqual(pair.usesCount, 2, "Dois usos semeados (ontem e hoje)")
        XCTAssertEqual(pair.usesRemaining, 58)
        XCTAssertEqual(pair.status, .inUse)
    }

    func testSeedPreviewDataMarksOnboardingComplete() throws {
        try UITestSupport.seedPreviewData(context: context, referenceDate: TestSupport.date(2026, 7, 12))
        let settings = try AppSettingsStore.currentSettings(context: context)
        XCTAssertTrue(settings.hasCompletedOnboarding, "Dado semeado sem onboarding concluído mostraria a tela de boas-vindas por cima")
    }

    func testSeedPreviewDataRegistersRoutineCareForReferenceDate() throws {
        let referenceDate = TestSupport.date(2026, 7, 12)
        try UITestSupport.seedPreviewData(context: context, referenceDate: referenceDate)

        let logs = try context.fetch(FetchDescriptor<RoutineCareLog>())
        XCTAssertEqual(logs.count, 1)
        XCTAssertTrue(Calendar.current.isDate(logs[0].date, inSameDayAs: referenceDate))
    }

    func testSeedPreviewDataCreatesActiveCaseWithReplacementInExactly89Days() throws {
        let referenceDate = TestSupport.date(2026, 7, 12)
        try UITestSupport.seedPreviewData(context: context, referenceDate: referenceDate)

        let cases = try context.fetch(FetchDescriptor<LensCase>())
        XCTAssertEqual(cases.count, 1)
        let activeCase = try XCTUnwrap(cases.first)
        XCTAssertEqual(activeCase.status, .active)
        XCTAssertEqual(
            LensStatisticsService.daysUntil(activeCase.nextRecommendedReplacementDate, referenceDate: referenceDate),
            89
        )
    }

    func testSeedPreviewDataCreatesActiveCleaningSolution() throws {
        try UITestSupport.seedPreviewData(context: context, referenceDate: TestSupport.date(2026, 7, 12))
        let solutions = try context.fetch(FetchDescriptor<CleaningSolution>())
        XCTAssertEqual(solutions.count, 1)
        XCTAssertEqual(solutions.first?.status, .active)
    }

    func testSeedPreviewDataCreatesActiveWearSessionForSeededPair() throws {
        let referenceDate = TestSupport.date(2026, 7, 12)
        let pair = try UITestSupport.seedPreviewData(context: context, referenceDate: referenceDate)

        let sessions = try context.fetch(FetchDescriptor<WearSession>())
        XCTAssertEqual(sessions.count, 1)
        let session = try XCTUnwrap(sessions.first)
        XCTAssertEqual(session.status, .active)
        XCTAssertEqual(session.lensPair?.id, pair.id)
    }

    // MARK: - Idempotência

    func testSeedPreviewDataCalledTwiceDoesNotDuplicateAnything() throws {
        let referenceDate = TestSupport.date(2026, 7, 12)
        let firstPair = try UITestSupport.seedPreviewData(context: context, referenceDate: referenceDate)
        let secondPair = try UITestSupport.seedPreviewData(context: context, referenceDate: referenceDate)

        XCTAssertEqual(firstPair.id, secondPair.id, "A segunda chamada deve retornar o mesmo par, não criar outro")
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<LensPair>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<LensUsage>()), 2)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<RoutineCareLog>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<LensCase>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<CleaningSolution>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<WearSession>()), 1)
    }

    func testSeedPreviewDataCalledManyTimesStaysStable() throws {
        let referenceDate = TestSupport.date(2026, 7, 12)
        for _ in 0..<10 {
            try UITestSupport.seedPreviewData(context: context, referenceDate: referenceDate)
        }
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<LensPair>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<LensUsage>()), 2)
    }
}
