import Foundation

enum WasteReason: String, CaseIterable, Identifiable, Codable {
    case spoiled
    case leftover
    case overCooked
    case overPrepared
    case expired
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .spoiled: "Spoiled"
        case .leftover: "Leftover"
        case .overCooked: "Over-Cooked"
        case .overPrepared: "Over-Prepared"
        case .expired: "Expired"
        case .other: "Other"
        }
    }

    var icon: String {
        switch self {
        case .spoiled: "leaf.fill"
        case .leftover: "fork.knife"
        case .overCooked: "flame.fill"
        case .overPrepared: "chart.bar.fill"
        case .expired: "clock.fill"
        case .other: "questionmark.circle.fill"
        }
    }
}
