import SwiftUI

struct ConfirmEntryView: View {
    @Bindable var viewModel: WasteViewModel
    @Environment(\.dismiss) private var dismiss

    let image: UIImage
    let gemmaResult: GemmaResult

    @State private var foodType: String
    @State private var estimatedGrams: Double
    @State private var wasteReason: WasteReason
    @State private var notes: String = ""
    @State private var isSaving = false

    init(viewModel: WasteViewModel, image: UIImage, gemmaResult: GemmaResult) {
        self.viewModel = viewModel
        self.image = image
        self.gemmaResult = gemmaResult
        _foodType = State(initialValue: gemmaResult.foodType)
        _estimatedGrams = State(initialValue: gemmaResult.estimatedGrams)
        _wasteReason = State(initialValue: gemmaResult.wasteReason)
    }

    var body: some View {
        NavigationStack {
            Form {
                // Photo Thumbnail
                Section {
                    HStack {
                        Spacer()
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 160, height: 160)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        Spacer()
                    }
                }
                .listRowBackground(Color.clear)

                // AI Confidence
                Section {
                    HStack {
                        Image(systemName: "brain")
                            .foregroundStyle(.accent)
                        Text("AI Confidence")
                        Spacer()
                        Text(String(format: "%.0f%%", gemmaResult.confidence * 100))
                            .foregroundStyle(.secondary)
                    }
                }

                // Editable Fields
                Section("Food Details") {
                    TextField("Food Type", text: $foodType)

                    Stepper(
                        "Weight: \(Int(estimatedGrams)) g",
                        value: $estimatedGrams,
                        in: 10...5000,
                        step: 10
                    )

                    Picker("Reason", selection: $wasteReason) {
                        ForEach(WasteReason.allCases) { reason in
                            Label(reason.displayName, systemImage: reason.icon)
                                .tag(reason)
                        }
                    }
                }

                Section("Notes (Optional)") {
                    TextField("Why was this wasted?", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                // Category Preview
                Section {
                    let category = FoodCategory.from(foodType: foodType)
                    HStack {
                        Image(systemName: category.icon)
                            .foregroundStyle(category.color)
                        Text("Category: \(category.displayName)")
                            .foregroundStyle(.secondary)
                    }
                }

                // Save Button
                Section {
                    Button {
                        saveEntry()
                    } label: {
                        HStack {
                            Spacer()
                            if isSaving {
                                ProgressView()
                            } else {
                                Label("Save Entry", systemImage: "checkmark.circle.fill")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .disabled(foodType.isEmpty || isSaving)
                }
            }
            .navigationTitle("Confirm Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func saveEntry() {
        isSaving = true
        let photoData = image.jpegData(compressionQuality: 0.7)
        viewModel.addEntry(
            photoData: photoData,
            foodType: foodType,
            estimatedGrams: estimatedGrams,
            wasteReason: wasteReason,
            confidence: gemmaResult.confidence,
            notes: notes.isEmpty ? nil : notes
        )
        dismiss()
    }
}
