
import Foundation

@MainActor
final class RevenueViewModel: ObservableObject {
    @Published var revenues: [RevenueItem] = []
    @Published var accounts: [FinanceItem] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    
    private var authViewModel: AuthViewModel {
        return AuthViewModel.shared
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        
        if authViewModel.isAuthenticated {
            // Load from Supabase when authenticated
            do {
                print("📥 [RevenueViewModel] Loading from Supabase...")
                async let revTask = SupabaseService.shared.fetchRevenues()
                async let accTask = SupabaseService.shared.fetchAccounts()
                let (revs, accs) = try await (revTask, accTask)
                revenues = revs
                accounts = accs
                print("✅ [RevenueViewModel] Loaded \(revenues.count) revenues, \(accounts.count) accounts")
            } catch {
                let nsError = error as NSError
                print("❌ [RevenueViewModel] Error: \(nsError.localizedDescription)")
                errorMessage = "Failed to load: \(nsError.localizedDescription)"
                revenues = []
                accounts = []
            }
        } else {
            // Load from local storage when not authenticated
            print("📂 [RevenueViewModel] Loading from local storage")
            revenues = LocalStorageService.shared.loadRevenues()
            accounts = LocalStorageService.shared.loadAccounts()
        }
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
