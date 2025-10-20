
import Foundation

enum FallbackRates {
    static let rates: [String: Double] = [
        "UAH": 41.0,
        "EUR": 0.92,
        "GBP": 0.79,
        "JPY": 149.0,
        "CNY": 7.24,
        "CAD": 1.36,
        "AUD": 1.52,
        "CHF": 0.88,
        "RUB": 92.0,
        "INR": 83.0
    ]

    static func getFallbackRate(for currency: String) -> Double? {
        return rates[currency]
    }
}
