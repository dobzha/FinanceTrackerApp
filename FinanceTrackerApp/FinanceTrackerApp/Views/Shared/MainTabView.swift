import SwiftUI

struct RootEntryView: View {
    @EnvironmentObject var auth: AuthViewModel
    @EnvironmentObject var toast: ToastManager

    var body: some View {
        Group {
            if auth.isAuthenticated {
                MainAppView()
            } else {
                SignInView()
            }
        }
        .overlay(alignment: .top) {
            if let msg = toast.message { ToastView(text: msg) }
        }
    }
}
