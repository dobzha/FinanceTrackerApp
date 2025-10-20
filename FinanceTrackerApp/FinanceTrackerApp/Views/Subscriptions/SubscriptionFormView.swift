
import SwiftUI

struct SubscriptionFormView: View {
    let accounts: [FinanceItem]
    let mode: AccountFormMode
    var existing: SubscriptionItem?
    var onSave: (String, Double, String, SubscriptionPeriod, Date, UUID?) async -> Bool

    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var amountString: String = ""
    @State private var currency: String = "USD"
    @State private var period: SubscriptionPeriod = .monthly
    @State private var repetitionDate: Date = Date()
    @State private var accountId: UUID? = nil
    @State private var validationErrors: [String] = []

    var body: some View {
        Form {
            Section("Details") {
                TextField("Name", text: $name)
                HStack {
                    TextField("Amount", text: $amountString).keyboardType(.decimalPad)
                    Spacer()
                    Picker("Currency", selection: $currency) {
                        ForEach(["USD","UAH","EUR","GBP","JPY","CNY"], id: \.self) { c in Text(c).tag(c) }
                    }.pickerStyle(.menu)
                }
                Picker("Period", selection: $period) {
                    ForEach(SubscriptionPeriod.allCases, id: \.self) { p in Text(p.rawValue.capitalized).tag(p) }
                }
                DatePicker("Repetition Date", selection: $repetitionDate, displayedComponents: .date)
                Picker("Account", selection: Binding(get: { accountId ?? UUID(uuidString: "00000000-0000-0000-0000-000000000000") }, set: { v in accountId = v })) {
                    Text("No account").tag(UUID(uuidString: "00000000-0000-0000-0000-000000000000")!)
                    ForEach(accounts, id: \.id) { acc in Text(acc.name).tag(acc.id) }
                }
            }
            if !validationErrors.isEmpty {
                Section { ForEach(validationErrors, id: \.self) { Text($0).foregroundColor(.red).font(.caption) } }
            }
        }
        .navigationTitle(mode == .create ? "New Subscription" : "Edit Subscription")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("Save") { Task { await save() } } }
        }
        .onAppear { seed() }
    }

    private func seed() {
        if let e = existing, mode == .edit {
            name = e.name; amountString = String(e.amount); currency = e.currency; period = e.period; repetitionDate = e.repetitionDate; accountId = e.accountId
        }
    }

    private func validate() -> [String] {
        var errs: [String] = []
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { errs.append("Name is required") }
        let normalized = amountString.replacingOccurrences(of: ",", with: ".")
        if Double(normalized) == nil { errs.append("Amount must be a number") }
        if let val = Double(normalized), val <= 0 { errs.append("Amount must be greater than 0") }
        if currency.isEmpty { errs.append("Currency is required") }
        return errs
    }

    private func save() async {
        validationErrors = validate()
        guard validationErrors.isEmpty else { return }
        let normalized = amountString.replacingOccurrences(of: ",", with: ".")
        let idToSend = (accountId == UUID(uuidString: "00000000-0000-0000-0000-000000000000")) ? nil : accountId
        let ok = await onSave(name, Double(normalized) ?? 0, currency, period, repetitionDate, idToSend)
        if ok { dismiss() }
    }
}
