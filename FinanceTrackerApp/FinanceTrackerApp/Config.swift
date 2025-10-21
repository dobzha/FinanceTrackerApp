
import Foundation

enum Config {
    static let supabaseURL = "https://dslaholfbjctbzkgprio.supabase.co"
    static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRzbGFob2xmYmpjdGJ6a2dwcmlvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTg3MjY5MTMsImV4cCI6MjA3NDMwMjkxM30.Zl8qZ1-t9pbLSptOvXNL0AglD3O8s729gLDuW_bsD2E"

    static let exchangeRateEdgeFunction = "https://dslaholfbjctbzkgprio.supabase.co/functions/v1/get-exchange-rates"
    static let exchangeRateCacheDuration: TimeInterval = 6 * 60 * 60
}


extension Config {
    static let oauthRedirectURL = "financetracker://auth-callback"
}
