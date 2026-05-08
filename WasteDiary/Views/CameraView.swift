import SwiftUI
import PhotosUI

struct CameraView: View {
    @Bindable var viewModel: WasteViewModel
    let scanMode: ScanMode
    @Environment(\.dismiss) private var dismiss

    @State private var cameraManager = CameraManager()
    @State private var capturedImage: UIImage?
    @State private var showConfirmEntry = false
    @State private var gemmaResult: GemmaResult?
    @State private var receiptResult: ReceiptResult?
    @State private var showConfirmReceipt = false

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isDropTargeted = false

    // Photo-picker loading state
    @State private var isSelectingPhoto = false
    @State private var loadProgress: Double = 0

    init(viewModel: WasteViewModel, scanMode: ScanMode = .wastedFood) {
        self.viewModel = viewModel
        self.scanMode = scanMode
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Show preview screen as soon as a photo is being selected,
                // even before capturedImage is available.
                if isSelectingPhoto || capturedImage != nil {
                    photoPreviewView
                } else if cameraManager.authorizationDenied || !cameraManager.isCameraAvailable {
                    cameraFallbackView
                } else {
                    cameraLiveView
                }

                if isDropTargeted {
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(.blue, lineWidth: 4)
                        .background(Color.blue.opacity(0.08).clipShape(RoundedRectangle(cornerRadius: 20)))
                        .overlay {
                            Label("Drop Photo Here", systemImage: "photo.badge.plus")
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(.blue)
                        }
                        .padding()
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                }
            }
            .navigationTitle(scanMode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    photoPickerButton
                }
            }
            .dropDestination(for: Data.self) { items, _ in
                guard let data = items.first, let image = UIImage(data: data) else { return false }
                capturedImage = image
                return true
            } isTargeted: { targeted in
                isDropTargeted = targeted
            }
            .onChange(of: selectedPhotoItem) { _, item in
                guard item != nil else { return }
                // Immediately navigate to preview screen
                isSelectingPhoto = true
                capturedImage = nil
                loadProgress = 0

                Task {
                    // Animate ring toward 85% while the actual load runs
                    withAnimation(.easeOut(duration: 0.9)) {
                        loadProgress = 0.85
                    }

                    guard
                        let data = try? await item?.loadTransferable(type: Data.self),
                        let image = UIImage(data: data)
                    else {
                        isSelectingPhoto = false
                        loadProgress = 0
                        return
                    }

                    // Snap to 100%, pause briefly so user sees it complete, then reveal
                    withAnimation(.easeOut(duration: 0.15)) {
                        loadProgress = 1.0
                    }
                    try? await Task.sleep(nanoseconds: 200_000_000)
                    withAnimation(.easeIn(duration: 0.3)) {
                        capturedImage = image
                        isSelectingPhoto = false
                    }
                }
            }
            .task {
                guard cameraManager.isCameraAvailable else { return }
                await cameraManager.checkAuthorization()
                cameraManager.configureSession()
                cameraManager.startSession()
            }
            .onDisappear {
                guard cameraManager.isCameraAvailable else { return }
                cameraManager.stopSession()
            }
            .fullScreenCover(isPresented: $showConfirmEntry) {
                if let image = capturedImage, let result = gemmaResult {
                    ConfirmEntryView(viewModel: viewModel, image: image, gemmaResult: result)
                }
            }
            .fullScreenCover(isPresented: $showConfirmReceipt) {
                if let image = capturedImage, let result = receiptResult {
                    ConfirmReceiptView(viewModel: viewModel, image: image, receiptResult: result)
                }
            }
            .onChange(of: viewModel.selectedTab) { _, tab in
                if tab == 2 { dismiss() }
            }
        }
    }

    // MARK: - Photo Picker Button

    private var photoPickerButton: some View {
        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
            Image(systemName: "photo.on.rectangle")
        }
    }

    // MARK: - Camera Live View

    private var cameraLiveView: some View {
        ZStack(alignment: .bottom) {
            CameraPreview(session: cameraManager.previewLayer)
                .ignoresSafeArea()

            Button {
                Task { capturedImage = await cameraManager.capturePhoto() }
            } label: {
                ZStack {
                    Circle().fill(.white).frame(width: 72, height: 72)
                    Circle().stroke(.white, lineWidth: 4).frame(width: 82, height: 82)
                }
            }
            .padding(.bottom, 40)
        }
    }

    // MARK: - Photo Preview

    private var photoPreviewView: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                if let image = capturedImage {
                    // Fully loaded — show in color
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .transition(.opacity.combined(with: .scale(scale: 0.97)))
                } else {
                    // Still loading — gray placeholder with progress ring
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(uiColor: .systemGray5))
                        .aspectRatio(4/3, contentMode: .fit)
                        .overlay {
                            CircularProgressView(progress: loadProgress)
                        }
                }
            }
            .padding(.horizontal)
            .animation(.easeInOut(duration: 0.3), value: capturedImage != nil)

            if viewModel.isAnalyzing {
                VStack(spacing: 12) {
                    ProgressView().controlSize(.large)
                    Text(scanMode.analyzingLabel)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 16) {
                Button("Retake") {
                    capturedImage = nil
                    isSelectingPhoto = false
                    loadProgress = 0
                    cameraManager.capturedImage = nil
                    cameraManager.startSession()
                }
                .buttonStyle(.bordered)
                .disabled(isSelectingPhoto)

                Button(scanMode.analyzeButtonLabel) {
                    guard let image = capturedImage else { return }
                    Task {
                        switch scanMode {
                        case .wastedFood:
                            gemmaResult = await viewModel.analyzeImage(image)
                            showConfirmEntry = true
                        case .receipt:
                            receiptResult = await viewModel.analyzeReceipt(image)
                            showConfirmReceipt = true
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isAnalyzing || isSelectingPhoto)
            }

            Spacer()
        }
    }

    // MARK: - Fallback UI (no camera)

    private var cameraFallbackView: some View {
        VStack(spacing: 20) {
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

                VStack(spacing: 8) {
                    Image(systemName: "arrow.down.doc")
                        .font(.system(size: 32))
                        .foregroundStyle(.blue)
                    Text("Drag a photo here from Finder\nor use the photo picker above")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8]))
                        .foregroundStyle(.blue.opacity(0.4))
                )
            }
        }
        .padding()
    }
}

// MARK: - Circular Progress View

private struct CircularProgressView: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.25), lineWidth: 7)
                .frame(width: 72, height: 72)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(.tint, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .frame(width: 72, height: 72)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut, value: progress)

            Text("\(Int(progress * 100))%")
                .font(.callout.weight(.semibold))
                .monospacedDigit()
                .contentTransition(.numericText())
        }
    }
}
