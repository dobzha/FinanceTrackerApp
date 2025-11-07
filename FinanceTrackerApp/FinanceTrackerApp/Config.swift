
import Foundation

enum Config {
    // MARK: - Supabase Configuration
    static let supabaseURL = "https://dslaholfbjctbzkgprio.supabase.co"
    static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRzbGFob2xmYmpjdGJ6a2dwcmlvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTg3MjY5MTMsImV4cCI6MjA3NDMwMjkxM30.Zl8qZ1-t9pbLSptOvXNL0AglD3O8s729gLDuW_bsD2E"

    // MARK: - Exchange Rate Configuration
    static let exchangeRateEdgeFunction = "https://dslaholfbjctbzkgprio.supabase.co/functions/v1/get-exchange-rates"
    static let exchangeRateCacheDuration: TimeInterval = 6 * 60 * 60
    
    // MARK: - Google OAuth Configuration
    static let googleClientID = "814400290575-jhrhi3p719dp3mvibl3amnkfbo809ddp.apps.googleusercontent.com"
    static let googleReversedClientID = "com.googleusercontent.apps.814400290575-jhrhi3p719dp3mvibl3amnkfbo809ddp"
}


extension Config {
    // MARK: - OAuth Redirect URL
    static let oauthRedirectURL = "financetracker://auth-callback"
}
