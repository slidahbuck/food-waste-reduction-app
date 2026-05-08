import Foundation
@preconcurrency import SwiftData
import SwiftUI
import UIKit

struct WasteSuggestion: Identifiable {
    let id = UUID()
    let title: String
    let body: String
    let icon: String
}

@Observable
@MainActor
final class WasteViewModel {
    private var modelContext: ModelContext

    var entries: [WasteEntry] = []
    var receiptEntries: [ReceiptEntry] = []
    var isAnalyzing = false
    var selectedTab: Int = 0
    var suggestions: [WasteSuggestion] = []
    var isLoadingSuggestions = false
    var suggestionError: String? = nil
    private var gemmaService: GemmaInferenceService?

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        do {
            gemmaService = try GemmaInferenceService()
        } catch {
            print("[WasteViewModel] Gemma init error: \(error.localizedDescription)")
        }
        fetchEntries()
        fetchReceiptEntries()
    }

    // MARK: - Waste CRUD

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
        let descriptor = FetchDescriptor<WasteEntry>()
        entries = ((try? modelContext.fetch(descriptor)) ?? [])
            .sorted { $0.timestamp > $1.timestamp }
    }

    // MARK: - Receipt CRUD

    func addReceiptEntry(storeName: String, items: [ReceiptItem], total: Double, confidence: Double, photoData: Data?) {
        let itemsData = (try? JSONEncoder().encode(items)) ?? Data()
        let entry = ReceiptEntry(storeName: storeName, itemsData: itemsData, total: total, confidence: confidence, photoData: photoData)
        modelContext.insert(entry)
        save()
        fetchReceiptEntries()
    }

    func deleteReceiptEntry(_ entry: ReceiptEntry) {
        modelContext.delete(entry)
        save()
        fetchReceiptEntries()
    }

    func fetchReceiptEntries() {
        let descriptor = FetchDescriptor<ReceiptEntry>()
        receiptEntries = ((try? modelContext.fetch(descriptor)) ?? [])
            .sorted { $0.timestamp > $1.timestamp }
    }

    // MARK: - Receipt Analytics

    var thisWeekReceiptEntries: [ReceiptEntry] {
        let startOfWeek = Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        return receiptEntries.filter { $0.timestamp >= startOfWeek }
    }

    var thisWeekReceiptTotal: Double {
        thisWeekReceiptEntries.reduce(0) { $0 + $1.total }
    }

    /// Percentage of grocery spend that was wasted this week (capped at 100%).
    var thisWeekWasteRatio: Double {
        guard thisWeekReceiptTotal > 0 else { return 0 }
        return min(thisWeekTotalCost / thisWeekReceiptTotal, 1.0)
    }

    var weeklySpendVsWaste: [(day: Date, spent: Double, wasted: Double)] {
        let calendar = Calendar.current
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: Date()) else { return [] }
        var result: [(day: Date, spent: Double, wasted: Double)] = []
        var current = weekInterval.start
        while current < weekInterval.end && current <= Date() {
            let day = current
            let nextDay = calendar.date(byAdding: .day, value: 1, to: day) ?? day
            let spent = receiptEntries
                .filter { $0.timestamp >= day && $0.timestamp < nextDay }
                .reduce(0) { $0 + $1.total }
            let wasted = entries
                .filter { $0.timestamp >= day && $0.timestamp < nextDay }
                .reduce(0) { $0 + $1.estimatedCost }
            result.append((day: day, spent: spent, wasted: wasted))
            current = nextDay
        }
        return result
    }

    var weeklyWasteByDay: [(day: Date, grams: Double)] {
        let calendar = Calendar.current
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: Date()) else { return [] }
        var result: [(day: Date, grams: Double)] = []
        var current = weekInterval.start
        while current < weekInterval.end && current <= Date() {
            let day = current
            let nextDay = calendar.date(byAdding: .day, value: 1, to: day) ?? day
            let dayGrams = entries
                .filter { $0.timestamp >= day && $0.timestamp < nextDay }
                .reduce(0) { $0 + $1.estimatedGrams }
            result.append((day: day, grams: dayGrams))
            current = nextDay
        }
        return result
    }

    var weeklyReceiptChartData: [(day: Date, total: Double)] {
        let calendar = Calendar.current
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: Date()) else { return [] }
        var result: [(day: Date, total: Double)] = []
        var current = weekInterval.start
        while current < weekInterval.end && current <= Date() {
            let day = current
            let nextDay = calendar.date(byAdding: .day, value: 1, to: day) ?? day
            let dayTotal = receiptEntries
                .filter { $0.timestamp >= day && $0.timestamp < nextDay }
                .reduce(0) { $0 + $1.total }
            result.append((day: day, total: dayTotal))
            current = nextDay
        }
        return result
    }

    var receiptEntriesGroupedByDay: [(date: Date, entries: [ReceiptEntry])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: receiptEntries) { calendar.startOfDay(for: $0.timestamp) }
        return grouped.sorted { $0.key > $1.key }.map { (date: $0.key, entries: $0.value) }
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

    // MARK: - Suggestions

    func loadSuggestions() async {
        guard let service = gemmaService else {
            suggestionError = "API key not configured. Add your key to APIKeys.swift."
            return
        }
        isLoadingSuggestions = true
        suggestionError = nil
        defer { isLoadingSuggestions = false }

        let topFoods = Dictionary(grouping: entries, by: { $0.foodType })
            .sorted { $0.value.count > $1.value.count }
            .prefix(3)
            .map { $0.key }
            .joined(separator: ", ")

        let topReason = Dictionary(grouping: thisWeekEntries, by: { $0.wasteReason.displayName })
            .max(by: { $0.value.count < $1.value.count })?.key ?? "various reasons"

        let context = """
        - Food wasted this week: \(String(format: "%.0f", thisWeekTotalGrams))g (est. $\(String(format: "%.2f", thisWeekTotalCost)))
        - Grocery spending this week: $\(String(format: "%.2f", thisWeekReceiptTotal))
        - Waste ratio: \(String(format: "%.0f", thisWeekWasteRatio * 100))% of grocery spend wasted
        - Most wasted foods (all time): \(topFoods.isEmpty ? "none logged yet" : topFoods)
        - Most common waste reason this week: \(topReason)
        - Logging streak: \(loggingStreak) days
        """

        do {
            suggestions = try await service.generateSuggestions(context: context)
        } catch {
            print("[WasteViewModel] Suggestions error: \(error.localizedDescription)")
            suggestionError = error.localizedDescription
        }
    }

    // MARK: - Gemma Inference

    func analyzeReceipt(_ image: UIImage) async -> ReceiptResult {
        isAnalyzing = true
        defer { isAnalyzing = false }

        guard let service = gemmaService else {
            return ReceiptResult(storeName: "Model Not Loaded", items: [], total: 0, confidence: 0.0)
        }

        do {
            return try await service.analyzeReceipt(image: image)
        } catch {
            print("[WasteViewModel] Receipt inference error: \(error.localizedDescription)")
            return ReceiptResult(storeName: "Analysis Failed", items: [], total: 0, confidence: 0.0)
        }
    }

    func analyzeImage(_ image: UIImage) async -> GemmaResult {
        isAnalyzing = true
        defer { isAnalyzing = false }

        guard let service = gemmaService else {
            return GemmaResult(
                foodType: "Model Not Loaded",
                estimatedGrams: 150,
                wasteReason: .other,
                confidence: 0.0
            )
        }

        do {
            return try await service.analyze(image: image)
        } catch {
            print("[WasteViewModel] Inference error: \(error.localizedDescription)")
            return GemmaResult(
                foodType: "Analysis Failed",
                estimatedGrams: 150,
                wasteReason: .other,
                confidence: 0.0
            )
        }
    }
}
