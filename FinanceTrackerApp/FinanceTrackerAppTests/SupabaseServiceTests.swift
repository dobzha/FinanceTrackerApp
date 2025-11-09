
import XCTest
@testable import FinanceTrackerApp

final class SupabaseServiceTests: XCTestCase {
    
    // Test date decoding with various formats that Supabase returns
    func testDateDecodingWithMicroseconds() throws {
        // Test the exact problematic date string from the error
        let jsonString = """
        {
            "id": "12345678-1234-1234-1234-123456789012",
            "user_id": "12345678-1234-1234-1234-123456789012",
            "name": "Test Subscription",
            "amount": 9.99,
            "currency": "USD",
            "period": "monthly",
            "repetition_date": "2025-01-01",
            "account_id": null,
            "created_at": "2025-11-07T11:45:05.053904+00:00",
            "updated_at": "2025-11-07T11:45:05.053904+00:00"
        }
        """
        
        let jsonData = jsonString.data(using: .utf8)!
        
        // Create a custom decoder matching the one in SupabaseService
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom(decodeFlexibleDate)
        
        // This should not throw an error
        let subscription = try decoder.decode(SubscriptionItem.self, from: jsonData)
        
        XCTAssertEqual(subscription.name, "Test Subscription")
        XCTAssertNotNil(subscription.createdAt)
        XCTAssertNotNil(subscription.updatedAt)
    }
    
    func testDateDecodingWithMilliseconds() throws {
        let jsonString = """
        {
            "id": "12345678-1234-1234-1234-123456789012",
            "user_id": "12345678-1234-1234-1234-123456789012",
            "name": "Test Account",
            "amount": 100.00,
            "currency": "USD",
            "created_at": "2025-11-07T11:45:05.053+00:00",
            "updated_at": "2025-11-07T11:45:05.053+00:00"
        }
        """
        
        let jsonData = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom(decodeFlexibleDate)
        
        let account = try decoder.decode(FinanceItem.self, from: jsonData)
        
        XCTAssertEqual(account.name, "Test Account")
        XCTAssertNotNil(account.createdAt)
        XCTAssertNotNil(account.updatedAt)
    }
    
    func testDateDecodingWithZTimezone() throws {
        let jsonString = """
        {
            "id": "12345678-1234-1234-1234-123456789012",
            "user_id": "12345678-1234-1234-1234-123456789012",
            "name": "Test Revenue",
            "amount": 500.00,
            "currency": "USD",
            "period": "monthly",
            "repetition_date": "2025-01-01",
            "account_id": null,
            "created_at": "2025-11-07T11:45:05.053Z",
            "updated_at": "2025-11-07T11:45:05.053Z"
        }
        """
        
        let jsonData = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom(decodeFlexibleDate)
        
        let revenue = try decoder.decode(RevenueItem.self, from: jsonData)
        
        XCTAssertEqual(revenue.name, "Test Revenue")
        XCTAssertNotNil(revenue.createdAt)
        XCTAssertNotNil(revenue.updatedAt)
    }
    
    func testDateDecodingWithNoFractionalSeconds() throws {
        let jsonString = """
        {
            "id": "12345678-1234-1234-1234-123456789012",
            "user_id": "12345678-1234-1234-1234-123456789012",
            "name": "Test Account 2",
            "amount": 200.00,
            "currency": "USD",
            "created_at": "2025-11-07T11:45:05+00:00",
            "updated_at": "2025-11-07T11:45:05+00:00"
        }
        """
        
        let jsonData = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom(decodeFlexibleDate)
        
        let account = try decoder.decode(FinanceItem.self, from: jsonData)
        
        XCTAssertEqual(account.name, "Test Account 2")
        XCTAssertNotNil(account.createdAt)
        XCTAssertNotNil(account.updatedAt)
    }
    
    // MARK: - Date Decoding Helper (copied from SupabaseService)
    
    /// Decodes dates in various formats returned by Supabase
    private func decodeFlexibleDate(from decoder: Decoder) throws -> Date {
        let container = try decoder.singleValueContainer()
        let dateString = try container.decode(String.self)
        
        // Process the date string to handle microseconds (6+ digits after decimal)
        var processedDateString = dateString
        
        // Regex to match fractional seconds with 4 or more digits
        if let regex = try? NSRegularExpression(pattern: "\\.(\\d{4,})([+-]\\d{2}:\\d{2}|Z)", options: []),
           let match = regex.firstMatch(in: dateString, options: [], range: NSRange(dateString.startIndex..., in: dateString)) {
            if let fractionalRange = Range(match.range(at: 1), in: dateString),
               let timezoneRange = Range(match.range(at: 2), in: dateString) {
                let fractional = String(dateString[fractionalRange])
                let timezone = String(dateString[timezoneRange])
                let milliseconds = String(fractional.prefix(3))
                let beforeFractional = dateString[..<fractionalRange.lowerBound]
                processedDateString = beforeFractional + "." + milliseconds + timezone
            }
        }
        
        // Try ISO8601DateFormatter
        if #available(iOS 15.0, *) {
            let iso8601 = ISO8601DateFormatter()
            iso8601.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = iso8601.date(from: processedDateString) {
                return date
            }
        }
        
        // Fallback: Try manual parsing
        let formats = [
            "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ",
            "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZZZZZ",
            "yyyy-MM-dd'T'HH:mm:ssZZZZZ",
            "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'",
            "yyyy-MM-dd'T'HH:mm:ss'Z'",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd",
            "yyyy-MM-dd HH:mm:ss"
        ]
        
        for format in formats {
            if let date = parseDate(processedDateString, format: format) {
                return date
            }
        }
        
        for format in formats {
            if let date = parseDate(dateString, format: format) {
                return date
            }
        }
        
        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "Cannot decode date string: \(dateString)"
        )
    }
    
    private func parseDate(_ dateString: String, format: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.date(from: dateString)
    }
}

