import UIKit
import AVFoundation
import CoreMedia
import simd

class CameraIntrinsicsViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {

    // The AVCaptureSession is the central hub for the camera.
    private let captureSession = AVCaptureSession()
    
    // The AVCaptureVideoPreviewLayer displays the live camera feed on the screen.
    private lazy var previewLayer: AVCaptureVideoPreviewLayer = {
        let layer = AVCaptureVideoPreviewLayer(session: self.captureSession)
        layer.videoGravity = .resizeAspectFill
        return layer
    }()

    // The queue to process video frames on a background thread.
    private let videoDataOutputQueue = DispatchQueue(label: "VideoDataOutputQueue",
                                                     qos: .userInitiated,
                                                     attributes: [],
                                                     autoreleaseFrequency: .workItem)
    
    // MARK: - View Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCaptureSession()
        
        // Add the preview layer to the view so the camera feed is visible.
        view.layer.addSublayer(previewLayer)
        
        // Start the session on a background thread.
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            self.captureSession.startRunning()
            print("Capture session started. Look for the intrinsic matrix in the logs.")
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Ensure the preview layer fills the entire screen.
        previewLayer.frame = view.bounds
    }

    // MARK: - Capture Session Setup

    func setupCaptureSession() {
        // Begin configuring the capture session.
        captureSession.beginConfiguration()
        
        // Set the session preset for a specific quality level.
        captureSession.sessionPreset = .hd1920x1080
        
        // Select the back wide-angle camera.
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                        for: .video,
                                                        position: .back) else {
            fatalError("No back camera found")
        }
        
        // Create video input from the device.
        guard let videoInput = try? AVCaptureDeviceInput(device: videoDevice) else {
            fatalError("Could not create video input")
        }
        
        // Add the input to the session.
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        } else {
            fatalError("Cannot add video input")
        }
        
        // Setup video data output to receive frames.
        let videoDataOutput = AVCaptureVideoDataOutput()
        videoDataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
        
        // Add the output to the session.
        if captureSession.canAddOutput(videoDataOutput) {
            captureSession.addOutput(videoDataOutput)
        } else {
            fatalError("Cannot add video data output")
        }
        
        // Enable intrinsic matrix delivery if supported.
        if let connection = videoDataOutput.connection(with: .video),
           connection.isCameraIntrinsicMatrixDeliverySupported {
            connection.isCameraIntrinsicMatrixDeliveryEnabled = true
        } else {
            print("Camera intrinsic matrix delivery not supported on this device/configuration.")
        }
        
        // Commit the configuration changes.
        captureSession.commitConfiguration()
    }
    
    // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

    // This delegate method is called for each video frame.
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        // Get the intrinsic matrix from the sample buffer metadata.
        guard let intrinsicData = CMGetAttachment(sampleBuffer, key: kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, attachmentModeOut: nil) as? Data else {
            // No intrinsic matrix found for this frame. This can be normal.
            return
        }
        
        // The intrinsic matrix is stored as a Data object. We convert it to the correct matrix type.
        let intrinsicMatrix: matrix_float3x3 = intrinsicData.withUnsafeBytes {
            $0.load(as: matrix_float3x3.self)
        }
        
        // Print the result on the main queue to avoid cluttering the background queue.
        DispatchQueue.main.async {
            print("---")
            print("Camera Intrinsic Matrix:")
            print(intrinsicMatrix)
        }
    }
}

