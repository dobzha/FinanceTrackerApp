
import Foundation

@MainActor
final class AccountsViewModel: ObservableObject {
    @Published var accounts: [FinanceItem] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    
    private var loadTask: Task<Void, Never>?
    
    private var authViewModel: AuthViewModel {
        // Get the shared AuthViewModel instance
        return AuthViewModel.shared
    }

    func loadAccounts() async {
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
                    
                    print("📥 [AccountsViewModel] Loading accounts from Supabase...")
                    let fetchedAccounts = try await SupabaseService.shared.fetchAccounts()
                    
                    // Check if task was cancelled before updating UI
                    try Task.checkCancellation()
                    
                    accounts = fetchedAccounts
                    errorMessage = nil
                    print("✅ [AccountsViewModel] Loaded \(accounts.count) accounts from Supabase")
                    
                    // Process pending transactions to update balances
                    await processTransactionsForAllAccounts()
                } catch is CancellationError {
                    print("⚠️ [AccountsViewModel] Load task was cancelled")
                    // Don't update UI or show error for cancelled tasks
                    // Keep existing data instead of clearing
                } catch {
                    let nsError = error as NSError
                    // Ignore cancelled network errors (don't show error to user)
                    if nsError.code == NSURLErrorCancelled || nsError.code == -999 {
                        print("⚠️ [AccountsViewModel] Network request was cancelled, keeping existing data")
                        return
                    }
                    
                    // Only show user-facing errors for real failures
                    print("❌ [AccountsViewModel] Error loading from Supabase: \(nsError.localizedDescription)")
                    print("❌ [AccountsViewModel] Full error: \(error)")
                    errorMessage = nsError.localizedDescription
                    // Keep existing accounts on error instead of clearing them
                }
            } else {
                // Load from local storage when not authenticated
                print("📂 [AccountsViewModel] Loading from local storage (not authenticated)")
                accounts = LocalStorageService.shared.loadAccounts()
                errorMessage = nil
                
                // Process pending transactions for local accounts
                await processTransactionsForAllAccounts()
            }
        }
        
        await loadTask?.value
    }
    
    /// Processes all pending transactions and updates account balances
    private func processTransactionsForAllAccounts() async {
        do {
            // Fetch subscriptions and revenues
            let subscriptions: [SubscriptionItem]
            let revenues: [RevenueItem]
            
            if authViewModel.isAuthenticated {
                subscriptions = try await SupabaseService.shared.fetchSubscriptions()
                revenues = try await SupabaseService.shared.fetchRevenues()
            } else {
                subscriptions = LocalStorageService.shared.loadSubscriptions()
                revenues = LocalStorageService.shared.loadRevenues()
            }
            
            // Process transactions and get updated accounts
            let updatedAccounts = try await TransactionProcessingService.shared.processAllPendingTransactions(
                accounts: accounts,
                subscriptions: subscriptions,
                revenues: revenues,
                isAuthenticated: authViewModel.isAuthenticated
            )
            
            // Update the accounts array
            accounts = updatedAccounts
            
            print("✅ [AccountsViewModel] Processed transactions for all accounts")
        } catch {
            print("❌ [AccountsViewModel] Error processing transactions: \(error)")
            // Don't show error to user - keep existing balances
        }
    }

    func createAccount(name: String, amount: Double, currency: String) async -> Bool {
        do {
            let item: FinanceItem
            
            if authViewModel.isAuthenticated {
                // Get current user ID for authenticated users
                guard let currentUser = await SupabaseService.shared.getCurrentUser() else {
                    errorMessage = "Authentication error. Please sign in again."
                    return false
                }
                
                item = FinanceItem(
                    id: UUID(),
                    userId: currentUser.id,
                    name: name,
                    amount: amount,
                    currency: currency,
                    lastProcessedDate: Date(),
                    createdAt: nil,
                    updatedAt: nil
                )
                try await SupabaseService.shared.createAccount(item)
            } else {
                // Create account locally for unauthenticated users
                item = FinanceItem(
                    id: UUID(),
                    userId: UUID(), // Dummy UUID for local storage
                    name: name,
                    amount: amount,
                    currency: currency,
                    lastProcessedDate: Date(),
                    createdAt: nil,
                    updatedAt: nil
                )
                LocalStorageService.shared.addAccount(item)
            }
            
            await loadAccounts()
            NotificationCenter.default.post(name: .init("AccountUpdated"), object: nil)
            return true
        } catch {
            errorMessage = (error as NSError).localizedDescription
            return false
        }
    }

    func updateAccount(_ account: FinanceItem) async -> Bool {
        do {
            if authViewModel.isAuthenticated {
                try await SupabaseService.shared.updateAccount(account)
            } else {
                LocalStorageService.shared.updateAccount(account)
            }
            await loadAccounts()
            NotificationCenter.default.post(name: .init("AccountUpdated"), object: nil)
            return true
        } catch {
            errorMessage = (error as NSError).localizedDescription
            return false
        }
    }

    func deleteAccount(_ account: FinanceItem) async -> Bool {
        do {
            if authViewModel.isAuthenticated {
                try await SupabaseService.shared.deleteAccount(id: account.id)
            } else {
                LocalStorageService.shared.deleteAccount(id: account.id)
            }
            accounts.removeAll { $0.id == account.id }
            NotificationCenter.default.post(name: .init("AccountUpdated"), object: nil)
            return true
        } catch {
            errorMessage = (error as NSError).localizedDescription
            return false
        }
    }

    func linkedCounts(for accountId: UUID) async -> (subscriptions: Int, revenues: Int) {
        do {
            let subs = try await SupabaseService.shared.fetchSubscriptions().filter { $0.accountId == accountId }
            let revs = try await SupabaseService.shared.fetchRevenues().filter { $0.accountId == accountId }
            return (subs.count, revs.count)
        } catch {
            return (0, 0)
        }
    }
}
