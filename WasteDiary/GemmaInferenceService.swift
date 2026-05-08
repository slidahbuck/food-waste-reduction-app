import Foundation
import UIKit
import Vision

// MARK: - MediaPipe import
// Requires MediaPipeTasksGenAI added via Swift Package Manager.
// In Xcode: File → Add Package Dependencies…
// URL: https://github.com/google-ai-edge/mediapipe-swift
// Product: MediaPipeTasksGenAI
import MediaPipeTasksGenAI

// MARK: - GemmaInferenceService

/// Runs Gemma 4 on-device via MediaPipe LLM Inference.
///
/// Model setup (one-time):
///   1. Download `gemma-4-it-cpu-int8.task` from Kaggle:
///      https://www.kaggle.com/models/google/gemma-4/tfLite/gemma-4-it-cpu-int8
///   2. Drag the `.task` file into Xcode under WasteDiary/ → ensure
///      "Add to target: WasteDiary" is checked.
///
/// The model is loaded once at init and reused for all inferences.
final class GemmaInferenceService {

    // MARK: - Constants

    private enum ModelFile {
        static let name = "gemma-4-it-cpu-int8"
        static let ext  = "task"
    }

    /// Raised by analyze(image:) when something goes wrong.
    enum InferenceError: LocalizedError {
        case modelFileNotFound
        case modelLoadFailed(Error)
        case inferenceFailed(Error)
        case unparsableResponse(String)

        var errorDescription: String? {
            switch self {
            case .modelFileNotFound:
                return "Gemma model file not found in app bundle. " +
                       "Add \(ModelFile.name).\(ModelFile.ext) to the Xcode project."
            case .modelLoadFailed(let e):
                return "Failed to load Gemma model: \(e.localizedDescription)"
            case .inferenceFailed(let e):
                return "Gemma inference failed: \(e.localizedDescription)"
            case .unparsableResponse(let raw):
                return "Could not parse Gemma response: \(raw)"
            }
        }
    }

    // MARK: - Properties

    private let llmInference: LlmInference

    // MARK: - Init

    init() throws {
        guard let modelPath = Bundle.main.path(
            forResource: ModelFile.name,
            ofType: ModelFile.ext
        ) else {
            throw InferenceError.modelFileNotFound
        }

        do {
            let options = LlmInference.Options(modelPath: modelPath)
            options.maxTokens   = 256   // JSON output is short
            options.temperature = 0.1   // Low = deterministic, structured
            options.topK        = 40
            llmInference = try LlmInference(options: options)
        } catch {
            throw InferenceError.modelLoadFailed(error)
        }
    }

    // MARK: - Public API

    /// Analyzes a food waste image and returns structured inference results.
    /// Tries multimodal (image → Gemma) first; falls back to Vision labels → Gemma text.
    func analyze(image: UIImage) async throws -> GemmaResult {
        // Attempt 1: pass the image directly to Gemma 4 (multimodal)
        if let result = try? await runMultimodal(image: image) {
            return result
        }

        // Attempt 2: Apple Vision labels → Gemma text reasoning
        return try await runVisionFallback(image: image)
    }

    // MARK: - Multimodal Path

    private func runMultimodal(image: UIImage) async throws -> GemmaResult {
        let mpImage = try MPImage(uiImage: image)

        let prompt = """
        <start_of_image>
        You are analyzing a food waste photo. Respond with ONLY valid JSON — no markdown, no explanation.

        JSON format:
        {
          "foodType": "<concise name of the food, e.g. Banana, Leftover Pasta>",
          "estimatedGrams": <integer weight estimate in grams>,
          "wasteReason": "<exactly one of: spoiled, leftover, overCooked, overPrepared, expired, other>",
          "confidence": <float 0.0–1.0>
        }
        """

        let rawResponse: String
        do {
            rawResponse = try llmInference.generateResponse(
                inputText: prompt,
                inputImages: [mpImage]
            )
        } catch {
            throw InferenceError.inferenceFailed(error)
        }

        return try parseJSON(from: rawResponse)
    }

    // MARK: - Vision Fallback Path

    private func runVisionFallback(image: UIImage) async throws -> GemmaResult {
        let labels = await extractVisionLabels(from: image)
        let labelList = labels.isEmpty ? "unknown food item" : labels.joined(separator: ", ")

        let prompt = """
        You are analyzing food waste. The photo recognition identified: \(labelList).

        Respond with ONLY valid JSON — no markdown, no explanation.

        JSON format:
        {
          "foodType": "<concise name of the primary food item>",
          "estimatedGrams": <integer weight estimate in grams>,
          "wasteReason": "<exactly one of: spoiled, leftover, overCooked, overPrepared, expired, other>",
          "confidence": <float 0.0–1.0>
        }
        """

        let rawResponse: String
        do {
            rawResponse = try llmInference.generateResponse(inputText: prompt)
        } catch {
            throw InferenceError.inferenceFailed(error)
        }

        return try parseJSON(from: rawResponse)
    }

    // MARK: - Apple Vision Labels

    private func extractVisionLabels(from image: UIImage) async -> [String] {
        guard let cgImage = image.cgImage else { return [] }

        return await withCheckedContinuation { continuation in
            let request = VNClassifyImageRequest { request, _ in
                let observations = (request.results as? [VNClassificationObservation]) ?? []
                let labels = observations
                    .filter { $0.confidence > 0.08 }
                    .prefix(6)
                    .map { $0.identifier }
                continuation.resume(returning: Array(labels))
            }
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }
    }

    // MARK: - JSON Parsing

    private func parseJSON(from text: String) throws -> GemmaResult {
        // Gemma sometimes wraps output in markdown fences — strip them.
        let cleaned = text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Extract the first {...} block
        guard
            let startIdx = cleaned.firstIndex(of: "{"),
            let endIdx   = cleaned.lastIndex(of: "}")
        else {
            throw InferenceError.unparsableResponse(text)
        }

        let jsonSlice = String(cleaned[startIdx...endIdx])

        guard
            let data = jsonSlice.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            throw InferenceError.unparsableResponse(jsonSlice)
        }

        let foodType   = json["foodType"]       as? String ?? "Unknown Food"
        let grams      = (json["estimatedGrams"] as? Double)
                      ?? (json["estimatedGrams"] as? Int).map(Double.init)
                      ?? 150.0
        let reasonStr  = json["wasteReason"]    as? String ?? "other"
        let confidence = json["confidence"]     as? Double ?? 0.7

        let reason = WasteReason(rawValue: reasonStr) ?? .other

        return GemmaResult(
            foodType: foodType,
            estimatedGrams: max(10, grams),
            wasteReason: reason,
            confidence: confidence.clamped(to: 0...1)
        )
    }
}

// MARK: - Helpers

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
