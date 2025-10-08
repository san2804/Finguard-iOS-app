//
//  HomeView.swift
//  FinGuard
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore   // for ListenerRegistration

// MARK: - Home Screen (live Firestore updates)

struct HomeView: View {
    @EnvironmentObject var auth: AuthViewModel
    @State private var showLogoutConfirm = false

    // Live totals
    @State private var spending: Double = 0      // keep NEGATIVE here for red UI
    @State private var income:   Double = 0
    @State private var balance:  Double = 0

    // Live category rows (from EXPENSES only)
    @State private var categories: [CategoryItem] = []

    // Quick-add state
    @State private var showAddMenu = false
    @State private var presentAddIncome = false
    @State private var presentAddExpense = false

    // Sheets
    @State private var presentStats = false
    @State private var presentIncomeList = false
    @State private var presentExpenseList = false
    @State private var presentSettings = false


    // Firestore listener
    @State private var txListener: ListenerRegistration?

    /// Current month key for querying (e.g. "2025-10") - used only for display elsewhere
    private var currentMonthKey: String { Date().monthKey }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                // ===== Header: Profile + options =====
                HStack(spacing: 12) {
                    AvatarView(url: auth.user?.photoURL, name: auth.user?.displayName ?? "You", size: 36)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(auth.user?.displayName ?? "Welcome")
                            .font(.headline)
                            .foregroundStyle(.primary)
                    }

                    Spacer()

                   
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                Text("Overview")
                    .font(.title3.weight(.bold))
                    .padding(.top, 2)

                // ===== Summary (3 tiles) =====
                SummaryCard(
                    spending: spending,
                    income: income,
                    balance: balance,
                    onTapSpending: { presentExpenseList = true },
                    onTapIncome:   { presentIncomeList = true }
                )
                .padding(.horizontal, 16)
                .padding(.top, 8)

                // ===== Section =====
                HStack {
                    Text("Expenses")
                        .font(.headline)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)

                // ===== Donut + List =====
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        DonutCard(slices: donutSlices, centerLabel: "Expenses")
                            .padding(.horizontal, 16)

