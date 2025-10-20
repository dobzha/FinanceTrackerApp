
import SwiftUI

struct QuickStatsView: View {
    let monthlyIncomeUSD: Double
    let monthlyExpensesUSD: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Monthly Overview").font(.headline)
                Spacer()
                Image(systemName: "chart.bar").foregroundColor(.blue)
            }
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "arrow.up.circle").foregroundColor(.green).font(.title3).frame(width: 24)
                    Text("Monthly Income").font(.subheadline)
                    Spacer()
                    Text(CurrencyService.shared.formatAmountInUSD(monthlyIncomeUSD)).font(.subheadline).foregroundColor(.green)
                }
                HStack {
                    Image(systemName: "arrow.down.circle").foregroundColor(.red).font(.title3).frame(width: 24)
                    Text("Monthly Expenses").font(.subheadline)
                    Spacer()
                    Text(CurrencyService.shared.formatAmountInUSD(monthlyExpensesUSD)).font(.subheadline).foregroundColor(.red)
                }
                Divider()
                HStack {
                    Image(systemName: "plus.circle").foregroundColor(net >= 0 ? .green : .red).font(.title3).frame(width: 24)
                    Text("Net Change").font(.subheadline).fontWeight(.semibold)
                    Spacer()
                    Text(CurrencyService.shared.formatAmountInUSD(net)).font(.subheadline).fontWeight(.bold).foregroundColor(net >= 0 ? .green : .red)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
    }

    private var net: Double { monthlyIncomeUSD - monthlyExpensesUSD }
}
