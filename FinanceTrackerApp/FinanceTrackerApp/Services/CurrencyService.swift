
import Foundation

struct ExchangeRateResponse: Codable {
    let currency: String
    let rate: Double
    let timestamp: String
}

struct CachedRate: Codable {
    let currency: String
    let rate: Double
    let timestamp: Date
}

enum CurrencyError: Error {
    case invalidURL
    case apiError
    case invalidCurrency
}

final class CurrencyService {
    static let shared = CurrencyService()
    private init() {}

    func fetchExchangeRate(currency: String) async throws -> Double {
        if let cached = getCachedRate(for: currency) {
            return cached
        }

        guard let url = URL(string: Config.exchangeRateEdgeFunction) else {
            throw CurrencyError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(Config.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        let body = ["currency": currency]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw CurrencyError.apiError
        }

        let result = try JSONDecoder().decode(ExchangeRateResponse.self, from: data)
        cacheRate(result.rate, for: currency)
        return result.rate
    }

    func convertToUSD(amount: Double, fromCurrency: String) async throws -> Double {
        if fromCurrency == "USD" { return amount }
        let rate = try await fetchExchangeRate(currency: fromCurrency)
        return amount / rate
    }

    func convertToUSDWithFallback(amount: Double, fromCurrency: String) async -> (usd: Double, isApproximate: Bool) {
        do {
            let usd = try await convertToUSD(amount: amount, fromCurrency: fromCurrency)
            return (usd, false)
        } catch {
            if let fallback = FallbackRates.getFallbackRate(for: fromCurrency) {
                return (amount / fallback, true)
            }
            return (amount, true)
        }
    }

    func formatAmountInUSD(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }

    func formatAmount(_ amount: Double, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: amount)) ?? "\(currency) 0.00"
    }

    private func getCachedRate(for currency: String) -> Double? {
        guard let data = UserDefaults.standard.data(forKey: "rate_\(currency)") else { return nil }
        guard let cached = try? JSONDecoder().decode(CachedRate.self, from: data) else { return nil }
        let age = Date().timeIntervalSince(cached.timestamp)
        if age > Config.exchangeRateCacheDuration { return nil }
        return cached.rate
    }

    private func cacheRate(_ rate: Double, for currency: String) {
        let cached = CachedRate(currency: currency, rate: rate, timestamp: Date())
        if let encoded = try? JSONEncoder().encode(cached) {
            UserDefaults.standard.set(encoded, forKey: "rate_\(currency)")
        }
    }
}
