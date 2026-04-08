import Foundation
import SwiftData

@Model
final class WasteEntry {
    @Attribute(.unique) var id: UUID
    @Attribute(.externalStorage) var photoData: Data?
    var foodType: String
    var estimatedGrams: Double
    var wasteReasonRaw: String
    var confidence: Double
    var timestamp: Date
    var notes: String?

    var wasteReason: WasteReason {
        get { WasteReason(rawValue: wasteReasonRaw) ?? .other }
        set { wasteReasonRaw = newValue.rawValue }
    }

    var foodCategory: FoodCategory {
        FoodCategory.from(foodType: foodType)
    }

    var estimatedCost: Double {
        // $4 per pound ≈ $0.00882 per gram
        estimatedGrams * 0.00882
    }

    init(
        id: UUID = UUID(),
        photoData: Data? = nil,
        foodType: String,
        estimatedGrams: Double,
        wasteReason: WasteReason,
        confidence: Double,
        timestamp: Date = Date(),
        notes: String? = nil
    ) {
        self.id = id
        self.photoData = photoData
        self.foodType = foodType
        self.estimatedGrams = estimatedGrams
        self.wasteReasonRaw = wasteReason.rawValue
        self.confidence = confidence
        self.timestamp = timestamp
        self.notes = notes
    }
}
