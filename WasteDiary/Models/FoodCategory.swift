import Foundation
import SwiftUI

enum FoodCategory: String, CaseIterable, Identifiable, Codable {
    case produce
    case dairy
    case meat
    case grains
    case leftovers
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .produce: "Produce"
        case .dairy: "Dairy"
        case .meat: "Meat"
        case .grains: "Grains"
        case .leftovers: "Leftovers"
        case .other: "Other"
        }
    }

    var color: Color {
        switch self {
        case .produce: .green
        case .dairy: .blue
        case .meat: .red
        case .grains: .orange
        case .leftovers: .purple
        case .other: .gray
        }
    }

    var icon: String {
        switch self {
        case .produce: "leaf.fill"
        case .dairy: "cup.and.saucer.fill"
        case .meat: "fish.fill"
        case .grains: "birthday.cake.fill"
        case .leftovers: "takeoutbag.and.cup.and.straw.fill"
        case .other: "questionmark.circle.fill"
        }
    }

    /// Derives a FoodCategory from a free-text food type string.
    static func from(foodType: String) -> FoodCategory {
        let lower = foodType.lowercased()

        let produceKeywords = ["apple", "banana", "lettuce", "tomato", "carrot", "spinach",
                               "broccoli", "avocado", "pepper", "onion", "potato", "fruit",
                               "vegetable", "salad", "berry", "grape", "orange", "cucumber",
                               "celery", "mushroom", "zucchini", "kale", "mango", "melon",
                               "peach", "pear", "strawberry", "blueberry"]
        let dairyKeywords = ["milk", "cheese", "yogurt", "cream", "butter", "ice cream",
                             "cottage", "sour cream", "whey", "curd"]
        let meatKeywords = ["chicken", "beef", "pork", "fish", "turkey", "lamb", "salmon",
                            "shrimp", "steak", "bacon", "sausage", "ham", "meat", "tuna"]
        let grainKeywords = ["bread", "rice", "pasta", "cereal", "oat", "wheat", "flour",
                             "tortilla", "noodle", "cracker", "bagel", "muffin", "grain",
                             "quinoa", "barley"]
        let leftoverKeywords = ["leftover", "takeout", "meal", "dinner", "lunch", "soup",
                                "stew", "casserole", "pizza", "sandwich"]

        if produceKeywords.contains(where: { lower.contains($0) }) { return .produce }
        if dairyKeywords.contains(where: { lower.contains($0) }) { return .dairy }
        if meatKeywords.contains(where: { lower.contains($0) }) { return .meat }
        if grainKeywords.contains(where: { lower.contains($0) }) { return .grains }
        if leftoverKeywords.contains(where: { lower.contains($0) }) { return .leftovers }

        return .other
    }
}
