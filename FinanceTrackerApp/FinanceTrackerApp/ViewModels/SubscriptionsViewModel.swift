
import Foundation

@MainActor
final class SubscriptionsViewModel: ObservableObject {
    @Published var subscriptions: [SubscriptionItem] = []
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
                async let subsTask = SupabaseService.shared.fetchSubscriptions()
                async let accTask = SupabaseService.shared.fetchAccounts()
                let (subs, accs) = try await (subsTask, accTask)
                subscriptions = subs
                accounts = accs
            } catch {
                errorMessage = (error as NSError).localizedDescription
            }
        } else {
            // Load from local storage when not authenticated
            subscriptions = LocalStorageService.shared.loadSubscriptions()
            accounts = LocalStorageService.shared.loadAccounts()
        }
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