                        VStack(spacing: 12) {
                            ForEach(categories) { CategoryRow(item: $0) }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 100) // space for bottom bar
                    }
                    .padding(.top, 4)
                }
            }
        }
        // Bottom bar with + action -> show popup
        .overlay(alignment: .bottom) {
            BottomBar(
                activeTab: .home,
                onAdd: {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) {
                        showAddMenu = true
                    }
                },
                onStats: { presentStats = true },
                onSettings: { presentSettings = true },
                onLogout: { showLogoutConfirm = true }
            )
        }
        .alert("Sign out?", isPresented: $showLogoutConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                auth.signOut()
            }
        } message: {
            Text("You’ll be returned to the login screen.")
        }
        // Stats sheet
        .sheet(isPresented: $presentStats) {
            StatsView().environmentObject(auth)
        }

        // Income / Expense recent sheets
        .sheet(isPresented: $presentIncomeList) {
            RecentTransactionsSheet(title: "Recent Income", type: .income)
                .environmentObject(auth)
        }
        .sheet(isPresented: $presentExpenseList) {
            RecentTransactionsSheet(title: "Recent Expenses", type: .expense)
                .environmentObject(auth)
        }
        .sheet(isPresented: $presentSettings) {
            SettingsView().environmentObject(auth)
        }

        // Quick Add bottom sheet popup
        .overlay {
            if showAddMenu {
                AddQuickMenu(
                    onIncome: {
                        withAnimation(.spring()) { showAddMenu = false }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            presentAddIncome = true
                        }
                    },
                    onExpense: {
                        withAnimation(.spring()) { showAddMenu = false }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            presentAddExpense = true
                        }
                    },
                    onCancel: {
                        withAnimation(.spring()) { showAddMenu = false }
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        // Present sheets
        .sheet(isPresented: $presentAddIncome) {
            AddIncomeView().environmentObject(auth)
        }
        .sheet(isPresented: $presentAddExpense) {
            AddExpenseView().environmentObject(auth)
        }
        .navigationBarHidden(true)

        // Attach / detach the Firestore live listener
        .onAppear { attachLiveListener() }
        .onDisappear {
            txListener?.remove()
            txListener = nil
        }
        // If the logged-in user changes, reattach for new UID
        .onChange(of: auth.user?.uid) { _ in
            txListener?.remove(); txListener = nil
            attachLiveListener()
        }
    }

    // Build donut slices from categories (abs values for proportions)
    private var donutSlices: [DonutSlice] {
        let vals = categories.map { abs($0.amount) }
        let colors = categories.map { $0.color }
        return zip(vals, colors).map { DonutSlice(value: $0.0, color: $0.1) }
    }

    // MARK: - Live Firestore updates (Option B: filter by date in-memory)
    private func attachLiveListener() {
        guard let uid = auth.user?.uid else { return }

        txListener?.remove(); txListener = nil

        // Listen to all user transactions, then filter current month in-memory
        txListener = TransactionService.shared.listen(for: uid, month: nil) { txs in
            // --- Define the current month range ---
            let cal = Calendar.current
            let now = Date()
            let start = cal.date(from: cal.dateComponents([.year, .month], from: now))!
            let end   = cal.date(byAdding: .month, value: 1, to: start)!

            // --- Filter current month transactions only ---
            let current = txs.filter { $0.date >= start && $0.date < end }

            // --- Income and Expense totals ---
            let inc = current.filter { $0.type == .income }
                .reduce(0.0) { $0 + max(0, $1.amount) }

            let exp = current.filter { $0.type == .expense }
                .reduce(0.0) { $0 + abs($1.amount) }

            // --- Update Home tiles ---
            income   = inc
            spending = -exp
            balance  = inc - exp

            // --- Category breakdown for donut ---
            let grouped = Dictionary(grouping: current.filter { $0.type == .expense }) { $0.category }
            let palette: [Color] = [.teal, .orange, .pink, .purple, .cyan, .indigo, .mint, .brown, .red, .blue]

            var idx = 0
            categories = grouped.map { (cat, items) in
                let total = items.reduce(0.0) { $0 + abs($1.amount) }
                defer { idx = (idx + 1) % palette.count }
                return CategoryItem(icon: "circle.fill", name: cat, amount: -total, color: palette[idx])
            }
            categories.sort { abs($0.amount) > abs($1.amount) }
        }
    }
}

// MARK: - Quick Add Bottom Sheet

struct AddQuickMenu: View {
    var onIncome: () -> Void
    var onExpense: () -> Void
    var onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture { onCancel() }

            VStack(spacing: 14) {
                Capsule()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 40, height: 5)
                    .padding(.top, 10)

                Text("Quick Add")
                    .font(.headline)
                    .padding(.top, 4)

                VStack(spacing: 12) {
                    Button(action: onIncome) {
                        HStack(spacing: 12) {
                            Image(systemName: "arrow.down.circle.fill").font(.title2)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Add Income").font(.headline)
                                Text("Salary, interest, refunds…")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.9))
                            }
                            Spacer()
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(LinearGradient(
                                    colors: [.green.opacity(0.9), .green.opacity(0.7)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing))
                        )
                        .foregroundStyle(.white)
                        .shadow(color: .green.opacity(0.25), radius: 10, y: 4)
                    }
                    .buttonStyle(.plain)

                    Button(action: onExpense) {
                        HStack(spacing: 12) {
                            Image(systemName: "arrow.up.circle.fill").font(.title2)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Add Expense").font(.headline)
                                Text("Food, travel, shopping…")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.9))
                            }
                            Spacer()
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(LinearGradient(
                                    colors: [.red.opacity(0.95), .pink.opacity(0.85)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing))
                        )
                        .foregroundStyle(.white)
                        .shadow(color: .red.opacity(0.25), radius: 10, y: 4)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 6)

                Button(action: onCancel) {
                    Text("Cancel")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color(.systemGray6))
                        )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.15), radius: 18, y: 0)
            )
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
    }
}

// MARK: - Bottom Bar (curved, center + button)
// Replace the enum
enum Tab { case home, stats, add, settings, logout }

// Update BottomBar signature: add onSettings, remove map
struct BottomBar: View {
    var activeTab: Tab = .home
    var onAdd: () -> Void
    var onStats: () -> Void = {}
    var onSettings: () -> Void = {}     // NEW
    var onLogout: () -> Void = {}

