
import SwiftUI

struct RevenueRowView: View {
    let item: RevenueItem
    let accountName: String?
    var onTap: (() -> Void)? = nil
    @State private var nextDateText: String = ""
    @State private var usdText: String = "$0.00"

    var body: some View {
        Button(action: {
            onTap?()
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name).font(.headline)
                        .foregroundColor(.primary)
                    HStack(spacing: 8) {
                        Text(item.period.rawValue.capitalized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        if let accountName { Text(accountName).font(.caption).foregroundColor(.secondary) }
                    }
                    if !nextDateText.isEmpty { Text(nextDateText).font(.caption2).foregroundColor(.secondary) }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(CurrencyService.shared.formatAmount(item.amount, currency: item.currency))
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    Text(usdText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .task {
            if let rep = item.repetitionDate {
                let next: Date?
                switch item.period {
                case .monthly: next = DateCalculations.getNextMonthlyPayment(repetitionDate: rep)
                case .yearly: next = DateCalculations.getNextYearlyPayment(repetitionDate: rep)
                case .once: next = DateCalculations.getNextRevenueDate(repetitionDate: rep, period: "once")
                case .weekly:
                    next = DateCalculations.getNextWeeklyPayment(repetitionDate: rep)
                }
                if let n = next { nextDateText = DateCalculations.formatPaymentDate(n) } else { nextDateText = "" }
            }
            let (usd, approx) = await CurrencyService.shared.convertToUSDWithFallback(amount: item.amount, fromCurrency: item.currency)
            let fmt = CurrencyService.shared.formatAmountInUSD(usd)
            usdText = approx ? "~" + fmt : fmt
        }
    }
}
