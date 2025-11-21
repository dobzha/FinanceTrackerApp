
import SwiftUI

struct AccountsScreen: View {
    @EnvironmentObject var toast: ToastManager
    @EnvironmentObject var auth: AuthViewModel
    @StateObject private var viewModel = AccountsViewModel()

    @State private var editingItem: FinanceItem? = nil
    @State private var showCreateForm = false
    @State private var showDeleteAlert = false
    @State private var deleteTarget: FinanceItem? = nil
    @State private var linkedText: String = ""
    @State private var totalBalanceUSD: Double = 0.0

    var body: some View {
        NavigationStack {
            contentView
                .navigationTitle("Accounts")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button { showCreateForm = true } label: { Image(systemName: "plus") }
                    }
                }
                .safeAreaInset(edge: .top) {
                    if !viewModel.accounts.isEmpty {
                        VStack(spacing: 8) {
                            HStack {
                                Text("Total Balance")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(CurrencyService.shared.formatAmountInUSD(totalBalanceUSD))
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)
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
            await viewModel.loadAccounts()
            await calculateTotalBalance()
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("AccountUpdated"))) { _ in
            Task { 
                await viewModel.loadAccounts()
                await calculateTotalBalance()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("DataRefreshNeeded"))) { _ in
            Task { 
                await viewModel.loadAccounts()
                await calculateTotalBalance()
            }
        }
        .alert("Error Loading Data", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        ), presenting: viewModel.errorMessage) { errorMsg in
            Button("OK") { viewModel.errorMessage = nil }
            Button("Retry") { 
                Task {
                    await viewModel.loadAccounts()
                    await calculateTotalBalance()
                }
            }
        } message: { errorMsg in
            Text(errorMsg)
        }
        .sheet(item: $editingItem) { item in
            NavigationStack {
                AccountFormView(
                    mode: .edit,
                    existing: item,
                    onSave: { name, amount, currency in
                        var updated = item
                        updated.name = name
                        updated.amount = amount
                        updated.currency = currency
                        let ok = await viewModel.updateAccount(updated)
                        if ok { 
                            toast.show("Account updated")
                            await calculateTotalBalance()
                        }
                        return ok
                    }
                )
            }
        }
        .sheet(isPresented: $showCreateForm) {
            NavigationStack {
                AccountFormView(
                    mode: .create,
                    existing: nil,
                    onSave: { name, amount, currency in
                        let ok = await viewModel.createAccount(name: name, amount: amount, currency: currency)
                        if ok { 
                            toast.show("Account created")
                            await calculateTotalBalance()
                        }
                        return ok
                    }
                )
            }
        }
        .alert("Delete \(deleteTarget?.name ?? "Account")?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { Task { await deleteConfirmed() } }
        } message: {
            Text(linkedText)
        }
    }

    private func confirmDelete(_ item: FinanceItem) {
        deleteTarget = item
        Task {
            let counts = await viewModel.linkedCounts(for: item.id)
            await MainActor.run {
                linkedText = counts.subscriptions + counts.revenues > 0 ? "\(counts.subscriptions) subscriptions and \(counts.revenues) revenue items will be unlinked" : "This item will be deleted"
                showDeleteAlert = true
            }
        }
    }

    private func deleteConfirmed() async {
        guard let target = deleteTarget else { return }
        if await viewModel.deleteAccount(target) { 
            toast.show("Account deleted")
            await calculateTotalBalance()
        }
    }
    
    private func calculateTotalBalance() async {
        let total = await FinancialCalculations.calculateCurrentAccountBalance(accounts: viewModel.accounts)
        await MainActor.run {
            totalBalanceUSD = total
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        if viewModel.isLoading {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.accounts.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "wallet.pass").font(.system(size: 56)).foregroundColor(.secondary)
                Text("No Accounts Yet").font(.title2).fontWeight(.semibold)
                Text("Start by adding your financial accounts.").font(.subheadline).foregroundColor(.secondary)
                Button("Add Account") { showCreateForm = true }.buttonStyle(.borderedProminent)
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                ForEach(viewModel.accounts, id: \.id) { item in
                    AccountRowView(item: item) {
                        editingItem = item
                    }
                    .swipeActions(edge: .leading) {
                        Button { editingItem = item } label: { Label("Edit", systemImage: "pencil") }
                            .tint(.blue)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) { confirmDelete(item) } label: { Label("Delete", systemImage: "trash") }
                    }
                }
            }
            .id("accountsList")
            .refreshable { 
                await viewModel.loadAccounts()
                await calculateTotalBalance()
            }
        }
    }
}

#Preview { AccountsScreen() }
