import SwiftUI

struct HomeView: View {
    @Bindable var viewModel: WasteViewModel
    @State private var activeScanMode: ScanMode?

    private var greetingWord: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "morning"
        case 12..<17: return "afternoon"
        default: return "evening"
        }
    }

    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground).ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Good")
                            .font(.system(size: 38, weight: .bold))
                            .foregroundStyle(.primary)
                        Text(greetingWord)
                            .font(.system(size: 38, weight: .bold))
                            .foregroundStyle(.secondary.opacity(0.45))
                    }
                    .padding(.top, 8)

                    // Weekly hero card
                    weeklyHeroCard

                    // Quick actions
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Quick Actions")
                                .font(.headline)
                            Spacer()
                        }

                        VStack(spacing: 0) {
                            actionRow(
                                icon: "trash.fill",
                                iconColor: .brown,
                                title: "Log Waste",
                                subtitle: "Photograph discarded food"
                            ) { activeScanMode = .wastedFood }

                            Divider().padding(.leading, 58)

                            actionRow(
                                icon: "doc.text.viewfinder",
                                iconColor: .primary,
                                title: "Scan Receipt",
                                subtitle: "Track grocery spending"
                            ) { activeScanMode = .receipt }
                        }
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                    }

                    // Impact line
                    HStack(spacing: 6) {
                        Image(systemName: "leaf.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("Food waste drives ~10% of global emissions.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
        }
        .fullScreenCover(item: $activeScanMode) { mode in
            CameraView(viewModel: viewModel, scanMode: mode)
        }
    }

    private var weeklyHeroCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("This Week")
                    .font(.headline)
                if viewModel.loggingStreak > 0 {
                    Text("\(viewModel.loggingStreak) day streak")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.brown.opacity(0.75))
                        .clipShape(Capsule())
                }
                Spacer()
                Button { activeScanMode = .wastedFood } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.primary)
                }
            }

            HStack(spacing: 12) {
                statTile(
                    label: "total waste",
                    value: String(format: "%.0fg", viewModel.thisWeekTotalGrams)
                )
                statTile(
                    label: "est. cost",
                    value: String(format: "$%.2f", viewModel.thisWeekTotalCost)
                )
                statTile(
                    label: "entries",
                    value: "\(viewModel.thisWeekEntries.count)"
                )
            }
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func statTile(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                Circle()
                    .trim(from: 0, to: 0.65)
                    .stroke(Color.secondary.opacity(0.25), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .frame(width: 18, height: 18)
                    .rotationEffect(.degrees(-90))
            }
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
        }
        .padding(12)
        .background(Color(UIColor.systemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .frame(maxWidth: .infinity)
    }

    private func actionRow(
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color(UIColor.systemGroupedBackground))
                        .frame(width: 38, height: 38)
                    Image(systemName: icon)
                        .font(.system(size: 15))
                        .foregroundStyle(iconColor)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.quaternary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
        }
    }
}
