
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
            let item: SubscriptionItem
            
            if authViewModel.isAuthenticated {
                // Get current user ID for authenticated users
                guard let currentUser = await SupabaseService.shared.getCurrentUser() else {
                    errorMessage = "Authentication error. Please sign in again."
                    return false
                }
                
                item = SubscriptionItem(id: UUID(), userId: currentUser.id, name: name, amount: amount, currency: currency, period: period, repetitionDate: repetitionDate, accountId: accountId, createdAt: nil, updatedAt: nil)
                try await SupabaseService.shared.createSubscription(item)
            } else {
                // Create subscription locally for unauthenticated users
                item = SubscriptionItem(id: UUID(), userId: UUID(), name: name, amount: amount, currency: currency, period: period, repetitionDate: repetitionDate, accountId: accountId, createdAt: nil, updatedAt: nil)
                LocalStorageService.shared.addSubscription(item)
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
            if authViewModel.isAuthenticated {
                try await SupabaseService.shared.updateSubscription(item)
            } else {
                LocalStorageService.shared.updateSubscription(item)
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
