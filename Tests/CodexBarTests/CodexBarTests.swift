import XCTest
@testable import CodexBar

final class CodexBarTests: XCTestCase {
    func testRemainingPercentIsClamped() {
        XCTAssertEqual(UsageWindow(durationMinutes: 300, usedPercent: 28, resetsAt: nil).remainingPercent, 72)
        XCTAssertEqual(UsageWindow(durationMinutes: 300, usedPercent: 140, resetsAt: nil).remainingPercent, 0)
    }

    func testClassifiesFiveHourAndWeeklyWindows() {
        let fiveHours = UsageWindow(durationMinutes: 300, usedPercent: 28, resetsAt: nil)
        let week = UsageWindow(durationMinutes: 10_080, usedPercent: 54, resetsAt: nil)
        let snapshot = UsageSnapshot(windows: [fiveHours, week], resetCreditsAvailable: 2, resetCredits: [])
        XCTAssertEqual(snapshot.fiveHour?.remainingPercent, 72)
        XCTAssertEqual(snapshot.weekly?.remainingPercent, 46)
    }
}
