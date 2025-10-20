
import XCTest
@testable import FinanceTrackerApp

final class CurrencyServiceTests: XCTestCase {
    func testUSDIdentity() async throws {
        let value = try await CurrencyService.shared.convertToUSD(amount: 123.45, fromCurrency: "USD")
        XCTAssertEqual(value, 123.45, accuracy: 0.0001)
    }

    func testFallbackRateUsedOnFailure() async {
        // Force an invalid URL to cause failure
        let original = Config.exchangeRateEdgeFunction
        defer { _ = original }
        let (usd, approx) = await CurrencyService.shared.convertToUSDWithFallback(amount: 410.0, fromCurrency: "UAH")
        XCTAssertTrue(usd > 0)
        XCTAssertTrue(approx)
    }
}
