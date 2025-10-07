import SwiftUI
import Charts
import FirebaseAuth

struct StatsView: View {
    @EnvironmentObject var auth: AuthViewModel

    // pick a year (defaults to current year)
    @State private var selectedYear = Calendar.current.component(.year, from: Date())
    // 12 months, income & expense totals
    @State private var monthly: [MonthStat] = MonthStat.emptyYear()

    // listener token
    @State private var listenerToken: ListenerRegistration?

    private let monthLabels = DateFormatter().shortMonthSymbols ?? ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    // Year selector
                    HStack {
                        Text("Year")
                            .font(.headline)
                        Spacer()
                        Picker("", selection: $selectedYear) {
                            // last 5 years including this year
                            let nowYear = Calendar.current.component(.year, from: Date())
                            ForEach((nowYear-4)...nowYear, id: \.self) { y in
                                Text("\(y)").tag(y)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 280)
                    }
                    .padding(.horizontal)

                    // Income chart
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Income (\(selectedYear))")
                            .font(.headline)
                            .padding(.horizontal)
                        Chart(monthly) { m in
                            BarMark(
                                x: .value("Month", monthLabels[m.monthIndex]),
                                y: .value("Income", m.income)
                            )
                            .foregroundStyle(.green)
                            .annotation(position: .top, alignment: .center) {
                                if m.income > 0 {
                                    Text(m.income.formattedAsCurrencyNoSymbol())
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .frame(height: 220)
                        .padding(.horizontal)
                    }

                    // Expense chart
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Expenses (\(selectedYear))")
                            .font(.headline)
                            .padding(.horizontal)
                        Chart(monthly) { m in
                            BarMark(
                                x: .value("Month", monthLabels[m.monthIndex]),
                                y: .value("Expense", m.expense)
                            )
                            .foregroundStyle(.red)
                            .annotation(position: .top, alignment: .center) {
                                if m.expense > 0 {
                                    Text(m.expense.formattedAsCurrencyNoSymbol())
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .frame(height: 220)
                        .padding(.horizontal)
                    }

                    Spacer(minLength: 24)
                }
                .padding(.top, 12)
            }
            .navigationTitle("Stats")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear   { attachYearListener() }
        .onDisappear{ listenerToken?.remove(); listenerToken = nil }
        .onChange(of: selectedYear) { _ in
            listenerToken?.remove()
            listenerToken = nil
            attachYearListener()
        }
    }

    private func attachYearListener() {
        guard let uid = auth.user?.uid else { return }
        // reset while loading
        monthly = MonthStat.emptyYear()

        listenerToken = TransactionService.shared.listenYear(for: uid, year: selectedYear) { txs in
            var buckets = MonthStat.emptyYear()
            for tx in txs {
                let m = Calendar.current.component(.month, from: tx.date) - 1 // 0...11
                if tx.type == .income   { buckets[m].income  += max(0, tx.amount) }
                if tx.type == .expense  { buckets[m].expense += max(0, tx.amount) }
            }
            monthly = buckets
        }
    }
}

// MARK: - Helpers

struct MonthStat: Identifiable {
    let id = UUID()
    let monthIndex: Int        // 0...11
    var income:  Double
    var expense: Double

    static func emptyYear() -> [MonthStat] {
        (0..<12).map { MonthStat(monthIndex: $0, income: 0, expense: 0) }
    }
}

private extension Double {
    func formattedAsCurrencyNoSymbol() -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencySymbol = ""
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 0
        return (f.string(from: NSNumber(value: self)) ?? "\(self)").trimmingCharacters(in: .whitespaces)
    }
}
