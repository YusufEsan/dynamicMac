import AVFoundation
import CoreImage
import AppKit

public protocol CameraManagerDelegate: AnyObject {
    func cameraManager(_ manager: CameraManager, didOutput pixelBuffer: CVPixelBuffer)
}

public final class CameraManager: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    public static let shared = CameraManager()
    
    public weak var delegate: CameraManagerDelegate?
    
    private let captureSession = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.faceisland.cameraSessionQueue")
    private var isSessionRunning = false
    
    public override init() {
        super.init()
    }
    
    public func startCapture() {
        sessionQueue.async { [weak self] in
            guard let self = self, !self.isSessionRunning else { return }
            
            self.captureSession.beginConfiguration()
            self.captureSession.sessionPreset = .vga640x480
            
            guard let videoDevice = AVCaptureDevice.default(for: .video) else {
                AppLogger.error("No FaceTime camera device found", category: .faceID)
                self.captureSession.commitConfiguration()
                return
            }
            
            do {
                let videoInput = try AVCaptureDeviceInput(device: videoDevice)
                if self.captureSession.canAddInput(videoInput) {
                    self.captureSession.addInput(videoInput)
                }
                
                let dataOutput = AVCaptureVideoDataOutput()
                dataOutput.alwaysDiscardsLateVideoFrames = true
                dataOutput.videoSettings = [
                    (kCVPixelBufferPixelFormatTypeKey as String): Int(kCVPixelFormatType_32BGRA)
                ]
                dataOutput.setSampleBufferDelegate(self, queue: self.sessionQueue)
                
                if self.captureSession.canAddOutput(dataOutput) {
                    self.captureSession.addOutput(dataOutput)
                }
                
                self.captureSession.commitConfiguration()
                self.captureSession.startRunning()
                self.isSessionRunning = self.captureSession.isRunning
                AppLogger.info("Camera capture started successfully", category: .faceID)
            } catch {
                AppLogger.error("Failed to start camera: \(error.localizedDescription)", category: .faceID)
                self.captureSession.commitConfiguration()
            }
        }
    }
    
    public func stopCapture() {
        sessionQueue.async { [weak self] in
            guard let self = self, self.isSessionRunning else { return }
            self.captureSession.stopRunning()
            self.isSessionRunning = false
            AppLogger.info("Camera capture stopped", category: .faceID)
        }
    }
    
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        delegate?.cameraManager(self, didOutput: pixelBuffer)
    }
}
