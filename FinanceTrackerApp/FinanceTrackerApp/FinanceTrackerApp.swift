import SwiftUI

@main
struct FinanceTrackerApp: App {
    var body: some Scene {
        WindowGroup {
            RootEntryView()
                .onAppear { OfflineQueueService.shared.startAutoSyncObservers() }.environmentObject(AuthViewModel()).environmentObject(ToastManager())
        }
    }
}