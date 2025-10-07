import SwiftUI

struct HomeView: View {
    // Demo data – swap with your real model later
    @State private var totalBudget: Double = 3400
    @State private var monthLabel: String = "January, 2022"
    @State private var categories: [CategorySpend] = [
        .init(icon: "takeoutbag.and.cup.and.straw.fill",
              name: "Food & Drink",
              monthlyBudget: 220,
              spent: 12,
              barGradient: [Color.green, Color.mint],
              statusText: "Good job!"),
        .init(icon: "car.fill",
              name: "Taxi Service",
              monthlyBudget: 400,
              spent: 450,
              barGradient: [Color.green, Color.teal],
              statusText: "Oops! Over budget")
    ]

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            VStack(spacing: 16) {

                // Header
                BudgetHeaderCard(totalBudget: totalBudget, monthLabel: monthLabel)

                // Cards list
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        ForEach(categories) { cat in
                            CategoryCard(category: cat)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 90) // room for bottom bar
                }
            }
        }
        .overlay(alignment: .bottom) {
            BottomBar()
        }
        .navigationBarHidden(true)
    }
}

struct BudgetHeaderCard: View {
    var totalBudget: Double
    var monthLabel: String

    var body: some View {
        ZStack(alignment: .top) {
            // Green gradient background with curved corners
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.green, Color.mint],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .frame(height: 220)
                .padding(.horizontal, 12)
                .shadow(color: Color.black.opacity(0.08), radius: 12, y: 6)

            VStack(spacing: 8) {
                // Icon bubble
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.25))
                        .frame(width: 64, height: 64)
                    Image(systemName: "banknote.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(.white)
                }
                .padding(.top, 22)

                Text("$\(Int(totalBudget)).00")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text("budget limit for \(monthLabel)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white.opacity(0.9))
            }
        }
        .padding(.top, 12)
    }
}

// MARK: - Category Model
struct CategorySpend: Identifiable {
    let id = UUID()
    let icon: String
    let name: String
    let monthlyBudget: Double
    let spent: Double
    let barGradient: [Color]
    let statusText: String

    var progress: Double {
        guard monthlyBudget > 0 else { return 0 }
        return min(spent / monthlyBudget, 1.0)
    }

    var isOverBudget: Bool { spent > monthlyBudget }
}

// MARK: - Category Card
struct CategoryCard: View {
    let category: CategorySpend

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header row
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.green.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: category.icon)
                        .foregroundColor(.green)
                        .font(.system(size: 20, weight: .semibold))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(category.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text("$ \(Int(category.monthlyBudget)).00 / month")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            // Progress Row (spent vs budget)
            HStack {
                Text("$\(Int(category.spent))")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
                Spacer()
                Text("$\(Int(category.monthlyBudget))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            ProgressBar(progress: category.progress, gradient: category.barGradient)

            // Status
            Text(category.statusText)
                .font(.caption.weight(.semibold))
                .foregroundColor(category.isOverBudget ? .red : .green)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .shadow(color: Color.black.opacity(0.06), radius: 8, y: 4)
    }
}

// MARK: - Progress Bar
struct ProgressBar: View {
    var progress: Double // 0...1
    var gradient: [Color]

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let capped = max(0.0, min(progress, 1.0))

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.gray.opacity(0.15))
                    .frame(height: 12)

                Capsule()
                    .fill(LinearGradient(colors: gradient,
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: width * capped, height: 12)
            }
        }
        .frame(height: 12)
    }
}

// MARK: - Bottom Bar
struct BottomBar: View {
    var body: some View {
        HStack(spacing: 28) {
            BarItem(icon: "house.fill", title: "Home", active: true)
            BarItem(icon: "chart.bar.fill", title: "Stats")
            AddButton()
            BarItem(icon: "square.grid.2x2.fill", title: "Categories")
            BarItem(icon: "gearshape.fill", title: "Settings")
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 22)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.08), radius: 12, y: -2)
                .ignoresSafeArea(edges: .bottom)
        )
        .padding(.horizontal, 12)
    }
}

struct BarItem: View {
    var icon: String
    var title: String
    var active: Bool = false
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(active ? .green : .secondary)
            Circle()
                .fill(active ? Color.green : .clear)
                .frame(width: 4, height: 4)
        }
        .frame(maxWidth: .infinity)
    }
}

struct AddButton: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [Color.green, Color.mint],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 52, height: 52)
                .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
            Image(systemName: "plus")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    NavigationView { HomeView() }
}
