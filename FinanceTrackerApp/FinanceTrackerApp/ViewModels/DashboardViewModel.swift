
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
        let now = Date()
        
        if selectedDate <= now {
            // Calculate historical balance using actual transactions from database
            await calculateHistoricalBalance(upToDate: selectedDate)
        } else {
            // Calculate future projections using projected transactions
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
    }
    
    /// Calculates historical balance using actual transaction records
    private func calculateHistoricalBalance(upToDate: Date) async {
        do {
            var totalBalance = 0.0
            
            // For each account, calculate its balance at the historical date
            for account in accounts {
                // Fetch all transactions for this account up to the selected date
                let transactions: [Transaction]
                
                if authViewModel.isAuthenticated {
                    transactions = try await SupabaseService.shared.fetchTransactions(
                        accountId: account.id,
                        startDate: nil,
                        endDate: upToDate
                    )
                } else {
                    transactions = LocalStorageService.shared.loadTransactions(
                        accountId: account.id,
                        startDate: nil,
                        endDate: upToDate
                    )
                }
                
                // Calculate account balance at the historical date
                let accountBalance = await calculateAccountBalanceAtDate(
                    account: account,
                    transactions: transactions,
                    targetDate: upToDate
                )
                
                totalBalance += accountBalance
            }
            
            projectedBalanceForSelectedDate = totalBalance
        } catch {
            print("❌ [DashboardViewModel] Error calculating historical balance: \(error)")
            // Fallback to projected calculation if there's an error
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
    }
    
    /// Calculates an account's balance at a specific date using actual transactions
    private func calculateAccountBalanceAtDate(
        account: FinanceItem,
        transactions: [Transaction],
        targetDate: Date
    ) async -> Double {
        let now = Date()
        
        // Start with the account's current balance
        var balance = account.amount
        
        // Convert current balance to USD if needed
        if account.currency != "USD" {
            let (convertedUSD, _) = await CurrencyService.shared.convertToUSDWithFallback(
                amount: balance,
                fromCurrency: account.currency
            )
            balance = convertedUSD
        }
        
        // If we're looking at a past date, we need to subtract transactions that happened
        // between the target date and now
        if targetDate < now {
            let futureTransactions = transactions.filter { $0.transactionDate > targetDate }
            
            for transaction in futureTransactions {
                // Convert transaction amount to USD if needed
                let (convertedUSD, _) = await CurrencyService.shared.convertToUSDWithFallback(
                    amount: transaction.amount,
                    fromCurrency: transaction.currency
                )
                balance -= convertedUSD
            }
        }
        
        return balance
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
