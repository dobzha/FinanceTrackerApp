
import XCTest
@testable import FinanceTrackerApp

final class FinancialCalculationsTests: XCTestCase {
    func testGenerateMonthlySubscriptionTransactions() async {
        let sub = SubscriptionItem(id: UUID(), userId: UUID(), name: "Test", amount: 100, currency: "USD", period: .monthly, repetitionDate: Date(), accountId: nil, createdAt: nil, updatedAt: nil)
        let tx = FinancialCalculations.generateProjectedTransactions(subscriptions: [sub], revenues: [], endDate: Calendar.current.date(byAdding: .month, value: 3, to: Date())!)
        XCTAssertTrue(tx.count >= 3)
    }
}
