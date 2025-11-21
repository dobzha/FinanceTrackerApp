
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
    
    /// Processes transactions for a specific account immediately (used after creating/updating subscriptions/revenues)
    func processTransactionsForAccount(
        account: FinanceItem,
        subscriptions: [SubscriptionItem],
        revenues: [RevenueItem],
        isAuthenticated: Bool
    ) async throws -> FinanceItem {
        return try await processAccountTransactions(
            account: account,
            subscriptions: subscriptions,
            revenues: revenues,
            isAuthenticated: isAuthenticated
        )
    }
    
    /// Processes pending transactions for a single account
    private func processAccountTransactions(
        account: FinanceItem,
        subscriptions: [SubscriptionItem],
        revenues: [RevenueItem],
        isAuthenticated: Bool
    ) async throws -> FinanceItem {
        let now = Date()
        let calendar = Calendar.current
        let nowStartOfDay = calendar.startOfDay(for: now)
        
        // Determine the start date for processing
        // If lastProcessedDate is today or earlier, we need to process from there to today
        // If lastProcessedDate is in the future, don't process
        let lastProcessed = account.lastProcessedDate ?? account.createdAt ?? now
        let lastProcessedStartOfDay = calendar.startOfDay(for: lastProcessed)
        
        // Don't process if lastProcessedDate is in the future
        guard lastProcessedStartOfDay <= nowStartOfDay else {
            return account
        }
        
        // Always process from lastProcessedDate (or start of today if processing same day) to end of today
        // This ensures we catch any new subscriptions/revenues added today
        let startDateStartOfDay = lastProcessedStartOfDay
        
        // Filter subscriptions and revenues linked to this account
        let accountSubscriptions = subscriptions.filter { $0.accountId == account.id }
        let accountRevenues = revenues.filter { $0.accountId == account.id }
        
        // Use end of today to ensure today's transactions are included
        // We'll use start of day for comparison in calculateOccurrences, so endDate should be start of tomorrow
        // to include all of today
        guard let tomorrowStartOfDay = calendar.date(byAdding: .day, value: 1, to: nowStartOfDay) else {
            return account
        }
        let endDate = tomorrowStartOfDay
        
        // Get existing transactions to avoid duplicates
        // Check for existing transactions from the start date to end of today
        let existingTransactions: Set<String>
        do {
            let existing = try await getAccountTransactions(
                accountId: account.id,
                startDate: startDateStartOfDay,
                endDate: endDate,
                isAuthenticated: isAuthenticated
            )
            // Create a set of unique identifiers: "sourceId:transactionDateStartOfDay"
            existingTransactions = Set(existing.map { transaction in
                let dateStartOfDay = calendar.startOfDay(for: transaction.transactionDate)
                return "\(transaction.sourceId):\(dateStartOfDay.timeIntervalSince1970)"
            })
            print("📊 [TransactionProcessingService] Found \(existingTransactions.count) existing transactions for account '\(account.name)' from \(startDateStartOfDay) to \(endDate)")
        } catch {
            print("⚠️ [TransactionProcessingService] Error fetching existing transactions: \(error)")
            existingTransactions = Set()
        }
        
        // Generate transactions for subscriptions (negative amounts)
        let subscriptionTransactions = generateTransactions(
            for: accountSubscriptions,
            account: account,
            startDate: startDateStartOfDay,
            endDate: endDate,
            type: .subscription,
            existingTransactions: existingTransactions
        )
        
        // Generate transactions for revenues (positive amounts)
        let revenueTransactions = generateTransactions(
            for: accountRevenues,
            account: account,
            startDate: startDateStartOfDay,
            endDate: endDate,
            type: .revenue,
            existingTransactions: existingTransactions
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
        
        print("💰 [TransactionProcessingService] Processing \(allTransactions.count) transactions for account '\(account.name)'. Balance change: \(totalChange) (from \(account.amount) to \(account.amount + totalChange))")
        
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
        type: TransactionType,
        existingTransactions: Set<String>
    ) -> [Transaction] {
        var transactions: [Transaction] = []
        let calendar = Calendar.current
        
        for subscription in subscriptions {
            let occurrences = calculateOccurrences(
                period: subscription.period.rawValue,
                repetitionDate: subscription.repetitionDate,
                startDate: startDate,
                endDate: endDate
            )
            
            for occurrence in occurrences {
                let occurrenceStartOfDay = calendar.startOfDay(for: occurrence)
                let transactionKey = "\(subscription.id):\(occurrenceStartOfDay.timeIntervalSince1970)"
                
                // Skip if transaction already exists
                if existingTransactions.contains(transactionKey) {
                    continue
                }
                
                let transaction = Transaction(
                    id: UUID(),
                    userId: account.userId,
                    accountId: account.id,
                    amount: -subscription.amount, // Negative for subscriptions
                    currency: subscription.currency,
                    transactionDate: occurrenceStartOfDay, // Use start of day for consistency
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
        type: TransactionType,
        existingTransactions: Set<String>
    ) -> [Transaction] {
        var transactions: [Transaction] = []
        let calendar = Calendar.current
        let startStartOfDay = calendar.startOfDay(for: startDate)
        let endStartOfDay = calendar.startOfDay(for: endDate)
        
        for revenue in revenues {
            // Handle one-time revenues separately
            if revenue.period == .once {
                // Check if this one-time revenue should be applied
                if let repetitionDate = revenue.repetitionDate {
                    let repStartOfDay = calendar.startOfDay(for: repetitionDate)
                    // Include if the date is within the range (inclusive)
                    if repStartOfDay >= startStartOfDay && repStartOfDay <= endStartOfDay {
                        let transactionKey = "\(revenue.id):\(repStartOfDay.timeIntervalSince1970)"
                        
                        // Skip if transaction already exists
                        if !existingTransactions.contains(transactionKey) {
                            let transaction = Transaction(
                                id: UUID(),
                                userId: account.userId,
                                accountId: account.id,
                                amount: revenue.amount, // Positive for revenues
                                currency: revenue.currency,
                                transactionDate: repStartOfDay, // Use start of day for consistency
                                transactionType: type,
                                sourceId: revenue.id,
                                sourceName: revenue.name,
                                description: "Revenue (one-time): \(revenue.name)",
                                createdAt: Date()
                            )
                            transactions.append(transaction)
                        }
                    }
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
                let occurrenceStartOfDay = calendar.startOfDay(for: occurrence)
                let transactionKey = "\(revenue.id):\(occurrenceStartOfDay.timeIntervalSince1970)"
                
                // Skip if transaction already exists
                if existingTransactions.contains(transactionKey) {
                    continue
                }
                
                let transaction = Transaction(
                    id: UUID(),
                    userId: account.userId,
                    accountId: account.id,
                    amount: revenue.amount, // Positive for revenues
                    currency: revenue.currency,
                    transactionDate: occurrenceStartOfDay, // Use start of day for consistency
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
        
        // Normalize dates to start of day for comparison
        let repStartOfDay = calendar.startOfDay(for: repetitionDate)
        let startStartOfDay = calendar.startOfDay(for: startDate)
        let endStartOfDay = calendar.startOfDay(for: endDate)
        
        // Start from the repetition date
        var currentDate = repStartOfDay
        
        // If repetition date is before start date, find the first occurrence >= startDate
        if currentDate < startStartOfDay {
            // Find the first occurrence after or equal to startDate
            while currentDate < startStartOfDay {
                guard let nextDate = addPeriod(to: currentDate, period: period) else {
                    break
                }
                currentDate = calendar.startOfDay(for: nextDate)
            }
        }
        
        // Collect all occurrences until endDate (inclusive)
        // Use start of day comparison to ensure same-day transactions are included
        while currentDate <= endStartOfDay {
            occurrences.append(currentDate)
            guard let nextDate = addPeriod(to: currentDate, period: period) else {
                break
            }
            currentDate = calendar.startOfDay(for: nextDate)
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