    var body: some View {
        HStack(spacing: 28) {
            BarItem(icon: "house.fill", title: "Home", active: activeTab == .home)

            Button(action: onStats) {
                BarItem(icon: "chart.bar.fill", title: "Stats", active: activeTab == .stats)
            }

            AddButton(action: onAdd) // center

            
            Button(action: onSettings) {
                BarItem(icon: "gearshape.fill", title: "Settings", active: activeTab == .settings)
            }
            .buttonStyle(.plain)
            
            Button(action: onLogout) {
                BarItem(icon: "rectangle.portrait.and.arrow.right",
                        title: "Logout",
                        active: activeTab == .logout)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 22)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .circular)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.08), radius: 12, y: -2)
                .ignoresSafeArea(edges: .bottom)
        )
        .padding(.horizontal, 12)
    }
}


struct BarItem: View {
    let icon: String
    let title: String
    let active: Bool

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(active ? Color.blue : .secondary)
            Text(title)
                .font(.caption2)
                .foregroundStyle(active ? Color.blue : .secondary)
                .opacity(0.9)
        }
        .frame(maxWidth: .infinity)
    }
}

struct AddButton: View {
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Color.blue, Color.cyan],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 54, height: 54)
                    .shadow(color: .black.opacity(0.15), radius: 8, y: 3)
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Avatar

struct AvatarView: View {
    let url: URL?
    let name: String
    var size: CGFloat = 32

    var body: some View {
        Group {
            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image): image.resizable().scaledToFill()
                    case .failure(_): fallback
                    case .empty: ProgressView()
                    @unknown default: fallback
                    }
                }
            } else {
                fallback
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color(.systemGray5), lineWidth: 1))
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
    }

    private var fallback: some View {
        ZStack {
            Circle().fill(Color(.systemGray5))
            Text(name.initials(2))
                .font(.caption.bold())
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Summary Card (3 tiles)

struct SummaryCard: View {
    let spending: Double
    let income: Double
    let balance: Double
    var onTapSpending: () -> Void
    var onTapIncome: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onTapSpending) {
                SummaryTile(icon: "chart.pie.fill", title: "Spending", amount: spending, tint: .red)
            }
            .buttonStyle(.plain)

            Divider().frame(height: 44)

            Button(action: onTapIncome) {
                SummaryTile(icon: "banknote.fill", title: "Income", amount: income, tint: .green)
            }
            .buttonStyle(.plain)

            Divider().frame(height: 44)

            SummaryTile(icon: "briefcase.fill", title: "Balance", amount: balance, tint: .yellow)
        }
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.systemBackground))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(.systemGray5), lineWidth: 1))
                .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
        )
    }
}

struct SummaryTile: View {
    let icon: String
    let title: String
    let amount: Double
    let tint: Color
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tint)
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text(amount.formattedCurrency)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(amount < 0 ? Color.red : Color.green)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }
}

// MARK: - Donut

struct DonutCard: View {
    let slices: [DonutSlice]
    let centerLabel: String
    var total: Double { max(slices.map(\.value).reduce(0, +), 0.0001) }
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.systemBackground))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color(.systemGray5), lineWidth: 1))
                .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .trim(from: 0, to: 1)
                        .stroke(Color.gray.opacity(0.15), lineWidth: 26)
                        .frame(width: 220, height: 220)
                    DonutRing(slices: slices, lineWidth: 26)
                        .frame(width: 220, height: 220)
                    VStack(spacing: 6) {
                        Text(centerLabel)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        // Show a positive total in the center, avoid "-0"
                        let centerTotal = abs(slices.map(\.value).reduce(0, +))
                        Text(centerTotal.formattedAsCurrencyNoSymbol())
                            .font(.headline.weight(.semibold))
                    }
                    .padding(6)
                    .background(
                        Circle().fill(Color(.systemBackground))
                            .frame(width: 120, height: 120)
                            .shadow(color: .black.opacity(0.04), radius: 3, y: 1)
                    )
                }
                .padding(.top, 10)
                .padding(.bottom, 6)
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity)
    }
}

struct DonutSlice: Identifiable {
    let id = UUID()
    let value: Double
    let color: Color
}

