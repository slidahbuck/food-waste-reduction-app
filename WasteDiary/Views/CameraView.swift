import SwiftUI

struct CameraView: View {
    @Bindable var viewModel: WasteViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var cameraManager = CameraManager()
    @State private var capturedImage: UIImage?
    @State private var showConfirmEntry = false
    @State private var gemmaResult: GemmaResult?

    var body: some View {
        NavigationStack {
            ZStack {
                if cameraManager.authorizationDenied || !cameraManager.isCameraAvailable {
                    cameraFallbackView
                } else if let capturedImage {
                    photoPreviewView(capturedImage)
                } else {
                    cameraLiveView
                }
            }
            .navigationTitle("Log Waste")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task {
                await cameraManager.checkAuthorization()
                cameraManager.configureSession()
                cameraManager.startSession()
            }
            .onDisappear {
                cameraManager.stopSession()
            }
            .fullScreenCover(isPresented: $showConfirmEntry) {
                if let image = capturedImage, let result = gemmaResult {
                    ConfirmEntryView(
                        viewModel: viewModel,
                        image: image,
                        gemmaResult: result
                    )
                }
            }
        }
    }

    // MARK: - Camera Live View

    private var cameraLiveView: some View {
        ZStack(alignment: .bottom) {
            CameraPreview(session: cameraManager.previewLayer)
                .ignoresSafeArea()

            Button {
                Task {
                    capturedImage = await cameraManager.capturePhoto()
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(.white)
                        .frame(width: 72, height: 72)
                    Circle()
                        .stroke(.white, lineWidth: 4)
                        .frame(width: 82, height: 82)
                }
            }
            .padding(.bottom, 40)
        }
    }

    // MARK: - Photo Preview

    private func photoPreviewView(_ image: UIImage) -> some View {
        VStack(spacing: 24) {
            Spacer()

            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)

            if viewModel.isAnalyzing {
                VStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.large)
                    Text("Analyzing with Gemma...")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 16) {
                Button("Retake") {
                    capturedImage = nil
                    cameraManager.capturedImage = nil
                    cameraManager.startSession()
                }
                .buttonStyle(.bordered)

                // TODO: Replace with Gemma 4 Core ML inference trigger
                Button("Analyze") {
                    Task {
                        gemmaResult = await viewModel.analyzeImage(image)
                        showConfirmEntry = true
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isAnalyzing)
            }

            Spacer()
        }
    }

    // MARK: - Fallback UI (no camera)

    private var cameraFallbackView: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            if cameraManager.authorizationDenied {
                Text("Camera Access Denied")
                    .font(.headline)
                Text("Please enable camera access in Settings to log food waste photos.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(.borderedProminent)
            } else {
                Text("Camera Not Available")
                    .font(.headline)
                Text("Use the simulator's photo library or run on a physical device.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                // Fallback: allow mock analysis without a photo
                Button("Use Mock Photo") {
                    Task {
                        let placeholder = UIImage(systemName: "photo.fill")!
                        capturedImage = placeholder
                        gemmaResult = await viewModel.analyzeImage(placeholder)
                        showConfirmEntry = true
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
}
