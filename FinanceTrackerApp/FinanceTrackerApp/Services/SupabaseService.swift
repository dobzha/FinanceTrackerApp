
import Foundation
import Supabase

final class SupabaseService {
    static let shared = SupabaseService()

    private let client: SupabaseClient

    private var isOnline: Bool { NetworkStatus.shared.isOnline }

    private init() {
        let url = URL(string: Config.supabaseURL)!
        client = SupabaseClient(supabaseURL: url, supabaseKey: Config.supabaseAnonKey)
    }

    // MARK: - Auth

    func signInWithGoogle(redirectTo: URL? = nil) async throws {
        _ = try await client.auth.signInWithOAuth(provider: .google, redirectTo: redirectTo)
    }

    func signOut() async throws {
        try await client.auth.signOut()
    }

    func getCurrentUser() async throws -> User? {
        return try await client.auth.session.user
    }

    func observeAuthState(_ handler: @escaping (AuthChangeEvent, Session?) -> Void) -> UUID {
        client.auth.addAuthStateChangeListener { event, session in
            handler(event, session)
        }
    }

    func removeAuthObserver(_ token: UUID) {
        client.auth.removeAuthStateChangeListener(token)
    }

    // MARK: - Finance Items (Accounts)

    func fetchAccounts() async throws -> [FinanceItem] {
        try await client.database.from("finance_items").select().order(column: "created_at", ascending: true).execute().value
    }

    func createAccount(_ item: FinanceItem) async throws {
        if isOnline {
            _ = try await client.database.from("finance_items").insert(values: item).execute()
        } else {
            OfflineQueueService.shared.enqueueCreate(item)
        }
    }

    func updateAccount(_ item: FinanceItem) async throws {
        if isOnline {
            _ = try await client.database.from("finance_items").update(values: item).eq(column: "id", value: item.id.uuidString).execute()
        } else {
            OfflineQueueService.shared.enqueueUpdate(item)
        }
    }

    func deleteAccount(id: UUID) async throws {
        if isOnline {
            _ = try await client.database.from("finance_items").delete().eq(column: "id", value: id.uuidString).execute()
        } else {
            OfflineQueueService.shared.enqueueDeleteFinance(id: id)
        }
    }

    // MARK: - Subscription Items

    func fetchSubscriptions() async throws -> [SubscriptionItem] {
        try await client.database.from("subscription_items").select().order(column: "created_at", ascending: true).execute().value
    }

    func createSubscription(_ item: SubscriptionItem) async throws {
        if isOnline {
            _ = try await client.database.from("subscription_items").insert(values: item).execute()
        } else {
            OfflineQueueService.shared.enqueueCreate(item)
        }
    }

    func updateSubscription(_ item: SubscriptionItem) async throws {
        if isOnline {
            _ = try await client.database.from("subscription_items").update(values: item).eq(column: "id", value: item.id.uuidString).execute()
        } else {
            OfflineQueueService.shared.enqueueUpdate(item)
        }
    }

    func deleteSubscription(id: UUID) async throws {
        if isOnline {
            _ = try await client.database.from("subscription_items").delete().eq(column: "id", value: id.uuidString).execute()
        } else {
            OfflineQueueService.shared.enqueueDeleteSubscription(id: id)
        }
    }

    // MARK: - Revenue Items

    func fetchRevenues() async throws -> [RevenueItem] {
        try await client.database.from("revenue_items").select().order(column: "created_at", ascending: true).execute().value
    }

    func createRevenue(_ item: RevenueItem) async throws {
        if isOnline {
            _ = try await client.database.from("revenue_items").insert(values: item).execute()
        } else {
            OfflineQueueService.shared.enqueueCreate(item)
        }
    }

    func updateRevenue(_ item: RevenueItem) async throws {
        if isOnline {
            _ = try await client.database.from("revenue_items").update(values: item).eq(column: "id", value: item.id.uuidString).execute()
        } else {
            OfflineQueueService.shared.enqueueUpdate(item)
        }
    }

    func deleteRevenue(id: UUID) async throws {
        if isOnline {
            _ = try await client.database.from("revenue_items").delete().eq(column: "id", value: id.uuidString).execute()
        } else {
            OfflineQueueService.shared.enqueueDeleteRevenue(id: id)
        }
    }
}
