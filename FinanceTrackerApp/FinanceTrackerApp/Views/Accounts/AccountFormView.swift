
import SwiftUI

enum AccountFormMode { case create, edit }

struct AccountFormView: View {
    let mode: AccountFormMode
    var existing: FinanceItem?
    var onSave: (String, Double, String) async -> Bool

    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var amountString: String = ""
    @State private var currency: String = "USD"
    @State private var validationErrors: [String] = []

    private let currencies = ["USD", "UAH", "EUR", "GBP", "JPY", "CNY", "CAD", "AUD", "CHF"]

    var body: some View {
        Form {
            Section("Details") {
                TextField("Name", text: $name)
                HStack {
                    TextField("Amount", text: $amountString)
                        .keyboardType(.decimalPad)
                    Spacer()
                    Picker("Currency", selection: $currency) {
                        ForEach(currencies, id: \.self) { c in
                            Text(c).tag(c)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            if !validationErrors.isEmpty {
                Section {
                    ForEach(validationErrors, id: \.self) { e in
                        Text(e).foregroundColor(.red).font(.caption)
                    }
                }
            }
        }
        .navigationTitle(mode == .create ? "New Account" : "Edit Account")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { Task { await save() } }
            }
        }
        .onAppear { seedForm() }
    }

    private func seedForm() {
        if let existing = existing, mode == .edit {
            name = existing.name
            amountString = String(existing.amount)
            currency = existing.currency
        }
    }

    private func saveValidation() -> [String] {
        var errs: [String] = []
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { errs.append("Name is required") }
        let normalized = amountString.replacingOccurrences(of: ",", with: ".")
        if Double(normalized) == nil { errs.append("Amount must be a number") }
        if let val = Double(normalized), val <= 0 { errs.append("Amount must be greater than 0") }
        if currency.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { errs.append("Currency is required") }
        return errs
    }

    private func save() async {
        validationErrors = saveValidation()
        guard validationErrors.isEmpty else { return }
        let normalized = amountString.replacingOccurrences(of: ",", with: ".")
        let ok = await onSave(name, Double(normalized) ?? 0, currency)
        if ok { dismiss() }
    }
}
