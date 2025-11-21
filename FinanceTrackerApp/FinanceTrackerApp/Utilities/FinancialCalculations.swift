
import Foundation

struct TransactionModel {
    let id: UUID
    let date: Date
    let amount: Double
    let currency: String
    let accountId: UUID?
    let type: String
}

struct FinancialCalculations {
    static func generateProjectedTransactions(subscriptions: [SubscriptionItem], revenues: [RevenueItem], endDate: Date, currentDate: Date = Date()) -> [TransactionModel] {
        var transactions: [TransactionModel] = []
        let calendar = Calendar.current
        let currentStartOfDay = calendar.startOfDay(for: currentDate)
        
        for s in subscriptions {
            let occ = DateCalculations.generateOccurrences(startDate: s.repetitionDate, period: s.period.rawValue, endDate: endDate)
            for d in occ {
                let dStartOfDay = calendar.startOfDay(for: d)
                // Include today's date in transactions
                if dStartOfDay >= currentStartOfDay {
                    transactions.append(TransactionModel(id: UUID(), date: d, amount: -s.amount, currency: s.currency, accountId: s.accountId, type: "subscription"))
                }
            }
        }
        for r in revenues {
            if r.period == .once, let rep = r.repetitionDate, DateCalculations.shouldHideOnceRevenue(repetitionDate: rep) { continue }
            let occ = DateCalculations.generateOccurrences(startDate: r.repetitionDate ?? Date(), period: r.period.rawValue, endDate: endDate)
            for d in occ {
                let dStartOfDay = calendar.startOfDay(for: d)
                // Include today's date in transactions
                if dStartOfDay >= currentStartOfDay {
                    transactions.append(TransactionModel(id: UUID(), date: d, amount: r.amount, currency: r.currency, accountId: r.accountId, type: "revenue"))
                }
            }
        }
        return transactions.sorted { $0.date < $1.date }
    }

    static func calculateAccountBalance(account: FinanceItem, transactions: [TransactionModel], upToDate: Date) async -> Double {
        var balance = account.amount
        if account.currency != "USD" {
            let (converted, _) = await CurrencyService.shared.convertToUSDWithFallback(amount: account.amount, fromCurrency: account.currency)
            balance = converted
        }
        for t in transactions where t.accountId == account.id && t.date <= upToDate {
            if t.currency != "USD" {
                let (converted, _) = await CurrencyService.shared.convertToUSDWithFallback(amount: t.amount, fromCurrency: t.currency)
                balance += converted
            } else {
                balance += t.amount
            }
        }
        return balance
    }

    static func calculateTotalBalance(accounts: [FinanceItem], transactions: [TransactionModel], upToDate: Date) async -> Double {
        var total = 0.0
        for a in accounts {
            total += await calculateAccountBalance(account: a, transactions: transactions, upToDate: upToDate)
        }
        return total
    }
    
    static func calculateCurrentAccountBalance(accounts: [FinanceItem]) async -> Double {
        var total = 0.0
        for account in accounts {
            if account.currency == "USD" {
                total += account.amount
            } else {
                let (convertedUSD, _) = await CurrencyService.shared.convertToUSDWithFallback(amount: account.amount, fromCurrency: account.currency)
                total += convertedUSD
            }
        }
        return total
    }

    static func generate12MonthProjections(accounts: [FinanceItem], subscriptions: [SubscriptionItem], revenues: [RevenueItem]) async -> [(month: Date, balance: Double)] {
        let calendar = Calendar.current
        let now = Date()
        guard let endDate = calendar.date(byAdding: .month, value: 12, to: now) else { return [] }
        let transactions = generateProjectedTransactions(subscriptions: subscriptions, revenues: revenues, endDate: endDate, currentDate: now)
        var result: [(Date, Double)] = []
        for offset in 0..<12 {
            guard let monthDate = calendar.date(byAdding: .month, value: offset, to: now),
                  let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: calendar.startOfDay(for: monthDate)) else { continue }
            let bal = await calculateTotalBalance(accounts: accounts, transactions: transactions, upToDate: endOfMonth)
            result.append((monthDate, bal))
        }
        return result
    }

    static func calculateMonthlySubscriptions(_ subs: [SubscriptionItem]) async -> Double {
        var total = 0.0
        for s in subs {
            let (usd, _) = await CurrencyService.shared.convertToUSDWithFallback(amount: s.amount, fromCurrency: s.currency)
            switch s.period {
            case .weekly:
                total += usd * 4.33 // Approximate weeks per month
            case .monthly:
                total += usd
            case .yearly:
                total += usd / 12.0
            }
        }
        return total
    }

    static func calculateMonthlyRevenue(_ revs: [RevenueItem]) async -> Double {
        var total = 0.0
        for r in revs where r.period != .once {
            let (usd, _) = await CurrencyService.shared.convertToUSDWithFallback(amount: r.amount, fromCurrency: r.currency)
            switch r.period {
            case .weekly:
                total += usd * 4.33 // Approximate weeks per month
            case .monthly:
                total += usd
            case .yearly:
                total += usd / 12.0
            case .once:
                break // Skip once payments
            }
        }
        return total
    }

    static func calculateNetMonthlyChange(subscriptions: [SubscriptionItem], revenues: [RevenueItem]) async -> Double {
        let income = await calculateMonthlyRevenue(revenues)
        let expenses = await calculateMonthlySubscriptions(subscriptions)
        return income - expenses
    }
}
