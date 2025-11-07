
import SwiftUI

struct RevenueScreen: View {
    @EnvironmentObject var toast: ToastManager
    @StateObject private var viewModel = RevenueViewModel()
    @State private var showForm = false
    @State private var editing: RevenueItem? = nil
    @State private var monthlyRevenueUSD: Double = 0.0

    var body: some View {
        NavigationView {
            Group {
                if viewModel.isLoading {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.revenues.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "dollarsign.circle").font(.system(size: 56)).foregroundColor(.secondary)
                        Text("No Revenue Yet").font(.title2).fontWeight(.semibold)
                        Text("Add income sources to track revenue").font(.subheadline).foregroundColor(.secondary)
                        Button("Add Revenue") { showForm = true }.buttonStyle(.borderedProminent)
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(viewModel.revenues, id: \.id) { r in
                            RevenueRowView(item: r, accountName: viewModel.accounts.first(where: { $0.id == r.accountId })?.name)
                                .swipeActions(edge: .leading) { Button { editing = r; showForm = true } label: { Label("Edit", systemImage: "pencil") }.tint(.blue) }
                                .swipeActions(edge: .trailing) { Button(role: .destructive) { Task { if await viewModel.delete(id: r.id) { toast.show("Revenue deleted"); await calculateMonthlyRevenue() } } } label: { Label("Delete", systemImage: "trash") } }
                        }
                    }
                    .refreshable { 
                        await viewModel.load()
                        await calculateMonthlyRevenue()
                    }
                }
            }
            .navigationTitle("Revenue")
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button { editing = nil; showForm = true } label: { Image(systemName: "plus") } } }
            .safeAreaInset(edge: .top) {
                if !viewModel.revenues.isEmpty {
                    VStack(spacing: 8) {
                        HStack {
                            Text("Monthly Revenue")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(CurrencyService.shared.formatAmountInUSD(monthlyRevenueUSD))
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(.green)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(Color(.systemBackground))
                        
                        Divider()
                    }
                }
            }
        }
        .task { 
            await viewModel.load()
            await calculateMonthlyRevenue()
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("AccountUpdated"))) { _ in
            Task { 
                await viewModel.load()
                await calculateMonthlyRevenue()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("DataRefreshNeeded"))) { _ in
            Task { 
                await viewModel.load()
                await calculateMonthlyRevenue()
            }
        }
        .sheet(isPresented: $showForm) {
            NavigationStack {
                RevenueFormView(accounts: viewModel.accounts, mode: editing == nil ? .create : .edit, existing: editing) { name, amount, currency, period, date, accountId in
                    if var e = editing {
                        e.name = name; e.amount = amount; e.currency = currency; e.period = period; e.repetitionDate = date; e.accountId = accountId
                        let ok = await viewModel.update(e)
                        if ok { 
                            toast.show("Revenue updated")
                            await calculateMonthlyRevenue()
                        }
                        return ok
                    } else {
                        let ok = await viewModel.create(name: name, amount: amount, currency: currency, period: period, repetitionDate: date, accountId: accountId)
                        if ok { 
                            toast.show("Revenue created")
                            await calculateMonthlyRevenue()
                        }
                        return ok
                    }
                }
            }
        }
    }
    
    private func calculateMonthlyRevenue() async {
        let total = await FinancialCalculations.calculateMonthlyRevenue(viewModel.revenues)
        await MainActor.run {
            monthlyRevenueUSD = total
        }
    }
}

#Preview { RevenueScreen() }
