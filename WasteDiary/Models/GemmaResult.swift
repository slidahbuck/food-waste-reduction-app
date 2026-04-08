import Foundation

/// Result returned by the Gemma on-device inference model.
/// // TODO: Replace with Gemma 4 Core ML inference output type
struct GemmaResult {
    let foodType: String
    let estimatedGrams: Double
    let wasteReason: WasteReason
    let confidence: Double
}
