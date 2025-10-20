
import SwiftUI

struct SignInView: View {
    @EnvironmentObject private var viewModel: AuthViewModel

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 48, weight: .bold))
                Text("Finance Tracker")
                    .font(.title2)
                    .fontWeight(.semibold)
            }

            if let error = viewModel.errorMessage, !error.isEmpty {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Button(action: { Task { await viewModel.signInWithGoogle() } }) {
                HStack {
                    Image(systemName: "g.circle")
                    Text(viewModel.isLoading ? "Signing in..." : "Sign in with Google")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(viewModel.isLoading)
            .padding(.horizontal)

            Spacer()
        }
        .padding(.top, 64)
    }
}

#Preview {
    SignInView()
}
