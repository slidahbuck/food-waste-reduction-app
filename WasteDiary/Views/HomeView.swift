import SwiftUI

struct HomeView: View {
    @Bindable var viewModel: WasteViewModel
    @State private var navigateToCamera = false

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good Morning"
        case 12..<17: return "Good Afternoon"
        default: return "Good Evening"
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Greeting
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(greeting)
                                .font(.title)
                                .fontWeight(.bold)
                            Text("Track your food waste, reduce your impact.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal)

                    // Weekly Summary Card
                    weeklySummaryCard

                    // Streak Counter
                    streakCard

                    // Log Waste Button
                    Button {
                        navigateToCamera = true
                    } label: {
                        Label("Log Waste", systemImage: "plus.circle.fill")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Waste Diary")
            .fullScreenCover(isPresented: $navigateToCamera) {
                CameraView(viewModel: viewModel)
            }
        }
    }

    private var weeklySummaryCard: some View {
        VStack(spacing: 12) {
            HStack {
                Text("This Week")
                    .font(.headline)
                Spacer()
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(.accent)
            }

            HStack(spacing: 24) {
                VStack(spacing: 4) {
                    Text(String(format: "%.0f g", viewModel.thisWeekTotalGrams))
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Total Waste")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Divider()
                    .frame(height: 40)

                VStack(spacing: 4) {
                    Text(String(format: "$%.2f", viewModel.thisWeekTotalCost))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.red)
                    Text("Est. Cost")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Divider()
                    .frame(height: 40)

                VStack(spacing: 4) {
                    Text("\(viewModel.thisWeekEntries.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Entries")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    private var streakCard: some View {
        HStack {
            Image(systemName: "flame.fill")
                .font(.title)
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(viewModel.loggingStreak) Day Streak")
                    .font(.headline)
                Text(viewModel.loggingStreak > 0
                     ? "Keep it up! Tracking helps you waste less."
                     : "Log your first entry today to start a streak!")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }
}
