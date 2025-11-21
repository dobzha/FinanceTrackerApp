
import Foundation

@MainActor
final class SubscriptionsViewModel: ObservableObject {
    @Published var subscriptions: [SubscriptionItem] = []
    @Published var accounts: [FinanceItem] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    
    private var loadTask: Task<Void, Never>?
    
    private var authViewModel: AuthViewModel {
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
                    
                    print("📥 [SubscriptionsViewModel] Loading from Supabase...")
                    
                    // Fetch data sequentially to avoid overwhelming the connection
                    let subs = try await SupabaseService.shared.fetchSubscriptions()
                    
                    // Check cancellation between requests
                    try Task.checkCancellation()
                    
                    let accs = try await SupabaseService.shared.fetchAccounts()
                    
                    // Check if task was cancelled before updating UI
                    try Task.checkCancellation()
                    
                    subscriptions = subs
                    accounts = accs
                    errorMessage = nil
                    print("✅ [SubscriptionsViewModel] Loaded \(subscriptions.count) subscriptions, \(accounts.count) accounts")
                } catch is CancellationError {
                    print("⚠️ [SubscriptionsViewModel] Load task was cancelled")
                    // Don't update UI or show error for cancelled tasks
                    // Keep existing data instead of clearing
                } catch {
                    let nsError = error as NSError
                    // Ignore cancelled network errors (don't show error to user)
                    if nsError.code == NSURLErrorCancelled || nsError.code == -999 {
                        print("⚠️ [SubscriptionsViewModel] Network request was cancelled, keeping existing data")
                        return
                    }
                    
                    // Only show user-facing errors for real failures
                    print("❌ [SubscriptionsViewModel] Error: \(nsError.localizedDescription)")
                    errorMessage = nsError.localizedDescription
                    // Keep existing data on error instead of clearing
                }
            } else {
                // Load from local storage when not authenticated
                print("📂 [SubscriptionsViewModel] Loading from local storage")
                subscriptions = LocalStorageService.shared.loadSubscriptions()
                accounts = LocalStorageService.shared.loadAccounts()
                errorMessage = nil
            }
        }
        
        await loadTask?.value
    }

    func create(name: String, amount: Double, currency: String, period: SubscriptionPeriod, repetitionDate: Date, accountId: UUID?) async -> Bool {
        do {
            // Normalize date to UTC midnight to avoid timezone shifts when encoding
            let normalizedDate = DateCalculations.normalizeToUTCMidnight(repetitionDate)
            
            let item: SubscriptionItem
            
            if authViewModel.isAuthenticated {
                // Get current user ID for authenticated users
                guard let currentUser = await SupabaseService.shared.getCurrentUser() else {
                    errorMessage = "Authentication error. Please sign in again."
                    return false
                }
                
                item = SubscriptionItem(id: UUID(), userId: currentUser.id, name: name, amount: amount, currency: currency, period: period, repetitionDate: normalizedDate, accountId: accountId, createdAt: nil, updatedAt: nil)
                try await SupabaseService.shared.createSubscription(item)
            } else {
                // Create subscription locally for unauthenticated users
                item = SubscriptionItem(id: UUID(), userId: UUID(), name: name, amount: amount, currency: currency, period: period, repetitionDate: normalizedDate, accountId: accountId, createdAt: nil, updatedAt: nil)
                LocalStorageService.shared.addSubscription(item)
            }
            
            // If subscription is linked to an account, process transactions immediately
            if let accountId = accountId {
                do {
                    // Fetch the latest account data
                    let account: FinanceItem
                    if authViewModel.isAuthenticated {
                        let allAccounts = try await SupabaseService.shared.fetchAccounts()
                        guard let fetchedAccount = allAccounts.first(where: { $0.id == accountId }) else {
                            throw NSError(domain: "SubscriptionsViewModel", code: 404, userInfo: [NSLocalizedDescriptionKey: "Account not found"])
                        }
                        account = fetchedAccount
                    } else {
                        let allAccounts = LocalStorageService.shared.loadAccounts()
                        guard let fetchedAccount = allAccounts.first(where: { $0.id == accountId }) else {
                            throw NSError(domain: "SubscriptionsViewModel", code: 404, userInfo: [NSLocalizedDescriptionKey: "Account not found"])
                        }
                        account = fetchedAccount
                    }
                    
                    let subscriptions: [SubscriptionItem]
                    let revenues: [RevenueItem]
                    
                    if authViewModel.isAuthenticated {
                        subscriptions = try await SupabaseService.shared.fetchSubscriptions()
                        revenues = try await SupabaseService.shared.fetchRevenues()
                    } else {
                        subscriptions = LocalStorageService.shared.loadSubscriptions()
                        revenues = LocalStorageService.shared.loadRevenues()
                    }
                    
                    // Process transactions for the affected account
                    let updatedAccount = try await TransactionProcessingService.shared.processTransactionsForAccount(
                        account: account,
                        subscriptions: subscriptions,
                        revenues: revenues,
                        isAuthenticated: authViewModel.isAuthenticated
                    )
                    
                    // Update the account in the accounts array if it exists
                    if let index = accounts.firstIndex(where: { $0.id == accountId }) {
                        accounts[index] = updatedAccount
                    }
                    
                    // Notify that accounts have been updated
                    NotificationCenter.default.post(name: .init("AccountUpdated"), object: nil)
                } catch {
                    print("⚠️ [SubscriptionsViewModel] Error processing transactions: \(error)")
                    // Continue anyway - the subscription was created successfully
                }
            }
            
            await load()
            return true
        } catch {
            errorMessage = (error as NSError).localizedDescription
            return false
        }
    }

    func update(_ item: SubscriptionItem) async -> Bool {
        do {
            // Store the old account ID before update
            let oldAccountId = subscriptions.first(where: { $0.id == item.id })?.accountId
            
            // Normalize date to UTC midnight to avoid timezone shifts when encoding
            let normalizedDate = DateCalculations.normalizeToUTCMidnight(item.repetitionDate)
            var normalizedItem = item
            normalizedItem.repetitionDate = normalizedDate
            
            if authViewModel.isAuthenticated {
                try await SupabaseService.shared.updateSubscription(normalizedItem)
            } else {
                LocalStorageService.shared.updateSubscription(normalizedItem)
            }
            
            // If subscription is linked to an account, process transactions immediately
            let accountId = normalizedItem.accountId ?? oldAccountId
            if let accountId = accountId {
                do {
                    // Fetch the latest account data
                    let account: FinanceItem
                    if authViewModel.isAuthenticated {
                        let allAccounts = try await SupabaseService.shared.fetchAccounts()
                        guard let fetchedAccount = allAccounts.first(where: { $0.id == accountId }) else {
                            throw NSError(domain: "SubscriptionsViewModel", code: 404, userInfo: [NSLocalizedDescriptionKey: "Account not found"])
                        }
                        account = fetchedAccount
                    } else {
                        let allAccounts = LocalStorageService.shared.loadAccounts()
                        guard let fetchedAccount = allAccounts.first(where: { $0.id == accountId }) else {
                            throw NSError(domain: "SubscriptionsViewModel", code: 404, userInfo: [NSLocalizedDescriptionKey: "Account not found"])
                        }
                        account = fetchedAccount
                    }
                    
                    let subscriptions: [SubscriptionItem]
                    let revenues: [RevenueItem]
                    
                    if authViewModel.isAuthenticated {
                        subscriptions = try await SupabaseService.shared.fetchSubscriptions()
                        revenues = try await SupabaseService.shared.fetchRevenues()
                    } else {
                        subscriptions = LocalStorageService.shared.loadSubscriptions()
                        revenues = LocalStorageService.shared.loadRevenues()
                    }
                    
                    // Process transactions for the affected account
                    let updatedAccount = try await TransactionProcessingService.shared.processTransactionsForAccount(
                        account: account,
                        subscriptions: subscriptions,
                        revenues: revenues,
                        isAuthenticated: authViewModel.isAuthenticated
                    )
                    
                    // Update the account in the accounts array if it exists
                    if let index = accounts.firstIndex(where: { $0.id == accountId }) {
                        accounts[index] = updatedAccount
                    }
                    
                    // Notify that accounts have been updated
                    NotificationCenter.default.post(name: .init("AccountUpdated"), object: nil)
                } catch {
                    print("⚠️ [SubscriptionsViewModel] Error processing transactions: \(error)")
                    // Continue anyway - the subscription was updated successfully
                }
            }
            
            await load()
            return true
        } catch {
            errorMessage = (error as NSError).localizedDescription
            return false
        }
    }

    func delete(id: UUID) async -> Bool {
        do {
            if authViewModel.isAuthenticated {
                try await SupabaseService.shared.deleteSubscription(id: id)
            } else {
                LocalStorageService.shared.deleteSubscription(id: id)
            }
            subscriptions.removeAll { $0.id == id }
            return true
        } catch {
            errorMessage = (error as NSError).localizedDescription
            return false
        }
    }
}
