import SwiftUI

struct HistoryView: View {
    @Bindable var viewModel: WasteViewModel

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.entries.isEmpty {
                    emptyState
                } else {
                    entryList
                }
            }
            .navigationTitle("History")
        }
    }

    // MARK: - Entry List

    private var entryList: some View {
        List {
            ForEach(viewModel.entriesGroupedByDay, id: \.date) { group in
                Section {
                    ForEach(group.entries, id: \.id) { entry in
                        entryRow(entry)
                    }
                    .onDelete { offsets in
                        for index in offsets {
                            viewModel.deleteEntry(group.entries[index])
                        }
                    }
                } header: {
                    Text(group.date, style: .date)
                }
            }
        }
    }

    private func entryRow(_ entry: WasteEntry) -> some View {
        HStack(spacing: 12) {
            // Thumbnail
            if let photoData = entry.photoData,
               let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.quaternary)
                    .frame(width: 50, height: 50)
                    .overlay {
                        Image(systemName: entry.foodCategory.icon)
                            .foregroundStyle(.secondary)
                    }
            }

            // Details
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.foodType)
                    .font(.headline)
                HStack(spacing: 8) {
                    Text(String(format: "%.0f g", entry.estimatedGrams))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(entry.timestamp, style: .time)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Reason Badge
            Text(entry.wasteReason.displayName)
                .font(.caption2)
                .fontWeight(.medium)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.accentColor.opacity(0.15))
                .foregroundStyle(.accent)
                .clipShape(Capsule())
        }
        .padding(.vertical, 2)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "leaf.fill")
                .font(.system(size: 48))
                .foregroundStyle(.accent)
            Text("No Entries Yet")
                .font(.title2)
                .fontWeight(.bold)
            Text("Start logging your food waste to see your history here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}
