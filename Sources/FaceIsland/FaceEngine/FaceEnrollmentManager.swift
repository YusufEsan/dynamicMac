import Foundation
import Vision
import CoreImage
import AppKit

public enum EnrollmentStep: Int, CaseIterable {
    case front = 0
    case left = 1
    case right = 2
    case completed = 3
    
    public var prompt: String {
        switch self {
        case .front: return "Look directly into the FaceTime camera"
        case .left: return "Turn your head slightly to the left"
        case .right: return "Turn your head slightly to the right"
        case .completed: return "Face ID Enrollment Complete!"
        }
    }
}

@Observable
public final class FaceEnrollmentManager: NSObject, CameraManagerDelegate {
    public static let shared = FaceEnrollmentManager()
    
    public var currentStep: EnrollmentStep = .front
    public var isEnrolling: Bool = false
    public var capturedSamples: [FaceEmbedding] = []
    public var progress: Double = 0.0
    public var statusMessage: String = ""
    public var latestPreviewImage: NSImage? = nil
    
    private var isCapturingSample = false
    private let ciContext = CIContext(options: [
        .useSoftwareRenderer: false,
        .priorityRequestLow: false
    ])
    private var lastPreviewTime: TimeInterval = 0
    private let analysisQueue = DispatchQueue(label: "com.faceisland.enrollmentAnalysis", qos: .userInteractive)
    
    public override init() {
        super.init()
    }
    
    public func startEnrollment() {
        capturedSamples.removeAll()
        currentStep = .front
        progress = 0.0
        isEnrolling = true
        statusMessage = currentStep.prompt
        
        CameraManager.shared.delegate = self
        CameraManager.shared.startCapture()
        AppLogger.info("Starting Face ID enrollment wizard...", category: .faceID)
    }
    
    public func cancelEnrollment() {
        isEnrolling = false
        CameraManager.shared.stopCapture()
        capturedSamples.removeAll()
        latestPreviewImage = nil
        progress = 0.0
    }
    
    public func cameraManager(_ manager: CameraManager, didOutput pixelBuffer: CVPixelBuffer) {
        guard isEnrolling, !isCapturingSample else { return }
        
        let now = ProcessInfo.processInfo.systemUptime
        // Render smooth 25 FPS preview with hardware GPU acceleration
        if now - lastPreviewTime > 0.04 {
            lastPreviewTime = now
            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            if let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) {
                let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: 320, height: 240))
                DispatchQueue.main.async {
                    self.latestPreviewImage = nsImage
                }
            }
        }
        
        analysisQueue.async { [weak self] in
            guard let self = self, self.isEnrolling, !self.isCapturingSample else { return }
            
            let landmarksRequest = VNDetectFaceLandmarksRequest()
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
            
            do {
                try handler.perform([landmarksRequest])
                guard let results = landmarksRequest.results, let face = results.first else {
                    DispatchQueue.main.async {
                        if self.currentStep != .completed {
                            self.statusMessage = "Yüzünüzü kamera alanına hizalayın"
                        }
                    }
                    return
                }
                
                if let embedding = FaceEmbedding.from(observation: face) {
                    self.isCapturingSample = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                        self.processSample(embedding)
                        self.isCapturingSample = false
                    }
                }
            } catch {
                AppLogger.error("Enrollment frame analysis failed: \(error)", category: .faceID)
            }
        }
    }
    
    private func processSample(_ embedding: FaceEmbedding) {
        capturedSamples.append(embedding)
        let totalSteps = EnrollmentStep.allCases.count - 1
        let nextRaw = currentStep.rawValue + 1
        
        progress = Double(capturedSamples.count) / Double(totalSteps)
        
        if nextRaw < totalSteps {
            currentStep = EnrollmentStep(rawValue: nextRaw) ?? .completed
            statusMessage = currentStep.prompt
        } else {
            currentStep = .completed
            statusMessage = currentStep.prompt
            progress = 1.0
            finishEnrollment()
        }
    }
    
    private func finishEnrollment() {
        FaceRecognitionManager.shared.saveEnrolledFaces(capturedSamples)
        AppLogger.info("Saved \(capturedSamples.count) Face ID embeddings to secure store", category: .faceID)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            self.isEnrolling = false
            CameraManager.shared.stopCapture()
        }
    }
}
