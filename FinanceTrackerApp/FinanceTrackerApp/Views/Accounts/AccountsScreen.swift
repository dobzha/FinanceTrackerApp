
import SwiftUI

struct AccountsScreen: View {
    @EnvironmentObject var toast: ToastManager
    @StateObject private var viewModel = AccountsViewModel()

    @State private var showForm = false
    @State private var editingItem: FinanceItem? = nil
    @State private var showDeleteAlert = false
    @State private var deleteTarget: FinanceItem? = nil
    @State private var linkedText: String = ""

    var body: some View {
        NavigationView {
            Group {
                if viewModel.isLoading {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.accounts.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "wallet.pass").font(.system(size: 56)).foregroundColor(.secondary)
                        Text("No Accounts Yet").font(.title2).fontWeight(.semibold)
                        Text("Start by adding your financial accounts.").font(.subheadline).foregroundColor(.secondary)
                        Button("Add Account") { showForm = true }.buttonStyle(.borderedProminent)
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(viewModel.accounts, id: \.id) { item in
                            AccountRowView(item: item)
                                .swipeActions(edge: .leading) {
                                    Button { editingItem = item; showForm = true } label: { Label("Edit", systemImage: "pencil") }
                                        .tint(.blue)
                                }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) { confirmDelete(item) } label: { Label("Delete", systemImage: "trash") }
                                }
                        }
                    }
                    .refreshable { await viewModel.loadAccounts() }
                }
            }
            .navigationTitle("Accounts")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { editingItem = nil; showForm = true } label: { Image(systemName: "plus") }
                }
            }
        }
        .task { await viewModel.loadAccounts() }
        .sheet(isPresented: $showForm) {
            NavigationStack {
                AccountFormView(
                    mode: editingItem == nil ? .create : .edit,
                    existing: editingItem,
                    onSave: { name, amount, currency in
                        if var editing = editingItem {
                            editing.name = name
                            editing.amount = amount
                            editing.currency = currency
                            let ok = await viewModel.updateAccount(editing); if ok { toast.show("Account updated") }; return ok
                        } else {
                            let ok = await viewModel.createAccount(name: name, amount: amount, currency: currency); if ok { toast.show("Account created") }; return ok
                        }
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
        if await viewModel.deleteAccount(target) { toast.show("Account deleted") }
    }
}

#Preview { AccountsScreen() }
