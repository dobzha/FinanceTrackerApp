
import SwiftUI

struct BalanceCard: View {
    let totalUSD: Double

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Total Balance").font(.headline).foregroundColor(.secondary)
                Spacer()
                Image(systemName: "wallet.pass").foregroundColor(.blue).font(.title2)
            }
            HStack {
                Text(CurrencyService.shared.formatAmountInUSD(totalUSD))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                Spacer()
            }
            HStack {
                Text("Across all accounts").font(.caption).foregroundColor(.secondary)
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
    }
}
