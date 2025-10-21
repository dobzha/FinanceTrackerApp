import Foundation

final class LocalStorageService: ObservableObject {
    static let shared = LocalStorageService()
    private init() {}
    
    // Storage keys
    private let accountsKey = "local_accounts_v1"
    private let subscriptionsKey = "local_subscriptions_v1"
    private let revenuesKey = "local_revenues_v1"
    
    // MARK: - Accounts
    
    func saveAccounts(_ accounts: [FinanceItem]) {
        if let data = try? JSONEncoder().encode(accounts) {
            UserDefaults.standard.set(data, forKey: accountsKey)
        }
    }
    
    func loadAccounts() -> [FinanceItem] {
        guard let data = UserDefaults.standard.data(forKey: accountsKey),
              let accounts = try? JSONDecoder().decode([FinanceItem].self, from: data) else {
            return []
        }
        return accounts
    }
    
    func addAccount(_ account: FinanceItem) {
        var accounts = loadAccounts()
        accounts.append(account)
        saveAccounts(accounts)
    }
    
    func updateAccount(_ account: FinanceItem) {
        var accounts = loadAccounts()
        if let index = accounts.firstIndex(where: { $0.id == account.id }) {
            accounts[index] = account
            saveAccounts(accounts)
        }
    }
    
    func deleteAccount(id: UUID) {
        var accounts = loadAccounts()
        accounts.removeAll { $0.id == id }
        saveAccounts(accounts)
    }
    
    // MARK: - Subscriptions
    
    func saveSubscriptions(_ subscriptions: [SubscriptionItem]) {
        if let data = try? JSONEncoder().encode(subscriptions) {
            UserDefaults.standard.set(data, forKey: subscriptionsKey)
        }
    }
    
    func loadSubscriptions() -> [SubscriptionItem] {
        guard let data = UserDefaults.standard.data(forKey: subscriptionsKey),
              let subscriptions = try? JSONDecoder().decode([SubscriptionItem].self, from: data) else {
            return []
        }
        return subscriptions
    }
    
    func addSubscription(_ subscription: SubscriptionItem) {
        var subscriptions = loadSubscriptions()
        subscriptions.append(subscription)
        saveSubscriptions(subscriptions)
    }
    
    func updateSubscription(_ subscription: SubscriptionItem) {
        var subscriptions = loadSubscriptions()
        if let index = subscriptions.firstIndex(where: { $0.id == subscription.id }) {
            subscriptions[index] = subscription
            saveSubscriptions(subscriptions)
        }
    }
    
    func deleteSubscription(id: UUID) {
        var subscriptions = loadSubscriptions()
        subscriptions.removeAll { $0.id == id }
        saveSubscriptions(subscriptions)
    }
    
    // MARK: - Revenues
    
    func saveRevenues(_ revenues: [RevenueItem]) {
        if let data = try? JSONEncoder().encode(revenues) {
            UserDefaults.standard.set(data, forKey: revenuesKey)
        }
    }
    
    func loadRevenues() -> [RevenueItem] {
        guard let data = UserDefaults.standard.data(forKey: revenuesKey),
              let revenues = try? JSONDecoder().decode([RevenueItem].self, from: data) else {
            return []
        }
        return revenues
    }
    
    func addRevenue(_ revenue: RevenueItem) {
        var revenues = loadRevenues()
        revenues.append(revenue)
        saveRevenues(revenues)
    }
    
    func updateRevenue(_ revenue: RevenueItem) {
        var revenues = loadRevenues()
        if let index = revenues.firstIndex(where: { $0.id == revenue.id }) {
            revenues[index] = revenue
            saveRevenues(revenues)
        }
    }
    
    func deleteRevenue(id: UUID) {
        var revenues = loadRevenues()
        revenues.removeAll { $0.id == id }
        saveRevenues(revenues)
    }
    
    // MARK: - Clear All Data
    
    func clearAllData() {
        UserDefaults.standard.removeObject(forKey: accountsKey)
        UserDefaults.standard.removeObject(forKey: subscriptionsKey)
        UserDefaults.standard.removeObject(forKey: revenuesKey)
    }
    
    // MARK: - Sync to Cloud
    
    func syncLocalDataToCloud() async -> Bool {
        do {
            // Sync accounts
            let localAccounts = loadAccounts()
            for account in localAccounts {
                try await SupabaseService.shared.createAccount(account)
            }
            
            // Sync subscriptions
            let localSubscriptions = loadSubscriptions()
            for subscription in localSubscriptions {
                try await SupabaseService.shared.createSubscription(subscription)
            }
            
            // Sync revenues
            let localRevenues = loadRevenues()
            for revenue in localRevenues {
                try await SupabaseService.shared.createRevenue(revenue)
            }
            
            // Clear local data after successful sync
            clearAllData()
            return true
        } catch {
            print("Failed to sync local data to cloud: \(error)")
            return false
        }
    }
}
