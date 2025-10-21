import SwiftUI

@main
struct FinanceTrackerApp: App {
    var body: some Scene {
        WindowGroup {
            RootEntryView()
                .onAppear { OfflineQueueService.shared.startAutoSyncObservers() }.onOpenURL { url in
                Task { await SupabaseService.shared.handleOpenURL(url) }
            }.environmentObject(AuthViewModel.shared).environmentObject(ToastManager())
        }
    }
}