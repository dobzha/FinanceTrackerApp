
import Foundation

@MainActor
final class AccountsViewModel: ObservableObject {
    @Published var accounts: [FinanceItem] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    
    private var authViewModel: AuthViewModel {
        // Get the shared AuthViewModel instance
        return AuthViewModel.shared
    }

    func loadAccounts() async {
        isLoading = true
        defer { isLoading = false }
        
        if authViewModel.isAuthenticated {
            // Load from Supabase when authenticated
            do {
                accounts = try await SupabaseService.shared.fetchAccounts()
            } catch {
                errorMessage = (error as NSError).localizedDescription
            }
        } else {
            // Load from local storage when not authenticated
            accounts = LocalStorageService.shared.loadAccounts()
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
