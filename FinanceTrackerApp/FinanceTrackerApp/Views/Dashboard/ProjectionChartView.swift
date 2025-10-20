
import SwiftUI
import Charts

struct ProjectionChartView: View {
    let points: [(month: Date, balance: Double)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("12-Month Projection").font(.headline)
                Spacer()
                Image(systemName: "chart.line.uptrend.xyaxis").foregroundColor(.blue)
            }
            if points.isEmpty {
                Text("No data yet. Add subscriptions and revenue.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Chart(points, id: \.month) { p in
                    LineMark(
                        x: .value("Month", p.month),
                        y: .value("Balance", p.balance)
                    )
                }
                .frame(height: 220)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
    }
}
