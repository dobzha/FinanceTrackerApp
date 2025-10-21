import SwiftUI

struct RootEntryView: View {
    @EnvironmentObject var auth: AuthViewModel
    @EnvironmentObject var toast: ToastManager

    var body: some View {
        Group {
            MainAppView()
        }
        .overlay(alignment: .top) {
            if let msg = toast.message { ToastView(text: msg) }
        }
    }
}
