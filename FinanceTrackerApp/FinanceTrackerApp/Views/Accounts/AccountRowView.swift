
import SwiftUI

struct AccountRowView: View {
    let item: FinanceItem
    var onTap: (() -> Void)? = nil
    @State private var convertedUSD: String = "$0.00"

    var body: some View {
        Button(action: {
            onTap?()
        }) {
            HStack {
                VStack(alignment: .leading) {
                    Text(item.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(item.currency)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text(plainAmount(amount: item.amount, currency: item.currency))
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    Text(convertedUSD)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
