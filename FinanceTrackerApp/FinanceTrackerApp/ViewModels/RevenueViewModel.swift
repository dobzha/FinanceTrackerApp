
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
            let item: RevenueItem
            
            if authViewModel.isAuthenticated {
                // Get current user ID for authenticated users
                guard let currentUser = await SupabaseService.shared.getCurrentUser() else {
                    errorMessage = "Authentication error. Please sign in again."
                    return false
                }
                
                item = RevenueItem(id: UUID(), userId: currentUser.id, name: name, amount: amount, currency: currency, period: period, repetitionDate: repetitionDate, accountId: accountId, createdAt: nil, updatedAt: nil)
                try await SupabaseService.shared.createRevenue(item)
            } else {
                // Create revenue locally for unauthenticated users
                item = RevenueItem(id: UUID(), userId: UUID(), name: name, amount: amount, currency: currency, period: period, repetitionDate: repetitionDate, accountId: accountId, createdAt: nil, updatedAt: nil)
                LocalStorageService.shared.addRevenue(item)
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
            if authViewModel.isAuthenticated {
                try await SupabaseService.shared.updateRevenue(item)
            } else {
                LocalStorageService.shared.updateRevenue(item)
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
