import UIKit
import AVFoundation
import CoreMedia
import simd

class CameraIntrinsicsViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {

    private let captureSession = AVCaptureSession()
    private lazy var previewLayer: AVCaptureVideoPreviewLayer = {
        let layer = AVCaptureVideoPreviewLayer(session: self.captureSession)
        layer.videoGravity = .resizeAspectFill
        return layer
    }()
    private let videoDataOutputQueue = DispatchQueue(label: "VideoDataOutputQueue",
                                                     qos: .userInitiated,
                                                     attributes: [],
                                                     autoreleaseFrequency: .workItem)

    // MARK: - Running average storage
    private var intrinsicSum = matrix_float3x3(0)
    private var intrinsicCount: Float = 0

    // MARK: - UI Label for displaying matrices
    private let intrinsicsLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.textColor = .yellow
        label.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        label.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        label.layer.cornerRadius = 8
        label.layer.masksToBounds = true
        label.textAlignment = .left
        return label
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCaptureSession()

        view.layer.addSublayer(previewLayer)
        view.addSubview(intrinsicsLabel)
        intrinsicsLabel.frame = CGRect(x: 10, y: 50, width: view.bounds.width - 20, height: 150)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.startRunning()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer.frame = view.bounds
        intrinsicsLabel.frame = CGRect(x: 10, y: 50, width: view.bounds.width - 20, height: 150)
    }

    func setupCaptureSession() {
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .hd1920x1080
        
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                        for: .video,
                                                        position: .back),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice)
        else { fatalError("Camera unavailable") }

        guard captureSession.canAddInput(videoInput) else { fatalError("Cannot add input") }
        captureSession.addInput(videoInput)

        let videoDataOutput = AVCaptureVideoDataOutput()
        videoDataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
        guard captureSession.canAddOutput(videoDataOutput) else { fatalError("Cannot add output") }
        captureSession.addOutput(videoDataOutput)

        if let connection = videoDataOutput.connection(with: .video),
           connection.isCameraIntrinsicMatrixDeliverySupported {
            connection.isCameraIntrinsicMatrixDeliveryEnabled = true
        }

        captureSession.commitConfiguration()
    }

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {

        guard let intrinsicData =
                CMGetAttachment(sampleBuffer,
                                key: kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix,
                                attachmentModeOut: nil) as? Data else { return }

        let intrinsicMatrix: matrix_float3x3 = intrinsicData.withUnsafeBytes {
            $0.load(as: matrix_float3x3.self)
        }

        // Update running average
        intrinsicSum += intrinsicMatrix
        intrinsicCount += 1
        let avgMatrix = intrinsicSum * (1.0 / intrinsicCount)

        // Format for display
        let text = """
        Current:
        \(matrixString(intrinsicMatrix))

        Average:
        \(matrixString(avgMatrix))
        """

        DispatchQueue.main.async {
            self.intrinsicsLabel.text = text
        }
    }

    private func matrixString(_ m: matrix_float3x3) -> String {
        return String(
            format: "[%.1f, %.1f, %.1f]\n[%.1f, %.1f, %.1f]\n[%.1f, %.1f, %.1f]",
            m[0][0], m[0][1], m[0][2],
            m[1][0], m[1][1], m[1][2],
            m[2][0], m[2][1], m[2][2]
        )
    }
}
