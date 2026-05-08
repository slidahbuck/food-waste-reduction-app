import SwiftUI

struct HistoryView: View {
    @Bindable var viewModel: WasteViewModel

    private enum HistoryItem {
        case waste(WasteEntry)
        case receipt(ReceiptEntry)

        var timestamp: Date {
            switch self {
            case .waste(let e): return e.timestamp
            case .receipt(let e): return e.timestamp
            }
        }
    }

    private var allGroupedByDay: [(date: Date, items: [HistoryItem])] {
        let calendar = Calendar.current
        var all: [HistoryItem] = viewModel.entries.map { .waste($0) }
            + viewModel.receiptEntries.map { .receipt($0) }
        all.sort { $0.timestamp > $1.timestamp }
        let grouped = Dictionary(grouping: all) { calendar.startOfDay(for: $0.timestamp) }
        return grouped.sorted { $0.key > $1.key }.map { (date: $0.key, items: $0.value) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.entries.isEmpty && viewModel.receiptEntries.isEmpty {
                    ZStack {
                        Color(UIColor.systemGroupedBackground).ignoresSafeArea()
                        emptyState
                    }
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
            ForEach(allGroupedByDay, id: \.date) { group in
                Section {
                    ForEach(group.items.indices, id: \.self) { index in
                        switch group.items[index] {
                        case .waste(let entry):
                            wasteRow(entry)
                        case .receipt(let entry):
                            receiptRow(entry)
                        }
                    }
                    .onDelete { offsets in
                        for index in offsets {
                            switch group.items[index] {
                            case .waste(let e): viewModel.deleteEntry(e)
                            case .receipt(let e): viewModel.deleteReceiptEntry(e)
                            }
                        }
                    }
                } header: {
                    Text(group.date, style: .date)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .textCase(nil)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Waste Row

    private func wasteRow(_ entry: WasteEntry) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color(UIColor.systemGroupedBackground))
                    .frame(width: 40, height: 40)
                if let photoData = entry.photoData, let uiImage = UIImage(data: photoData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                } else {
                    Image(systemName: entry.foodCategory.icon)
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.foodType)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(String(format: "%.0f g · ", entry.estimatedGrams) + entry.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(entry.wasteReason.displayName)
                .font(.caption2)
                .fontWeight(.medium)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.brown.opacity(0.10))
                .foregroundStyle(.brown)
                .clipShape(Capsule())
        }
        .padding(.vertical, 2)
    }

    // MARK: - Receipt Row

    private func receiptRow(_ entry: ReceiptEntry) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color(UIColor.systemGroupedBackground))
                    .frame(width: 40, height: 40)
                if let photoData = entry.photoData, let uiImage = UIImage(data: photoData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                } else {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.storeName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("\(entry.items.count) items · " + entry.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(String(format: "$%.2f", entry.total))
                .font(.caption2)
                .fontWeight(.medium)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(red: 0.53, green: 0.63, blue: 0.55).opacity(0.15))
                .foregroundStyle(Color(red: 0.53, green: 0.63, blue: 0.55))
                .clipShape(Capsule())
        }
        .padding(.vertical, 2)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "leaf.fill")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text("No entries yet")
                .font(.headline)
                .foregroundStyle(.primary)
            Text("Log food waste or scan a receipt\nto see your history here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}
