import SwiftUI
import SwiftData

@main
struct WasteDiaryApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [WasteEntry.self, ReceiptEntry.self])
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: WasteViewModel?
    @State private var selectedTab = 0

    var body: some View {
        Group {
            if let viewModel {
                TabView(selection: $selectedTab) {
                    HomeView(viewModel: viewModel)
                        .tabItem { Label("Home", systemImage: "house.fill") }
                        .tag(0)

                    ScanPickerView(viewModel: viewModel)
                        .tabItem { Label("Scan", systemImage: "camera.fill") }
                        .tag(1)

                    DashboardView(viewModel: viewModel)
                        .tabItem { Label("Dashboard", systemImage: "chart.bar.fill") }
                        .tag(2)

                    SuggestionsView(viewModel: viewModel)
                        .tabItem { Label("Tips", systemImage: "lightbulb.fill") }
                        .tag(3)
                }
                .tint(.accent)
                .onChange(of: viewModel.selectedTab) { _, tab in
                    selectedTab = tab
                }
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
