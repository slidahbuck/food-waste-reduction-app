import SwiftUI
import Charts

struct DashboardView: View {
    @Bindable var viewModel: WasteViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    weeklyBarChart
                    weekComparison
                    categoryBreakdown
                }
                .padding(.vertical)
            }
            .navigationTitle("Dashboard")
        }
    }

    // MARK: - Weekly Bar Chart

    private var weeklyBarChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("This Week by Category")
                .font(.headline)
                .padding(.horizontal)

            Chart(viewModel.weeklyChartData, id: \.category) { item in
                BarMark(
                    x: .value("Category", item.category.displayName),
                    y: .value("Grams", item.grams)
                )
                .foregroundStyle(item.category.color)
                .cornerRadius(6)
            }
            .chartYAxisLabel("Grams")
            .frame(height: 220)
            .padding(.horizontal)
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    // MARK: - Week Comparison

    private var weekComparison: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Week Comparison")
                    .font(.headline)
                Spacer()
            }

            HStack(spacing: 24) {
                weekColumn(
                    title: "This Week",
                    grams: viewModel.thisWeekTotalGrams,
                    isCurrent: true
                )
                weekColumn(
                    title: "Last Week",
                    grams: viewModel.lastWeekTotalGrams,
                    isCurrent: false
                )
            }

            if viewModel.lastWeekTotalGrams > 0 {
                let change = viewModel.thisWeekTotalGrams - viewModel.lastWeekTotalGrams
                let pct = (change / viewModel.lastWeekTotalGrams) * 100
                HStack {
                    Image(systemName: change <= 0 ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                        .foregroundStyle(change <= 0 ? .green : .red)
                    Text(String(format: "%.0f%% %@", abs(pct), change <= 0 ? "less waste" : "more waste"))
                        .font(.subheadline)
                        .foregroundStyle(change <= 0 ? .green : .red)
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    private func weekColumn(title: String, grams: Double, isCurrent: Bool) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(String(format: "%.0f g", grams))
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(isCurrent ? .primary : .secondary)
            Text(String(format: "$%.2f", grams * 0.00882))
                .font(.caption)
                .foregroundStyle(.red)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Category Breakdown

    private var categoryBreakdown: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Breakdown by Category")
                .font(.headline)

            if viewModel.thisWeekByCategory.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "tray.fill")
                            .font(.title)
                            .foregroundStyle(.secondary)
                        Text("No entries this week")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 24)
                    Spacer()
                }
            } else {
                ForEach(viewModel.thisWeekByCategory, id: \.category) { item in
                    HStack {
                        Image(systemName: item.category.icon)
                            .foregroundStyle(item.category.color)
                            .frame(width: 28)
                        Text(item.category.displayName)
                            .fontWeight(.medium)
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text(String(format: "%.0f g", item.grams))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text(String(format: "$%.2f", item.cost))
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }
}
