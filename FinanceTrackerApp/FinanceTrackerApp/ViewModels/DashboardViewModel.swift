
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
    
    @Published var selectedDate: Date = Date()
    @Published var projectedBalanceForSelectedDate: Double = 0

    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    
    private var authViewModel: AuthViewModel {
        // Get the shared AuthViewModel instance
        return AuthViewModel.shared
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        
        if authViewModel.isAuthenticated {
            // Load from Supabase when authenticated
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
        } else {
            // Load from local storage when not authenticated
            accounts = LocalStorageService.shared.loadAccounts()
            subscriptions = LocalStorageService.shared.loadSubscriptions()
            revenues = LocalStorageService.shared.loadRevenues()
            await compute()
        }
    }

    private func compute() async {
        projections = await FinancialCalculations.generate12MonthProjections(accounts: accounts, subscriptions: subscriptions, revenues: revenues)
        if let last = projections.last?.balance {
            // not needed; total is computed at current date below
            _ = last
        }
        let now = Date()
        totalBalanceUSD = await FinancialCalculations.calculateCurrentAccountBalance(accounts: accounts)
        monthlySubscriptionsUSD = await FinancialCalculations.calculateMonthlySubscriptions(subscriptions)
        monthlyRevenueUSD = await FinancialCalculations.calculateMonthlyRevenue(revenues)
        
        // Calculate projected balance for selected date
        await calculateBalanceForSelectedDate()
    }
    
    func calculateBalanceForSelectedDate() async {
        let calendar = Calendar.current
        let endDate = calendar.date(byAdding: .year, value: 1, to: selectedDate) ?? selectedDate
        let transactions = FinancialCalculations.generateProjectedTransactions(
            subscriptions: subscriptions,
            revenues: revenues,
            endDate: endDate,
            currentDate: Date()
        )
        projectedBalanceForSelectedDate = await FinancialCalculations.calculateTotalBalance(
            accounts: accounts,
            transactions: transactions,
            upToDate: selectedDate
        )
    }
    
    func setSelectedDate(_ date: Date) async {
        selectedDate = date
        await calculateBalanceForSelectedDate()
    }
    
    func resetToToday() async {
        selectedDate = Date()
        await calculateBalanceForSelectedDate()
    }
}
