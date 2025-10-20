
import SwiftUI

struct SubscriptionsScreen: View {
    @EnvironmentObject var toast: ToastManager
    @StateObject private var viewModel = SubscriptionsViewModel()
    @State private var showForm = false
    @State private var editing: SubscriptionItem? = nil

    var body: some View {
        NavigationView {
            Group {
                if viewModel.isLoading {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.subscriptions.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "repeat").font(.system(size: 56)).foregroundColor(.secondary)
                        Text("No Subscriptions Yet").font(.title2).fontWeight(.semibold)
                        Text("Add your subscriptions to track recurring expenses").font(.subheadline).foregroundColor(.secondary)
                        Button("Add Subscription") { showForm = true }.buttonStyle(.borderedProminent)
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(viewModel.subscriptions, id: \.id) { s in
                            SubscriptionRowView(item: s, accountName: viewModel.accounts.first(where: { $0.id == s.accountId })?.name)
                                .swipeActions(edge: .leading) { Button { editing = s; showForm = true } label: { Label("Edit", systemImage: "pencil") }.tint(.blue) }
                                .swipeActions(edge: .trailing) { Button(role: .destructive) { Task { if await viewModel.delete(id: s.id) { toast.show("Subscription deleted") } } } label: { Label("Delete", systemImage: "trash") } }
                        }
                    }
                    .refreshable { await viewModel.load() }
                }
            }
            .navigationTitle("Subscriptions")
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button { editing = nil; showForm = true } label: { Image(systemName: "plus") } } }
        }
        .task { await viewModel.load() }
        .sheet(isPresented: $showForm) {
            NavigationStack {
                SubscriptionFormView(accounts: viewModel.accounts, mode: editing == nil ? .create : .edit, existing: editing) { name, amount, currency, period, date, accountId in
                    if var e = editing {
                        e.name = name; e.amount = amount; e.currency = currency; e.period = period; e.repetitionDate = date; e.accountId = accountId
                        let ok = await viewModel.update(e); if ok { toast.show("Subscription updated") }; return ok
                    } else {
                        let ok = await viewModel.create(name: name, amount: amount, currency: currency, period: period, repetitionDate: date, accountId: accountId); if ok { toast.show("Subscription created") }; return ok
                    }
                }
            }
        }
    }
}

#Preview { SubscriptionsScreen() }
