import SwiftUI
import SwiftData

@main
struct WasteDiaryApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: WasteEntry.self)
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: WasteViewModel?

    var body: some View {
        Group {
            if let viewModel {
                TabView {
                    HomeView(viewModel: viewModel)
                        .tabItem {
                            Label("Home", systemImage: "house.fill")
                        }

                    CameraView(viewModel: viewModel)
                        .tabItem {
                            Label("Log", systemImage: "plus.circle.fill")
                        }

                    DashboardView(viewModel: viewModel)
                        .tabItem {
                            Label("Dashboard", systemImage: "chart.bar.fill")
                        }

                    HistoryView(viewModel: viewModel)
                        .tabItem {
                            Label("History", systemImage: "clock.fill")
                        }
                }
                .tint(.accent)
            } else {
                ProgressView("Loading...")
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = WasteViewModel(modelContext: modelContext)
            }
        }
    }
}
