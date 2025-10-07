import SwiftUI
import PhotosUI

struct AddIncomeView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var auth: AuthViewModel

    // Form fields
    @State private var amountText = ""                 // typed amount as string
    @State private var category = "Salary"
    @State private var account  = "Bank Account"
    @State private var date: Date = Date()
    @State private var note = ""

    // Attachment
    @State private var pickerItem: PhotosPickerItem?
    @State private var receiptImage: UIImage?
    @State private var receiptData: Data?

    // UI state
    @State private var isSaving = false
    @State private var errorMessage: String?

    // Pickers
    private let categories = ["Salary", "Bonus", "Investment Return", "Gift", "Freelance"]
    private let accounts   = ["Bank Account", "Cash", "Digital Wallet"]

    // Derived month/year from date
    private var monthName: String {
        let f = DateFormatter()
        f.dateFormat = "LLLL"                // “October”
        return f.string(from: date)
    }
    private var yearNumber: Int {
        Calendar.current.component(.year, from: date)
    }

    // Validations
    private var amountValue: Double? {
        Double(amountText.replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespaces))
    }
    private var canSave: Bool {
        (amountValue ?? 0) > 0 && !category.isEmpty && !account.isEmpty
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Income Details")) {
                    TextField("Amount", text: $amountText)
                        .keyboardType(.decimalPad)

                    Picker("Category", selection: $category) {
                        ForEach(categories, id: \.self) { Text($0) }
                    }

                    Picker("Account/Wallet", selection: $account) {
                        ForEach(accounts, id: \.self) { Text($0) }
                    }

                    DatePicker("Date", selection: $date, displayedComponents: .date)

                    HStack {
                        Text("Month")
                        Spacer()
                        Text("\(monthName) \(yearNumber)").foregroundStyle(.secondary)
                    }

                    TextField("Note (optional)", text: $note, axis: .vertical)
                }

                Section(header: Text("Attachment (optional)")) {
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        HStack {
                            if let img = receiptImage {
                                Image(uiImage: img)
                                    .resizable().scaledToFill()
                                    .frame(width: 48, height: 48)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            } else {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.gray.opacity(0.12))
                                    .frame(width: 48, height: 48)
                                    .overlay(Image(systemName: "photo").foregroundStyle(.secondary))
                            }
                            Text(receiptImage == nil ? "Add receipt photo" : "Change receipt")
                                .foregroundStyle(.primary)
                            Spacer()
                        }
                    }
                    .onChange(of: pickerItem) { item in
                        Task {
                            guard let item else { return }
                            if let data = try? await item.loadTransferable(type: Data.self),
                               let ui = UIImage(data: data) {
                                receiptImage = ui
                                // Compress to keep uploads small
                                receiptData = ui.jpegData(compressionQuality: 0.8) ?? data
                            }
                        }
                    }
                }

                if let msg = errorMessage {
                    Section {
                        Text(msg).foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Add Income")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await saveIncome() }
                    } label: {
                        if isSaving { ProgressView() } else { Text("Save") }
                    }
                    .disabled(!canSave || isSaving)
                }
            }
        }
    }

    // MARK: - Save
    private func saveIncome() async {
        guard let uid = auth.user?.uid else {
            errorMessage = "Not signed in."
            return
        }
        guard let amount = amountValue, amount > 0 else {
            errorMessage = "Enter a valid amount."
            return
        }
        isSaving = true; defer { isSaving = false }

        do {
            let tx = Transaction(
                userId: uid,
                type: .income,
                amount: amount,
                category: category,
                account: account,
                note: note.isEmpty ? nil : note,
                date: date,
                month: monthName,
                year: yearNumber,
                attachmentURL: nil
            )
            try await TransactionService.shared.addTransaction(tx, receiptData: receiptData)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
