
import Foundation

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var accounts: [FinanceItem] = []
    @Published var subscriptions: [SubscriptionItem] = []
    @Published var revenues: [RevenueItem] = []

    @Published var totalBalanceUSD: Double = 0
    @Published var monthlySubscriptionsUSD: Double = 0
    @Published var monthlyRevenueUSD: Double = 0
    @Published var projections: [(month: Date, balance: Double)] = []

    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let accTask = SupabaseService.shared.fetchAccounts()
            async let subTask = SupabaseService.shared.fetchSubscriptions()
            async let revTask = SupabaseService.shared.fetchRevenues()
            let (acc, subs, revs) = try await (accTask, subTask, revTask)
            accounts = acc
            subscriptions = subs
            revenues = revs
            await compute()
        } catch {
            errorMessage = (error as NSError).localizedDescription
        }
    }

    private func compute() async {
        projections = await FinancialCalculations.generate12MonthProjections(accounts: accounts, subscriptions: subscriptions, revenues: revenues)
        if let last = projections.last?.balance {
            // not needed; total is computed at current date below
            _ = last
        }
        let now = Date()
        totalBalanceUSD = await FinancialCalculations.calculateTotalBalance(accounts: accounts, transactions: FinancialCalculations.generateProjectedTransactions(subscriptions: subscriptions, revenues: revenues, endDate: now), upToDate: now)
        monthlySubscriptionsUSD = await FinancialCalculations.calculateMonthlySubscriptions(subscriptions)
        monthlyRevenueUSD = await FinancialCalculations.calculateMonthlyRevenue(revenues)
    }
}
