
import SwiftUI

struct SubscriptionsScreen: View {
    @EnvironmentObject var toast: ToastManager
    @StateObject private var viewModel = SubscriptionsViewModel()
    @State private var editing: SubscriptionItem? = nil
    @State private var showCreateForm = false
    @State private var monthlyExpensesUSD: Double = 0.0

    var body: some View {
        NavigationStack {
            contentView
                .navigationTitle("Subscriptions")
                .navigationBarTitleDisplayMode(.large)
                .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button { showCreateForm = true } label: { Image(systemName: "plus") } } }
                .safeAreaInset(edge: .top) {
                    if !viewModel.subscriptions.isEmpty {
                        VStack(spacing: 8) {
                            HStack {
                                Text("Monthly Expenses")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(CurrencyService.shared.formatAmountInUSD(monthlyExpensesUSD))
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundColor(.red)
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
            await calculateMonthlyExpenses()
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("AccountUpdated"))) { _ in
            Task { 
                await viewModel.load()
                await calculateMonthlyExpenses()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("DataRefreshNeeded"))) { _ in
            Task { 
                await viewModel.load()
                await calculateMonthlyExpenses()
            }
        }
        .alert("Error Loading Data", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        ), presenting: viewModel.errorMessage) { errorMsg in
            Button("OK") { viewModel.errorMessage = nil }
            Button("Retry") { 
                Task {
                    await viewModel.load()
                    await calculateMonthlyExpenses()
                }
            }
        } message: { errorMsg in
            Text(errorMsg)
        }
        .sheet(item: $editing) { item in
            NavigationStack {
                SubscriptionFormView(accounts: viewModel.accounts, mode: .edit, existing: item) { name, amount, currency, period, date, accountId in
                    var updated = item
                    updated.name = name
                    updated.amount = amount
                    updated.currency = currency
                    updated.period = period
                    updated.repetitionDate = date
                    updated.accountId = accountId
                    let ok = await viewModel.update(updated)
                    if ok { 
                        toast.show("Subscription updated")
                        await calculateMonthlyExpenses()
                    }
                    return ok
                }
            }
        }
        .sheet(isPresented: $showCreateForm) {
            NavigationStack {
                SubscriptionFormView(accounts: viewModel.accounts, mode: .create, existing: nil) { name, amount, currency, period, date, accountId in
                    let ok = await viewModel.create(name: name, amount: amount, currency: currency, period: period, repetitionDate: date, accountId: accountId)
                    if ok { 
                        toast.show("Subscription created")
                        await calculateMonthlyExpenses()
                    }
                    return ok
                }
            }
        }
    }
    
    private func calculateMonthlyExpenses() async {
        let total = await FinancialCalculations.calculateMonthlySubscriptions(viewModel.subscriptions)
        await MainActor.run {
            monthlyExpensesUSD = total
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        if viewModel.isLoading {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.subscriptions.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "repeat").font(.system(size: 56)).foregroundColor(.secondary)
                Text("No Subscriptions Yet").font(.title2).fontWeight(.semibold)
                Text("Add your subscriptions to track recurring expenses").font(.subheadline).foregroundColor(.secondary)
                Button("Add Subscription") { showCreateForm = true }.buttonStyle(.borderedProminent)
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                ForEach(viewModel.subscriptions, id: \.id) { s in
                    SubscriptionRowView(item: s, accountName: viewModel.accounts.first(where: { $0.id == s.accountId })?.name) {
                        editing = s
                    }
                    .swipeActions(edge: .leading) { Button { editing = s } label: { Label("Edit", systemImage: "pencil") }.tint(.blue) }
                    .swipeActions(edge: .trailing) { Button(role: .destructive) { Task { if await viewModel.delete(id: s.id) { toast.show("Subscription deleted"); await calculateMonthlyExpenses() } } } label: { Label("Delete", systemImage: "trash") } }
                }
            }
            .id("subscriptionsList")
            .refreshable { 
                await viewModel.load()
                await calculateMonthlyExpenses()
            }
        }
    }
}

#Preview { SubscriptionsScreen() }