struct DonutRing: View {
    let slices: [DonutSlice]
    let lineWidth: CGFloat
    var body: some View {
        GeometryReader { geo in
            let radius = min(geo.size.width, geo.size.height) / 2
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let values = slices.map(\.value)
            let safeTotal = max(values.reduce(0, +), 0.0001)
            let prefix: [Double] = values.reduce(into: [0.0]) { acc, v in acc.append(acc.last! + v) }
            ZStack {
                ForEach(slices.indices, id: \.self) { i in
                    let startAngle = CGFloat(prefix[i] / safeTotal * 2 * .pi) - .pi / 2
                    let endAngle   = CGFloat(prefix[i + 1] / safeTotal * 2 * .pi) - .pi / 2
                    Path { p in
                        p.addArc(center: center,
                                 radius: radius,
                                 startAngle: Angle(radians: Double(startAngle)),
                                 endAngle:   Angle(radians: Double(endAngle)),
                                 clockwise: false)
                    }
                    .stroke(slices[i].color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                }
            }
        }
    }
}

// MARK: - Category List

struct CategoryItem: Identifiable {
    let id = UUID()
    let icon: String      // SF Symbol
    let name: String
    let amount: Double    // negative for expenses (UI)
    let color: Color
}

struct CategoryRow: View {
    let item: CategoryItem
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(item.color.opacity(0.15))
                    .frame(width: 42, height: 42)
                Image(systemName: item.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(item.color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name).font(.subheadline.weight(.semibold))
                Text(Date.now, style: .date).font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            Text(item.amount.formattedCurrency)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.red)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(.systemGray5), lineWidth: 1))
        )
    }
}

// MARK: - Recent Transactions Sheet (per type)

struct RecentTransactionsSheet: View {
    enum Kind { case income, expense }
    let title: String
    let type: Kind

    @EnvironmentObject var auth: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var items: [Transaction] = []
    @State private var listener: ListenerRegistration?
    

    private func attach() {
        guard let uid = auth.user?.uid else { return }
        listener?.remove(); listener = nil

        listener = TransactionService.shared.listen(for: uid, month: nil) { txs in
            // Filter by current month
            let cal = Calendar.current
            let now = Date()
            let start = cal.date(from: cal.dateComponents([.year, .month], from: now))!
            let end   = cal.date(byAdding: .month, value: 1, to: start)!

            let current = txs.filter { $0.date >= start && $0.date < end }

            switch type {
            case .income:  items = current.filter { $0.type == .income }
            case .expense: items = current.filter { $0.type == .expense }
            }
        }
    }

    var body: some View {
        NavigationStack {
            List(items.sorted(by: { $0.date > $1.date })) { t in
                HStack(spacing: 12) {
                    Image(systemName: type == .income ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                        .foregroundStyle(type == .income ? .green : .red)
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(t.category).font(.subheadline.weight(.semibold))
                        Text(t.date, style: .date).font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text((type == .expense ? -abs(t.amount) : max(0, t.amount)).formattedCurrency)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(type == .income ? .green : .red)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .onAppear { attach() }
        .onDisappear { listener?.remove(); listener = nil }
    }
}

// MARK: - Helpers

extension String {
    /// "Jane Doe" -> "JD"
    func initials(_ maxLetters: Int = 2) -> String {
        self.split(separator: " ")
            .prefix(maxLetters)
            .compactMap { $0.first }
            .map(String.init)
            .joined()
            .uppercased()
    }
}

extension Double {
    /// Localized currency (with symbol)
    var formattedCurrency: String {
        Self.currencyFormatter.string(from: NSNumber(value: self)) ?? String(self)
    }
    /// Currency look without symbol (for donut center)
    func formattedAsCurrencyNoSymbol() -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencySymbol = ""
        f.maximumFractionDigits = 0
        f.minimumFractionDigits = 0
        return (f.string(from: NSNumber(value: self)) ?? "\(self)").trimmingCharacters(in: .whitespaces)
    }
    fileprivate static var currencyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.maximumFractionDigits = 0
        f.minimumFractionDigits = 0
        return f
    }()
}

extension Date {
    /// "yyyy-MM" convenience (not used for Option B logic)
    var monthKey: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM"
        return f.string(from: self)
    }
}

// MARK: - Preview
#Preview {
    HomeView().environmentObject(AuthViewModel())
}
