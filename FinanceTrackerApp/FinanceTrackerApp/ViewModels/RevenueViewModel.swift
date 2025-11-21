
import Foundation

@MainActor
final class RevenueViewModel: ObservableObject {
    @Published var revenues: [RevenueItem] = []
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
                    
                    print("📥 [RevenueViewModel] Loading from Supabase...")
                    
                    // Fetch data sequentially to avoid overwhelming the connection
                    let revs = try await SupabaseService.shared.fetchRevenues()
                    
                    // Check cancellation between requests
                    try Task.checkCancellation()
                    
                    let accs = try await SupabaseService.shared.fetchAccounts()
                    
                    // Check if task was cancelled before updating UI
                    try Task.checkCancellation()
                    
                    revenues = revs
                    accounts = accs
                    errorMessage = nil
                    print("✅ [RevenueViewModel] Loaded \(revenues.count) revenues, \(accounts.count) accounts")
                } catch is CancellationError {
                    print("⚠️ [RevenueViewModel] Load task was cancelled")
                    // Don't update UI or show error for cancelled tasks
                    // Keep existing data instead of clearing
                } catch {
                    let nsError = error as NSError
                    // Ignore cancelled network errors (don't show error to user)
                    if nsError.code == NSURLErrorCancelled || nsError.code == -999 {
                        print("⚠️ [RevenueViewModel] Network request was cancelled, keeping existing data")
                        return
                    }
                    
                    // Only show user-facing errors for real failures
                    print("❌ [RevenueViewModel] Error: \(nsError.localizedDescription)")
                    errorMessage = nsError.localizedDescription
                    // Keep existing data on error instead of clearing
                }
            } else {
                // Load from local storage when not authenticated
                print("📂 [RevenueViewModel] Loading from local storage")
                revenues = LocalStorageService.shared.loadRevenues()
                accounts = LocalStorageService.shared.loadAccounts()
                errorMessage = nil
            }
        }
        
        await loadTask?.value
    }

    func create(name: String, amount: Double, currency: String, period: RevenuePeriod, repetitionDate: Date?, accountId: UUID?) async -> Bool {
        do {
            // Normalize date to UTC midnight to avoid timezone shifts when encoding
            let normalizedDate = repetitionDate != nil ? DateCalculations.normalizeToUTCMidnight(repetitionDate!) : nil
            
            let item: RevenueItem
            
            if authViewModel.isAuthenticated {
                // Get current user ID for authenticated users
                guard let currentUser = await SupabaseService.shared.getCurrentUser() else {
                    errorMessage = "Authentication error. Please sign in again."
                    return false
                }
                
                item = RevenueItem(id: UUID(), userId: currentUser.id, name: name, amount: amount, currency: currency, period: period, repetitionDate: normalizedDate, accountId: accountId, createdAt: nil, updatedAt: nil)
                try await SupabaseService.shared.createRevenue(item)
            } else {
                // Create revenue locally for unauthenticated users
                item = RevenueItem(id: UUID(), userId: UUID(), name: name, amount: amount, currency: currency, period: period, repetitionDate: normalizedDate, accountId: accountId, createdAt: nil, updatedAt: nil)
                LocalStorageService.shared.addRevenue(item)
            }
            
            // If revenue is linked to an account, process transactions immediately
            if let accountId = accountId {
                do {
                    // Fetch the latest account data
                    let account: FinanceItem
                    if authViewModel.isAuthenticated {
                        let allAccounts = try await SupabaseService.shared.fetchAccounts()
                        guard let fetchedAccount = allAccounts.first(where: { $0.id == accountId }) else {
                            throw NSError(domain: "RevenueViewModel", code: 404, userInfo: [NSLocalizedDescriptionKey: "Account not found"])
                        }
                        account = fetchedAccount
                    } else {
                        let allAccounts = LocalStorageService.shared.loadAccounts()
                        guard let fetchedAccount = allAccounts.first(where: { $0.id == accountId }) else {
                            throw NSError(domain: "RevenueViewModel", code: 404, userInfo: [NSLocalizedDescriptionKey: "Account not found"])
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
                    print("⚠️ [RevenueViewModel] Error processing transactions: \(error)")
                    // Continue anyway - the revenue was created successfully
                }
            }
            
            await load()
            return true
        } catch {
            errorMessage = (error as NSError).localizedDescription
            return false
        }
    }

    func update(_ item: RevenueItem) async -> Bool {
        do {
            // Store the old account ID before update
            let oldAccountId = revenues.first(where: { $0.id == item.id })?.accountId
            
            // Normalize date to UTC midnight to avoid timezone shifts when encoding
            let normalizedDate = item.repetitionDate != nil ? DateCalculations.normalizeToUTCMidnight(item.repetitionDate!) : nil
            var normalizedItem = item
            normalizedItem.repetitionDate = normalizedDate
            
            if authViewModel.isAuthenticated {
                try await SupabaseService.shared.updateRevenue(normalizedItem)
            } else {
                LocalStorageService.shared.updateRevenue(normalizedItem)
            }
            
            // If revenue is linked to an account, process transactions immediately
            let accountId = normalizedItem.accountId ?? oldAccountId
            if let accountId = accountId {
                do {
                    // Fetch the latest account data
                    let account: FinanceItem
                    if authViewModel.isAuthenticated {
                        let allAccounts = try await SupabaseService.shared.fetchAccounts()
                        guard let fetchedAccount = allAccounts.first(where: { $0.id == accountId }) else {
                            throw NSError(domain: "RevenueViewModel", code: 404, userInfo: [NSLocalizedDescriptionKey: "Account not found"])
                        }
                        account = fetchedAccount
                    } else {
                        let allAccounts = LocalStorageService.shared.loadAccounts()
                        guard let fetchedAccount = allAccounts.first(where: { $0.id == accountId }) else {
                            throw NSError(domain: "RevenueViewModel", code: 404, userInfo: [NSLocalizedDescriptionKey: "Account not found"])
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
                    print("⚠️ [RevenueViewModel] Error processing transactions: \(error)")
                    // Continue anyway - the revenue was updated successfully
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
                try await SupabaseService.shared.deleteRevenue(id: id)
            } else {
                LocalStorageService.shared.deleteRevenue(id: id)
            }
            revenues.removeAll { $0.id == id }
            return true
        } catch {
            errorMessage = (error as NSError).localizedDescription
            return false
        }
    }
}
