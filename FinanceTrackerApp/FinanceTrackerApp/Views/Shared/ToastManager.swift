
import Foundation
import SwiftUI

final class ToastManager: ObservableObject {
    @Published var message: String? = nil

    func show(_ text: String) {
        message = text
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation { self.message = nil }
        }
    }
}
