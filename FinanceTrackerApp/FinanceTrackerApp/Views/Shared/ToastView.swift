
import SwiftUI

struct ToastView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.subheadline)
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.8))
            .cornerRadius(12)
            .padding(.top, 12)
    }
}
