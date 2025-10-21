
import SwiftUI

struct BalanceCard: View {
    @ObservedObject var viewModel: DashboardViewModel
    @State private var showDatePicker = false
    
    private var isToday: Bool {
        Calendar.current.isDateInToday(viewModel.selectedDate)
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: viewModel.selectedDate)
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Total Balance").font(.headline).foregroundColor(.secondary)
                Spacer()
                HStack(spacing: 8) {
                    if !isToday {
                        Button(action: {
                            Task {
                                await viewModel.resetToToday()
                            }
                        }) {
                            Text("Today")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(6)
                        }
                    }
                    Button(action: {
                        showDatePicker.toggle()
                    }) {
                        Image(systemName: "calendar")
                            .foregroundColor(.blue)
                            .font(.title2)
                    }
                }
            }
            
            HStack {
                Text(CurrencyService.shared.formatAmountInUSD(viewModel.projectedBalanceForSelectedDate))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                Spacer()
            }
            
            HStack {
                Text(isToday ? "Current balance across all accounts" : "Projected balance on \(formattedDate)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
        .sheet(isPresented: $showDatePicker) {
            NavigationView {
                VStack(spacing: 20) {
                    DatePicker(
                        "Select Date",
                        selection: Binding(
                            get: { viewModel.selectedDate },
                            set: { newDate in
                                Task {
                                    await viewModel.setSelectedDate(newDate)
                                }
                            }
                        ),
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .padding()
                    
                    Spacer()
                }
                .navigationTitle("Select Date")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            showDatePicker = false
                        }
                    }
                }
            }
        }
    }
}
