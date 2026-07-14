import XCTest
import SwiftData
@testable import MinhasLentes

@MainActor
final class OnboardingViewModelTests: XCTestCase {
    var context: ModelContext!

    override func setUp() {
        super.setUp()
        context = TestSupport.makeContext()
    }

    override func tearDown() {
        context = nil
        super.tearDown()
    }

    private func makeSettings() -> AppSettings {
        let settings = AppSettings()
        context.insert(settings)
        return settings
    }

    func testCreateInitialDataPairModeCreatesOnePair() async throws {
        let settings = makeSettings()
        let viewModel = OnboardingViewModel()
        viewModel.startDate = TestSupport.date(2026, 7, 1)
        viewModel.maximumUses = 30
        viewModel.trackingMode = .pair

        let success = await viewModel.createInitialData(settings: settings, context: context)

        XCTAssertTrue(success)
        let pairs = try LensPairService.allPairs(context: context)
        XCTAssertEqual(pairs.count, 1)
        XCTAssertEqual(pairs.first?.side, .both)
        XCTAssertEqual(pairs.first?.maximumUses, 30)
        XCTAssertEqual(settings.maximumUses, 30)
        XCTAssertEqual(settings.trackingMode, .pair)
    }

    func testCreateInitialDataIndividualModeCreatesTwoPairs() async throws {
        let settings = makeSettings()
        let viewModel = OnboardingViewModel()
        viewModel.trackingMode = .individual

        let success = await viewModel.createInitialData(settings: settings, context: context)

        XCTAssertTrue(success)
        let pairs = try LensPairService.allPairs(context: context)
        XCTAssertEqual(pairs.count, 2)
        XCTAssertTrue(pairs.contains { $0.side == .right })
        XCTAssertTrue(pairs.contains { $0.side == .left })
    }

    func testCreateInitialDataRegistersCaseCleaning() async throws {
        let settings = makeSettings()
        let viewModel = OnboardingViewModel()
        let cleaningDate = TestSupport.date(2026, 6, 20)
        viewModel.lastCleaningDate = cleaningDate

        let success = await viewModel.createInitialData(settings: settings, context: context)

        XCTAssertTrue(success)
        let lastCleaning = try CaseCleaningService.lastCleaning(context: context)
        XCTAssertNotNil(lastCleaning)
        XCTAssertEqual(
            Calendar.current.isDate(lastCleaning!.cleaningDate, inSameDayAs: cleaningDate),
            true
        )
    }

    func testCreateInitialDataDoesNotMarkOnboardingComplete() async throws {
        let settings = makeSettings()
        let viewModel = OnboardingViewModel()

        _ = await viewModel.createInitialData(settings: settings, context: context)

        XCTAssertFalse(settings.hasCompletedOnboarding, "createInitialData não deve concluir o onboarding — só completeOnboarding, ao final do passo de notificações")
    }

    func testCompleteOnboardingMarksSettingsComplete() {
        let settings = makeSettings()
        let viewModel = OnboardingViewModel()

        viewModel.completeOnboarding(settings: settings, context: context)

        XCTAssertTrue(settings.hasCompletedOnboarding)
        XCTAssertNil(viewModel.presentedError)
    }
}
