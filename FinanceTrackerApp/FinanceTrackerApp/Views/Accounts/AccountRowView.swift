
import SwiftUI

struct AccountRowView: View {
    let item: FinanceItem
    @State private var convertedUSD: String = "$0.00"

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(item.name)
                    .font(.headline)
                Text(item.currency)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text(plainAmount(amount: item.amount, currency: item.currency))
                    .font(.subheadline)
                Text(convertedUSD)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .task {
            let (usd, approx) = await CurrencyService.shared.convertToUSDWithFallback(amount: item.amount, fromCurrency: item.currency)
            let fmt = CurrencyService.shared.formatAmountInUSD(usd)
            convertedUSD = approx ? "~" + fmt : fmt
        }
    }

    private func plainAmount(amount: Double, currency: String) -> String {
        CurrencyService.shared.formatAmount(amount, currency: currency)
    }
}
