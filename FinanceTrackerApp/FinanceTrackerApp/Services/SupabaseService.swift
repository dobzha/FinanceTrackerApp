
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

    func signInWithGoogle(redirectTo: URL? = URL(string: Config.oauthRedirectURL)) async throws {
        _ = try await client.auth.signInWithOAuth(provider: .google, redirectTo: redirectTo)
    }

    func signOut() async throws {
        try await client.auth.signOut()
    }

    func getCurrentUser() async -> User? {
        do {
            let session = try await client.auth.session
            return session.user
        } catch {
            return nil
        }
    }

    // MARK: - Finance Items (Accounts)

    func fetchAccounts() async throws -> [FinanceItem] {
        try await client.from("finance_items").select().order("created_at", ascending: true).execute().value
    }

    func createAccount(_ item: FinanceItem) async throws {
        if isOnline {
            _ = try await client.from("finance_items").insert(item).execute()
        } else {
            OfflineQueueService.shared.enqueueCreate(item)
        }
    }

    func updateAccount(_ item: FinanceItem) async throws {
        if isOnline {
            _ = try await client.from("finance_items").update(item).eq("id", value: item.id.uuidString).execute()
        } else {
            OfflineQueueService.shared.enqueueUpdate(item)
        }
    }

    func deleteAccount(id: UUID) async throws {
        if isOnline {
            _ = try await client.from("finance_items").delete().eq("id", value: id.uuidString).execute()
        } else {
            OfflineQueueService.shared.enqueueDeleteFinance(id: id)
        }
    }

    // MARK: - Subscription Items

    func fetchSubscriptions() async throws -> [SubscriptionItem] {
        try await client.from("subscription_items").select().order("created_at", ascending: true).execute().value
    }

    func createSubscription(_ item: SubscriptionItem) async throws {
        if isOnline {
            _ = try await client.from("subscription_items").insert(item).execute()
        } else {
            OfflineQueueService.shared.enqueueCreate(item)
        }
    }

    func updateSubscription(_ item: SubscriptionItem) async throws {
        if isOnline {
            _ = try await client.from("subscription_items").update(item).eq("id", value: item.id.uuidString).execute()
        } else {
            OfflineQueueService.shared.enqueueUpdate(item)
        }
    }

    func deleteSubscription(id: UUID) async throws {
        if isOnline {
            _ = try await client.from("subscription_items").delete().eq("id", value: id.uuidString).execute()
        } else {
            OfflineQueueService.shared.enqueueDeleteSubscription(id: id)
        }
    }

    // MARK: - Revenue Items

    func fetchRevenues() async throws -> [RevenueItem] {
        try await client.from("revenue_items").select().order("created_at", ascending: true).execute().value
    }

    func createRevenue(_ item: RevenueItem) async throws {
        if isOnline {
            _ = try await client.from("revenue_items").insert(item).execute()
        } else {
            OfflineQueueService.shared.enqueueCreate(item)
        }
    }

    func updateRevenue(_ item: RevenueItem) async throws {
        if isOnline {
            _ = try await client.from("revenue_items").update(item).eq("id", value: item.id.uuidString).execute()
        } else {
            OfflineQueueService.shared.enqueueUpdate(item)
        }
    }

    func deleteRevenue(id: UUID) async throws {
        if isOnline {
            _ = try await client.from("revenue_items").delete().eq("id", value: id.uuidString).execute()
        } else {
            OfflineQueueService.shared.enqueueDeleteRevenue(id: id)
        }
    }

    func handleOpenURL(_ url: URL) async {
        do {
            _ = try await client.auth.session(from: url)
        } catch {
            // ignore; user can retry sign-in
        }
    }
}
