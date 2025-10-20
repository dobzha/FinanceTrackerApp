
import XCTest
@testable import FinanceTrackerApp

final class DateCalculationsTests: XCTestCase {
    func testMonthlyJan31ToFebEnd() {
        var comps = DateComponents(year: 2025, month: 1, day: 31)
        let calendar = Calendar.current
        let rep = calendar.date(from: comps)!
        comps = DateComponents(year: 2025, month: 2, day: 1)
        let now = calendar.date(from: comps)!
        let next = DateCalculations.getNextMonthlyPayment(repetitionDate: rep, currentDate: now)
        let nextMonth = calendar.component(.month, from: next)
        let nextDay = calendar.component(.day, from: next)
        XCTAssertEqual(nextMonth, 2)
        XCTAssertTrue(nextDay == 28 || nextDay == 29)
    }

    func testYearlyNextYearWhenPassed() {
        let calendar = Calendar.current
        let rep = calendar.date(from: DateComponents(year: 2020, month: 1, day: 1))!
        let now = calendar.date(from: DateComponents(year: 2025, month: 2, day: 1))!
        let next = DateCalculations.getNextYearlyPayment(repetitionDate: rep, currentDate: now)
        XCTAssertEqual(calendar.component(.year, from: next), 2026)
        XCTAssertEqual(calendar.component(.month, from: next), 1)
        XCTAssertEqual(calendar.component(.day, from: next), 1)
    }

    func testOnceRevenueHidesAfterMonth() {
        let calendar = Calendar.current
        let rep = calendar.date(from: DateComponents(year: 2025, month: 3, day: 15))!
        let cur = calendar.date(from: DateComponents(year: 2025, month: 4, day: 1))!
        XCTAssertTrue(DateCalculations.shouldHideOnceRevenue(repetitionDate: rep, currentDate: cur))
    }
}
