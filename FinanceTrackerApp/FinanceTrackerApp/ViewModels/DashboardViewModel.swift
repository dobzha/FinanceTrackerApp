
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
    
    private var loadTask: Task<Void, Never>?
    
    private var authViewModel: AuthViewModel {
        // Get the shared AuthViewModel instance
        return AuthViewModel.shared
    }

    func load() async {
        // Cancel any existing load task to prevent multiple simultaneous requests
        loadTask?.cancel()
        
        // Create a new task
        loadTask = Task {
            isLoading = true
            defer { isLoading = false }
            
            if authViewModel.isAuthenticated {
                // Load from Supabase when authenticated
                do {
                    // Check if task was cancelled before starting the network request
                    try Task.checkCancellation()
                    
                    // Fetch data sequentially to avoid overwhelming the connection
                    let acc = try await SupabaseService.shared.fetchAccounts()
                    
                    // Check cancellation between requests
                    try Task.checkCancellation()
                    
                    let subs = try await SupabaseService.shared.fetchSubscriptions()
                    
                    // Check cancellation between requests
                    try Task.checkCancellation()
                    
                    let revs = try await SupabaseService.shared.fetchRevenues()
                    
                    // Check if task was cancelled before updating UI
                    try Task.checkCancellation()
                    
                    accounts = acc
                    subscriptions = subs
                    revenues = revs
                    errorMessage = nil
                    await compute()
                } catch is CancellationError {
                    print("⚠️ [DashboardViewModel] Load task was cancelled")
                    // Don't update UI or show error for cancelled tasks
                    // Keep existing data instead of clearing
                } catch {
                    let nsError = error as NSError
                    // Ignore cancelled network errors (don't show error to user)
                    if nsError.code == NSURLErrorCancelled || nsError.code == -999 {
                        print("⚠️ [DashboardViewModel] Network request was cancelled, keeping existing data")
                        return
                    }
                    
                    // Only show user-facing errors for real failures
                    errorMessage = nsError.localizedDescription
                    // Keep existing data on error instead of clearing
                }
            } else {
                // Load from local storage when not authenticated
                accounts = LocalStorageService.shared.loadAccounts()
                subscriptions = LocalStorageService.shared.loadSubscriptions()
                revenues = LocalStorageService.shared.loadRevenues()
                errorMessage = nil
                await compute()
            }
        }
        
        await loadTask?.value
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
