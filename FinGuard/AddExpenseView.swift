import SwiftUI
import PhotosUI   // for optional receipt image
import FirebaseAuth

struct AddExpenseView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var auth: AuthViewModel

    // MARK: - Form state
    @State private var amountText: String = ""
    @State private var date: Date = Date()
    @State private var category: String = "Food"
    @State private var account: String = "Cash"
    @State private var note: String = ""

    // Month & Year controls (user can override the date’s month/year if needed)
    @State private var monthIndex: Int = Calendar.current.component(.month, from: Date()) - 1
    @State private var yearNumber: Int  = Calendar.current.component(.year, from: Date())

    // Receipt (optional)
    @State private var selectedItem: PhotosPickerItem?
    @State private var receiptPreview: UIImage?
    @State private var receiptData: Data?

    // UI state
    @State private var isSaving = false
    @State private var errorMessage: String?

    // MARK: - Static choices
    private let categories = ["Food", "Travel", "Shopping", "Bills", "Entertainment", "Health", "Other"]
    private let accounts   = ["Cash", "Bank", "Card"]
    private let monthNames = DateFormatter().monthSymbols ?? []

    // MARK: - Derived
    private var amountValue: Double? {
        Double(amountText.replacingOccurrences(of: ",", with: "."))
    }
    private var canSave: Bool {
        if let a = amountValue, a > 0, !category.isEmpty, !account.isEmpty { return true }
        return false
    }

    var body: some View {
        NavigationStack {
            Form {
                // Amount
                Section("Amount") {
                    TextField("0.00", text: $amountText)
                        .keyboardType(.decimalPad)
                }

                // Details
                Section("Details") {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                        .onChange(of: date) {
                            monthIndex = Calendar.current.component(.month, from: date) - 1
                            yearNumber = Calendar.current.component(.year, from: date)
                        }

                    Picker("Month", selection: $monthIndex) {
                        ForEach(monthNames.indices, id: \.self) { i in
                            Text(monthNames[i]).tag(i)
                        }
                    }
                    Stepper("Year \(yearNumber)", value: $yearNumber, in: 2000...2100)

                    Picker("Category", selection: $category) {
                        ForEach(categories, id: \.self) { Text($0) }
                    }
                    Picker("Account", selection: $account) {
                        ForEach(accounts, id: \.self) { Text($0) }
                    }
                }

                // Note
                Section("Note (optional)") {
                    TextField("Add a note…", text: $note)
                }

                // Receipt
                Section("Receipt (optional)") {
                    HStack(spacing: 12) {
                        PhotosPicker(selection: $selectedItem, matching: .images) {
                            Label(receiptPreview == nil ? "Add photo" : "Change photo",
                                  systemImage: "photo")
                        }
                        if let img = receiptPreview {
                            Spacer()
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 56, height: 56)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }

                if let err = errorMessage {
                    Section {
                        Text(err).foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Add Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await saveExpense() }
                    } label: {
                        if isSaving { ProgressView() } else { Text("Save") }
                    }
                    .disabled(!canSave || isSaving)
                }
            }
        }
        .onChange(of: selectedItem) { newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let img = UIImage(data: data) {
                    receiptPreview = img
                    receiptData = data
                }
            }
        }
    }

    // MARK: - Save
    private func saveExpense() async {
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
            let monthName = monthNames.indices.contains(monthIndex) ? monthNames[monthIndex] : ""

            let tx = Transaction(
                userId: uid,
                type: .expense,                // <- expense
                amount: -amount,               // store expenses as negative if that’s your convention
                category: category,
                account: account,
                note: note.isEmpty ? nil : note,
                date: date,
                month: monthName,
                year: yearNumber,
                attachmentURL: nil
            )

            try await TransactionService.shared.add(tx, receiptData: receiptData)


            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
