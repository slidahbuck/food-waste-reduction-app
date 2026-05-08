@preconcurrency import AVFoundation
import SwiftUI
import UIKit

@Observable
@MainActor
final class CameraManager: NSObject {
    var capturedImage: UIImage?
    var isAuthorized = false
    var authorizationDenied = false
    var isCameraAvailable = false

    private let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private var continuation: CheckedContinuation<UIImage?, Never>?

    override init() {
        super.init()
        isCameraAvailable = UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    // MARK: - Authorization

    func checkAuthorization() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isAuthorized = true
        case .notDetermined:
            isAuthorized = await AVCaptureDevice.requestAccess(for: .video)
            authorizationDenied = !isAuthorized
        default:
            isAuthorized = false
            authorizationDenied = true
        }
    }

    // MARK: - Session

    func configureSession() {
        guard isAuthorized, isCameraAvailable else { return }

        session.beginConfiguration()
        session.sessionPreset = .photo

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: camera),
              session.canAddInput(input) else {
            session.commitConfiguration()
            return
        }

        session.addInput(input)

        guard session.canAddOutput(photoOutput) else {
            session.commitConfiguration()
            return
        }

        session.addOutput(photoOutput)
        session.commitConfiguration()
    }

    func startSession() {
        guard !session.isRunning, isAuthorized, isCameraAvailable else { return }
        let session = self.session
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }

    func stopSession() {
        guard session.isRunning else { return }
        let session = self.session
        DispatchQueue.global(qos: .userInitiated).async {
            session.stopRunning()
        }
    }

    var previewLayer: AVCaptureSession {
        session
    }

    // MARK: - Capture

    func capturePhoto() async -> UIImage? {
        guard isAuthorized, isCameraAvailable else { return nil }

        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            let settings = AVCapturePhotoSettings()
            photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }
}

nonisolated extension CameraManager: AVCapturePhotoCaptureDelegate {
    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        let imageData = photo.fileDataRepresentation()
        Task { @MainActor in
            guard let data = imageData, let image = UIImage(data: data) else {
                continuation?.resume(returning: nil)
                continuation = nil
                return
            }
            capturedImage = image
            continuation?.resume(returning: image)
            continuation = nil
        }
    }
}

// MARK: - Camera Preview UIViewRepresentable

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        context.coordinator.previewLayer = previewLayer
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.previewLayer?.frame = uiView.bounds
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var previewLayer: AVCaptureVideoPreviewLayer?
    }
}
