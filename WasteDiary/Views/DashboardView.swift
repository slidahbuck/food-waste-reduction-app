import SwiftUI
import Charts

struct DashboardView: View {
    @Bindable var viewModel: WasteViewModel

    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        sectionCard(
                            title: "Spend vs. Waste",
                            subtitle: "Estimated waste cost against grocery spend",
                            seeMoreDestination: nil
                        ) {
                            let hasData = viewModel.weeklySpendVsWaste.contains(where: { $0.spent > 0 || $0.wasted > 0 })
                            if hasData {
                                Chart {
                                    ForEach(viewModel.weeklySpendVsWaste, id: \.day) { item in
                                        BarMark(
                                            x: .value("Day", item.day, unit: .day),
                                            y: .value("Amount", item.wasted)
                                        )
                                        .foregroundStyle(by: .value("Type", "Wasted"))
                                        .cornerRadius(4)

                                        BarMark(
                                            x: .value("Day", item.day, unit: .day),
                                            y: .value("Amount", item.spent)
                                        )
                                        .foregroundStyle(by: .value("Type", "Spent"))
                                        .cornerRadius(4)
                                    }
                                }
                                .chartForegroundStyleScale([
                                "Wasted": Color.brown,
                                "Spent": Color(red: 0.53, green: 0.63, blue: 0.55)
                            ])
                                .chartLegend(position: .top, alignment: .leading)
                                .chartXAxis {
                                    AxisMarks(values: .stride(by: .day)) {
                                        AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                                        AxisGridLine()
                                    }
                                }
                                .chartYAxis {
                                    AxisMarks { value in
                                        AxisValueLabel {
                                            if let d = value.as(Double.self) {
                                                Text("$\(Int(d))").font(.caption2)
                                            }
                                        }
                                        AxisGridLine()
                                    }
                                }
                                .frame(height: 220)
                            } else {
                                emptyPlaceholder(icon: "chart.bar.xaxis", message: "Scan receipts and log waste to see your comparison")
                            }
                        }

                        sectionCard(
                            title: "Food Waste",
                            subtitle: String(format: "%.0f g this week", viewModel.thisWeekTotalGrams),
                            seeMoreDestination: AnyView(HistoryView(viewModel: viewModel))
                        ) {
                            if viewModel.weeklyWasteByDay.contains(where: { $0.grams > 0 }) {
                                Chart(viewModel.weeklyWasteByDay, id: \.day) { item in
                                    BarMark(
                                        x: .value("Day", item.day, unit: .day),
                                        y: .value("Grams", item.grams)
                                    )
                                    .foregroundStyle(Color.brown)
                                    .cornerRadius(5)
                                }
                                .chartXAxis {
                                    AxisMarks(values: .stride(by: .day)) {
                                        AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                                        AxisGridLine()
                                    }
                                }
                                .chartYAxis {
                                    AxisMarks { value in
                                        AxisValueLabel {
                                            if let g = value.as(Double.self) {
                                                Text("\(Int(g))g").font(.caption2)
                                            }
                                        }
                                        AxisGridLine()
                                    }
                                }
                                .frame(height: 200)
                            } else {
                                emptyPlaceholder(icon: "trash", message: "No waste logged this week")
                            }
                        }

                        sectionCard(
                            title: "Grocery Spending",
                            subtitle: String(format: "$%.2f this week", viewModel.thisWeekReceiptTotal),
                            seeMoreDestination: AnyView(ReceiptHistoryView(viewModel: viewModel))
                        ) {
                            if viewModel.weeklyReceiptChartData.contains(where: { $0.total > 0 }) {
                                Chart(viewModel.weeklyReceiptChartData, id: \.day) { item in
                                    BarMark(
                                        x: .value("Day", item.day, unit: .day),
                                        y: .value("Spent", item.total)
                                    )
                                    .foregroundStyle(Color(red: 0.53, green: 0.63, blue: 0.55))
                                    .cornerRadius(5)
                                }
                                .chartXAxis {
                                    AxisMarks(values: .stride(by: .day)) {
                                        AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                                        AxisGridLine()
                                    }
                                }
                                .chartYAxis {
                                    AxisMarks { value in
                                        AxisValueLabel {
                                            if let d = value.as(Double.self) {
                                                Text("$\(Int(d))").font(.caption2)
                                            }
                                        }
                                        AxisGridLine()
                                    }
                                }
                                .frame(height: 200)
                            } else {
                                emptyPlaceholder(icon: "doc.text", message: "No receipts scanned this week")
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("Dashboard")
        }
    }

    // MARK: - Section Card

    @ViewBuilder
    private func sectionCard<Content: View>(
        title: String,
        subtitle: String,
        seeMoreDestination: AnyView?,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline)
                    Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                if let destination = seeMoreDestination {
                    NavigationLink(destination: destination) {
                        Text("See all")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            content()
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Empty Placeholder

    private func emptyPlaceholder(icon: String, message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title)
                .foregroundStyle(.tertiary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
    }
}
