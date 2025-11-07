
import Foundation
import Supabase
#if os(iOS)
import UIKit
#endif

final class SupabaseService {
    static let shared = SupabaseService()

    private let client: SupabaseClient
    private let customDecoder: JSONDecoder

    private var isOnline: Bool { NetworkStatus.shared.isOnline }

    private init() {
        let url = URL(string: Config.supabaseURL)!
        client = SupabaseClient(supabaseURL: url, supabaseKey: Config.supabaseAnonKey)
        
        // Configure custom JSON decoder with flexible date parsing
        customDecoder = JSONDecoder()
        customDecoder.dateDecodingStrategy = .custom(Self.decodeFlexibleDate)
    }
    
    // MARK: - Date Decoding Helper
    
    /// Decodes dates in various formats returned by Supabase
    /// Supports: ISO8601 with microseconds, milliseconds, standard, date-only, and datetime formats
    private static func decodeFlexibleDate(from decoder: Decoder) throws -> Date {
        let container = try decoder.singleValueContainer()
        let dateString = try container.decode(String.self)
        
        // Try ISO8601 with fractional seconds (iOS 15+)
        if #available(iOS 15.0, *) {
            let iso8601 = ISO8601DateFormatter()
            iso8601.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = iso8601.date(from: dateString) {
                return date
            }
        }
        
        // Try common date formats using helper
        let formats = [
            "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZZZZZ",  // Microseconds with timezone
            "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ",     // Milliseconds with timezone
            "yyyy-MM-dd'T'HH:mm:ssZZZZZ",         // Standard with timezone
            "yyyy-MM-dd'T'HH:mm:ss'Z'",           // UTC timezone
            "yyyy-MM-dd",                          // Date only
            "yyyy-MM-dd HH:mm:ss"                  // Datetime
        ]
        
        for format in formats {
            if let date = Self.parseDate(dateString, format: format) {
                return date
            }
        }
        
        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "Cannot decode date string: \(dateString)"
        )
    }
    
    /// Helper method to parse date with a specific format
    private static func parseDate(_ dateString: String, format: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.date(from: dateString)
    }

    // MARK: - Auth

    func signInWithGoogle(redirectTo: URL? = URL(string: Config.oauthRedirectURL)) async throws {
        // For iOS, we need to open the OAuth URL in a browser
        // The Supabase client will handle the redirect back to the app
        do {
            let url = try await client.auth.getOAuthSignInURL(
                provider: .google,
                redirectTo: redirectTo
            )
            
            // Open in Safari or external browser
            // The app will receive the callback via the URL scheme defined in Info.plist
            await MainActor.run {
                #if os(iOS)
                if UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                }
                #endif
            }
        } catch {
            print("Error getting OAuth URL: \(error)")
            throw error
        }
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
        // Fetch only the current user's accounts
        // RLS policies will also enforce this on the database level
        print("🔍 [SupabaseService] Fetching accounts...")
        
        guard let user = try? await client.auth.session.user else {
            print("❌ [SupabaseService] User not authenticated")
            throw NSError(domain: "SupabaseService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not signed in. Please sign in to view your data."])
        }
        
        print("✅ [SupabaseService] User authenticated: \(user.id.uuidString)")
        
        do {
            let result: [FinanceItem] = try await client
                .from("finance_items")
                .select()
                .eq("user_id", value: user.id.uuidString)
                .order("created_at", ascending: true)
                .execute()
                .value
            
            print("✅ [SupabaseService] Fetched \(result.count) accounts successfully")
            return result
        } catch {
            print("❌ [SupabaseService] Error fetching accounts: \(error)")
            throw error
        }
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
        // Fetch only the current user's subscriptions
        print("🔍 [SupabaseService] Fetching subscriptions...")
        
        guard let user = try? await client.auth.session.user else {
            print("❌ [SupabaseService] User not authenticated")
            throw NSError(domain: "SupabaseService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not signed in. Please sign in to view your data."])
        }
        
        print("✅ [SupabaseService] User authenticated: \(user.id.uuidString)")
        
        do {
            // Use custom decoder to handle date format issues
            let response = try await client
                .from("subscription_items")
                .select()
                .eq("user_id", value: user.id.uuidString)
                .order("created_at", ascending: true)
                .execute()
            
            let result = try customDecoder.decode([SubscriptionItem].self, from: response.data)
            
            print("✅ [SupabaseService] Fetched \(result.count) subscriptions successfully")
            return result
        } catch let decodingError as DecodingError {
            print("❌ [SupabaseService] Date decoding error for subscriptions: \(decodingError)")
            throw NSError(domain: "SupabaseService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Date format error. Please check subscription dates."])
        } catch {
            print("❌ [SupabaseService] Error fetching subscriptions: \(error)")
            throw error
        }
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
        // Fetch only the current user's revenues
        print("🔍 [SupabaseService] Fetching revenues...")
        
        guard let user = try? await client.auth.session.user else {
            print("❌ [SupabaseService] User not authenticated")
            throw NSError(domain: "SupabaseService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not signed in. Please sign in to view your data."])
        }
        
        print("✅ [SupabaseService] User authenticated: \(user.id.uuidString)")
        
        do {
            // Use custom decoder to handle date format issues
            let response = try await client
                .from("revenue_items")
                .select()
                .eq("user_id", value: user.id.uuidString)
                .order("created_at", ascending: true)
                .execute()
            
            let result = try customDecoder.decode([RevenueItem].self, from: response.data)
            
            print("✅ [SupabaseService] Fetched \(result.count) revenues successfully")
            return result
        } catch let decodingError as DecodingError {
            print("❌ [SupabaseService] Date decoding error for revenues: \(decodingError)")
            throw NSError(domain: "SupabaseService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Date format error. Please check revenue dates."])
        } catch {
            print("❌ [SupabaseService] Error fetching revenues: \(error)")
            throw error
        }
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
