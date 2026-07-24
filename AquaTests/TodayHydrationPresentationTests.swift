import XCTest
@testable import Aqua

final class TodayHydrationPresentationTests: XCTestCase {
    func testStatusThresholdsFollowDailyProgress() {
        XCTAssertEqual(presentation(consumed: 0).status, .starting)
        XCTAssertEqual(presentation(consumed: 400).status, .buildingMomentum)
        XCTAssertEqual(presentation(consumed: 1_000).status, .halfway)
        XCTAssertEqual(presentation(consumed: 1_700).status, .nearlyComplete)
        XCTAssertEqual(presentation(consumed: 2_000).status, .goalReached)
        XCTAssertEqual(presentation(consumed: 2_200).status, .beyondGoal)
    }

    func testAboveGoalProgressCapsOnlyTheVisualFill() {
        let presentation = presentation(consumed: 2_500)

        XCTAssertEqual(presentation.actualFraction, 1.25, accuracy: 0.001)
        XCTAssertEqual(presentation.visualFraction, 1, accuracy: 0.001)
        XCTAssertEqual(presentation.amountAboveGoal, 500, accuracy: 0.001)
        XCTAssertTrue(presentation.hasReachedGoal)
        XCTAssertTrue(presentation.isBeyondGoal)
    }

    func testRemainingAmountComesFromExistingProgress() {
        let presentation = presentation(consumed: 750)

        XCTAssertEqual(presentation.remainingAmount, 1_250, accuracy: 0.001)
        XCTAssertFalse(presentation.hasReachedGoal)
    }

    private func presentation(consumed: Double) -> TodayHydrationPresentation {
        TodayHydrationPresentation(
            progress: DailyHydrationProgress(
                consumedAmount: consumed,
                dailyGoal: 2_000
            )
        )
    }
}
