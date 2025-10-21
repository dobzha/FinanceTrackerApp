
import SwiftUI

struct DashboardScreen: View {
    @StateObject private var viewModel = DashboardViewModel()
    @EnvironmentObject var auth: AuthViewModel
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    if !auth.isAuthenticated {
                        VStack(spacing: 12) {
                            HStack {
                                Text("You are not signed in")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                            Button { Task { await auth.signInWithGoogle() } } label: {
                                HStack { Image(systemName: "g.circle"); Text(auth.isLoading ? "Signing in..." : "Sign in with Google").fontWeight(.semibold) }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
                    }
                    
                    // Always show balance and stats, regardless of authentication status
                    BalanceCard(viewModel: viewModel)
                    QuickStatsView(monthlyIncomeUSD: viewModel.monthlyRevenueUSD, monthlyExpensesUSD: viewModel.monthlySubscriptionsUSD)
                }
                .padding()
            }
            .navigationTitle("Dashboard")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if auth.isAuthenticated {
                        Button("Sign Out") { Task { await auth.signOut() } }
                    } else {
                        Button("Sign In") { Task { await auth.signInWithGoogle() } }
                    }
                }
            }
        }
        .overlay {
            if viewModel.isLoading { ProgressView().scaleEffect(1.2) }
        }
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
        .onReceive(NotificationCenter.default.publisher(for: .init("AccountUpdated"))) { _ in
            Task { await viewModel.load() }
        }
    }
}
