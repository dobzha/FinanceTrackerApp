
import Foundation

@MainActor
final class TransactionProcessingService {
    static let shared = TransactionProcessingService()
    
    private init() {}
    
    // MARK: - Main Processing Function
    
    /// Processes all pending transactions for all accounts and updates their balances
    func processAllPendingTransactions(
        accounts: [FinanceItem],
        subscriptions: [SubscriptionItem],
        revenues: [RevenueItem],
        isAuthenticated: Bool
    ) async throws -> [FinanceItem] {
        var updatedAccounts = accounts
        
        for (index, account) in accounts.enumerated() {
            let updatedAccount = try await processAccountTransactions(
                account: account,
                subscriptions: subscriptions,
                revenues: revenues,
                isAuthenticated: isAuthenticated
            )
            updatedAccounts[index] = updatedAccount
        }
        
        return updatedAccounts
    }
    
    /// Processes pending transactions for a single account
    private func processAccountTransactions(
        account: FinanceItem,
        subscriptions: [SubscriptionItem],
        revenues: [RevenueItem],
        isAuthenticated: Bool
    ) async throws -> FinanceItem {
        let now = Date()
        let startDate = account.lastProcessedDate ?? account.createdAt ?? now
        
        // Only process if there's time that has passed since last processing
        guard startDate < now else {
            return account
        }
        
        // Filter subscriptions and revenues linked to this account
        let accountSubscriptions = subscriptions.filter { $0.accountId == account.id }
        let accountRevenues = revenues.filter { $0.accountId == account.id }
        
        // Generate transactions for subscriptions (negative amounts)
        let subscriptionTransactions = generateTransactions(
            for: accountSubscriptions,
            account: account,
            startDate: startDate,
            endDate: now,
            type: .subscription
        )
        
        // Generate transactions for revenues (positive amounts)
        let revenueTransactions = generateTransactions(
            for: accountRevenues,
            account: account,
            startDate: startDate,
            endDate: now,
            type: .revenue
        )
        
        let allTransactions = subscriptionTransactions + revenueTransactions
        
        // If no new transactions, just update lastProcessedDate
        guard !allTransactions.isEmpty else {
            var updatedAccount = account
            updatedAccount.lastProcessedDate = now
            if isAuthenticated {
                try await SupabaseService.shared.updateAccount(updatedAccount)
            } else {
                LocalStorageService.shared.updateAccount(updatedAccount)
            }
            return updatedAccount
        }
        
        // Calculate total balance change
        let totalChange = allTransactions.reduce(0.0) { result, transaction in
            return result + transaction.amount
        }
        
        // Update account balance
        var updatedAccount = account
        updatedAccount.amount += totalChange
        updatedAccount.lastProcessedDate = now
        
        // Save transactions and updated account
        if isAuthenticated {
            // Save all transactions to database
            for transaction in allTransactions {
                try await SupabaseService.shared.createTransaction(transaction)
            }
            // Update account
            try await SupabaseService.shared.updateAccount(updatedAccount)
        } else {
            // Save to local storage
            for transaction in allTransactions {
                LocalStorageService.shared.addTransaction(transaction)
            }
            LocalStorageService.shared.updateAccount(updatedAccount)
        }
        
        print("✅ Processed \(allTransactions.count) transactions for account '\(account.name)'. Balance change: \(totalChange)")
        
        return updatedAccount
    }
    
    // MARK: - Transaction Generation
    
    private func generateTransactions(
        for subscriptions: [SubscriptionItem],
        account: FinanceItem,
        startDate: Date,
        endDate: Date,
        type: TransactionType
    ) -> [Transaction] {
        var transactions: [Transaction] = []
        
        for subscription in subscriptions {
            let occurrences = calculateOccurrences(
                period: subscription.period.rawValue,
                repetitionDate: subscription.repetitionDate,
                startDate: startDate,
                endDate: endDate
            )
            
            for occurrence in occurrences {
                let transaction = Transaction(
                    id: UUID(),
                    userId: account.userId,
                    accountId: account.id,
                    amount: -subscription.amount, // Negative for subscriptions
                    currency: subscription.currency,
                    transactionDate: occurrence,
                    transactionType: type,
                    sourceId: subscription.id,
                    sourceName: subscription.name,
                    description: "Subscription: \(subscription.name)",
                    createdAt: Date()
                )
                transactions.append(transaction)
            }
        }
        
        return transactions
    }
    
