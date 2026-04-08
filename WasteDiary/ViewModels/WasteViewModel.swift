import Foundation
import SwiftData
import SwiftUI
import UIKit

@Observable
final class WasteViewModel {
    private var modelContext: ModelContext

    var entries: [WasteEntry] = []
    var isAnalyzing = false

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        fetchEntries()
    }

    // MARK: - CRUD

    func addEntry(
        photoData: Data?,
        foodType: String,
        estimatedGrams: Double,
        wasteReason: WasteReason,
        confidence: Double,
        notes: String?
    ) {
        let entry = WasteEntry(
            photoData: photoData,
            foodType: foodType,
            estimatedGrams: estimatedGrams,
            wasteReason: wasteReason,
            confidence: confidence,
            notes: notes
        )
        modelContext.insert(entry)
        save()
        fetchEntries()
    }

    func deleteEntry(_ entry: WasteEntry) {
        modelContext.delete(entry)
        save()
        fetchEntries()
    }

    func fetchEntries() {
        let descriptor = FetchDescriptor<WasteEntry>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        entries = (try? modelContext.fetch(descriptor)) ?? []
    }

    private func save() {
        try? modelContext.save()
    }

    // MARK: - Weekly Aggregation

    var thisWeekEntries: [WasteEntry] {
        let calendar = Calendar.current
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        return entries.filter { $0.timestamp >= startOfWeek }
    }

    var lastWeekEntries: [WasteEntry] {
        let calendar = Calendar.current
        guard let thisWeekInterval = calendar.dateInterval(of: .weekOfYear, for: Date()) else {
            return []
        }
        let lastWeekEnd = thisWeekInterval.start
        let lastWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: lastWeekEnd) ?? lastWeekEnd
        return entries.filter { $0.timestamp >= lastWeekStart && $0.timestamp < lastWeekEnd }
    }

    var thisWeekTotalGrams: Double {
        thisWeekEntries.reduce(0) { $0 + $1.estimatedGrams }
    }

    var lastWeekTotalGrams: Double {
        lastWeekEntries.reduce(0) { $0 + $1.estimatedGrams }
    }

    var thisWeekTotalCost: Double {
        thisWeekEntries.reduce(0) { $0 + $1.estimatedCost }
    }

    /// Breakdown of this week's waste by FoodCategory.
    var thisWeekByCategory: [(category: FoodCategory, grams: Double, cost: Double)] {
        var map: [FoodCategory: (grams: Double, cost: Double)] = [:]
        for entry in thisWeekEntries {
            let cat = entry.foodCategory
            let existing = map[cat, default: (0, 0)]
            map[cat] = (existing.grams + entry.estimatedGrams, existing.cost + entry.estimatedCost)
        }
        return map.map { (category: $0.key, grams: $0.value.grams, cost: $0.value.cost) }
            .sorted { $0.grams > $1.grams }
    }

    /// Weekly chart data: grams per FoodCategory for this week.
    var weeklyChartData: [(category: FoodCategory, grams: Double)] {
        var map: [FoodCategory: Double] = [:]
        for entry in thisWeekEntries {
            map[entry.foodCategory, default: 0] += entry.estimatedGrams
        }
        return FoodCategory.allCases.map { cat in
            (category: cat, grams: map[cat, default: 0])
        }
    }

    // MARK: - Streak

    /// Number of consecutive days (ending today or yesterday) the user logged at least one entry.
    var loggingStreak: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let loggedDays = Set(entries.map { calendar.startOfDay(for: $0.timestamp) })

        // Start counting from today or yesterday
        var checkDate = today
        if !loggedDays.contains(today) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else {
                return 0
            }
            checkDate = yesterday
        }

        var streak = 0
        while loggedDays.contains(checkDate) {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = prev
        }
        return streak
    }

    // MARK: - Entries Grouped by Day

    var entriesGroupedByDay: [(date: Date, entries: [WasteEntry])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: entries) { entry in
            calendar.startOfDay(for: entry.timestamp)
        }
        return grouped.sorted { $0.key > $1.key }
            .map { (date: $0.key, entries: $0.value) }
    }

    // MARK: - Mock Gemma Inference

    /// Analyzes a food waste image using the on-device Gemma model.
    /// // TODO: Replace with Gemma 4 Core ML inference
    func analyzeImage(_ image: UIImage) async -> GemmaResult {
        isAnalyzing = true
        defer { isAnalyzing = false }

        // Simulate model inference latency
        try? await Task.sleep(for: .seconds(1.2))

        // TODO: Replace with Gemma 4 Core ML inference
        // This mock returns randomized but realistic data for development.
        let mockFoods: [(type: String, grams: Double, reason: WasteReason)] = [
            ("Banana", 120, .spoiled),
            ("Leftover Pasta", 250, .leftover),
            ("Chicken Breast", 180, .expired),
            ("Bread Slices", 90, .expired),
            ("Salad Mix", 150, .spoiled),
            ("Rice", 200, .overPrepared),
            ("Avocado", 170, .spoiled),
            ("Grilled Salmon", 220, .overCooked),
            ("Yogurt", 175, .expired),
            ("Pizza Slices", 300, .leftover),
            ("Broccoli", 130, .spoiled),
            ("Milk", 240, .expired),
        ]

        let mock = mockFoods.randomElement()!
        let gramsVariation = Double.random(in: -30...30)
        let confidence = Double.random(in: 0.72...0.96)

        return GemmaResult(
            foodType: mock.type,
            estimatedGrams: max(50, mock.grams + gramsVariation),
            wasteReason: mock.reason,
            confidence: confidence
        )
    }
}
