
import SwiftUI
import Charts

struct DashboardScreen: View {
    @StateObject private var viewModel = DashboardViewModel()

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    BalanceCard(totalUSD: viewModel.totalBalanceUSD)
                    ProjectionChartView(points: viewModel.projections)
                    QuickStatsView(monthlyIncomeUSD: viewModel.monthlyRevenueUSD, monthlyExpensesUSD: viewModel.monthlySubscriptionsUSD)
                }
                .padding()
            }
            .navigationTitle("Dashboard")
        }
        .overlay {
            if viewModel.isLoading { ProgressView().scaleEffect(1.2) }
        }
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }
}