    private func generateTransactions(
        for revenues: [RevenueItem],
        account: FinanceItem,
        startDate: Date,
        endDate: Date,
        type: TransactionType
    ) -> [Transaction] {
        var transactions: [Transaction] = []
        
        for revenue in revenues {
            // Handle one-time revenues separately
            if revenue.period == .once {
                // Check if this one-time revenue should be applied
                if let repetitionDate = revenue.repetitionDate,
                   repetitionDate >= startDate && repetitionDate <= endDate {
                    let transaction = Transaction(
                        id: UUID(),
                        userId: account.userId,
                        accountId: account.id,
                        amount: revenue.amount, // Positive for revenues
                        currency: revenue.currency,
                        transactionDate: repetitionDate,
                        transactionType: type,
                        sourceId: revenue.id,
                        sourceName: revenue.name,
                        description: "Revenue (one-time): \(revenue.name)",
                        createdAt: Date()
                    )
                    transactions.append(transaction)
                }
                continue
            }
            
            // Handle recurring revenues
            guard let repetitionDate = revenue.repetitionDate else {
                continue
            }
            
            let occurrences = calculateOccurrences(
                period: revenue.period.rawValue,
                repetitionDate: repetitionDate,
                startDate: startDate,
                endDate: endDate
            )
            
            for occurrence in occurrences {
                let transaction = Transaction(
                    id: UUID(),
                    userId: account.userId,
                    accountId: account.id,
                    amount: revenue.amount, // Positive for revenues
                    currency: revenue.currency,
                    transactionDate: occurrence,
                    transactionType: type,
                    sourceId: revenue.id,
                    sourceName: revenue.name,
                    description: "Revenue: \(revenue.name)",
                    createdAt: Date()
                )
                transactions.append(transaction)
            }
        }
        
        return transactions
    }
    
    // MARK: - Date Calculations
    
    /// Calculates all occurrences of a recurring event between startDate and endDate
    private func calculateOccurrences(
        period: String,
        repetitionDate: Date,
        startDate: Date,
        endDate: Date
    ) -> [Date] {
        var occurrences: [Date] = []
        let calendar = Calendar.current
        
        // Start from the repetition date
        var currentDate = repetitionDate
        
        // Find the first occurrence after or equal to startDate
        while currentDate < startDate {
            guard let nextDate = addPeriod(to: currentDate, period: period) else {
                break
            }
            currentDate = nextDate
        }
        
        // Collect all occurrences until endDate
        while currentDate <= endDate {
            occurrences.append(currentDate)
            guard let nextDate = addPeriod(to: currentDate, period: period) else {
                break
            }
            currentDate = nextDate
        }
        
        return occurrences
    }
    
    /// Adds one period to a date
    private func addPeriod(to date: Date, period: String) -> Date? {
        let calendar = Calendar.current
        switch period {
        case "weekly":
            return calendar.date(byAdding: .weekOfYear, value: 1, to: date)
        case "monthly":
            return calendar.date(byAdding: .month, value: 1, to: date)
        case "yearly":
            return calendar.date(byAdding: .year, value: 1, to: date)
        default:
            return nil
        }
    }
    
    // MARK: - Historical Balance Calculation
    
    /// Calculates the balance of an account at a specific historical date
    func calculateHistoricalBalance(
        account: FinanceItem,
        transactions: [Transaction],
        upToDate: Date
    ) async -> Double {
        // Start with the account's current amount
        var balance = account.amount
        
        // Get only transactions for this account up to the specified date
        let accountTransactions = transactions.filter { transaction in
            transaction.accountId == account.id && transaction.transactionDate <= upToDate
        }
        
        // We need to work backwards from current balance if we're looking at a past date
        // Or forwards if we're looking at a future date
        let now = Date()
        
        if upToDate < now {
            // Looking at the past: subtract transactions that happened after upToDate
            let futureTransactions = transactions.filter { transaction in
                transaction.accountId == account.id && transaction.transactionDate > upToDate && transaction.transactionDate <= now
            }
            
            for transaction in futureTransactions {
                balance -= transaction.amount
            }
        } else {
            // Looking at the future: this is handled elsewhere (projections)
            // For now, just return current balance
        }
        
        return balance
    }
    
    /// Gets all transactions for an account within a date range
    func getAccountTransactions(
        accountId: UUID,
        startDate: Date,
        endDate: Date,
        isAuthenticated: Bool
    ) async throws -> [Transaction] {
        if isAuthenticated {
            return try await SupabaseService.shared.fetchTransactions(
                accountId: accountId,
                startDate: startDate,
                endDate: endDate
            )
        } else {
            return LocalStorageService.shared.loadTransactions(
                accountId: accountId,
                startDate: startDate,
                endDate: endDate
            )
        }
    }
}

