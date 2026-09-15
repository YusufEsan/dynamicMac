import Foundation
import Vision
import CoreImage
import AppKit

public enum FaceMatchState: Equatable {
    case idle
    case scanning(progress: Double)
    case recognized(confidence: Float)
    case notRecognized
    case noFaceDetected
    case cameraUnavailable
}

@Observable
public final class FaceRecognitionManager: NSObject, CameraManagerDelegate {
    public static let shared = FaceRecognitionManager()
    
    public var currentState: FaceMatchState = .idle
    public var lastMatchScore: Float = 0.0
    public var isScanning: Bool = false
    public var recognitionThreshold: Float = 0.78
    
    public var isRecognized: Bool {
        if case .recognized = currentState { return true }
        return false
    }
    
    public static let faceRecognizedNotification = Notification.Name("FaceIsland_FaceRecognized")
    
    public var onFaceRecognized: ((Float) -> Void)?
    public var onScanFailed: (() -> Void)?
    
    private var sequenceHandler = VNSequenceRequestHandler()
    private var enrolledEmbeddings: [FaceEmbedding] = []
    private var scanStartTime: Date?
    private let scanTimeout: TimeInterval = 4.0
    private var consecutiveMatches: Int = 0
    private let requiredConsecutiveMatches: Int = 2
    
    private override init() {
        super.init()
        loadEnrolledFaces()
    }
    
    public func loadEnrolledFaces() {
        if let data = UserDefaults.standard.data(forKey: "FaceIsland_EnrolledEmbeddings"),
           let embeddings = try? JSONDecoder().decode([FaceEmbedding].self, from: data) {
            self.enrolledEmbeddings = embeddings
        }
    }
    
    public func saveEnrolledFaces(_ embeddings: [FaceEmbedding]) {
        self.enrolledEmbeddings = embeddings
        if let data = try? JSONEncoder().encode(embeddings) {
            UserDefaults.standard.set(data, forKey: "FaceIsland_EnrolledEmbeddings")
        }
    }
    
    public var isEnrolled: Bool {
        return !enrolledEmbeddings.isEmpty
    }
    
    public func startRecognition() {
        guard isEnrolled else {
            currentState = .notRecognized
            return
        }
        
        guard PermissionManager.shared.cameraGranted else {
            currentState = .cameraUnavailable
            return
        }
        
        isScanning = true
        consecutiveMatches = 0
        scanStartTime = Date()
        currentState = .scanning(progress: 0.1)
        WidgetSharedState.shared.updateFaceIDState(isScanning: true, isRecognized: false, statusText: "Yüz Taranıyor...")
        
        CameraManager.shared.delegate = self
        CameraManager.shared.startCapture()
        AppLogger.info("Starting Face ID recognition scan...", category: .faceID)
    }
    
    public func stopRecognition() {
        isScanning = false
        CameraManager.shared.stopCapture()
        if case .scanning = currentState {
            currentState = .idle
            WidgetSharedState.shared.updateFaceIDState(isScanning: false, isRecognized: false, statusText: "Face ID Hazır")
        }
    }
    
    public func cameraManager(_ manager: CameraManager, didOutput pixelBuffer: CVPixelBuffer) {
        guard isScanning else { return }
        
        // Check timeout
        if let start = scanStartTime, Date().timeIntervalSince(start) > scanTimeout {
            DispatchQueue.main.async {
                self.stopRecognition()
                self.currentState = .notRecognized
                WidgetSharedState.shared.updateFaceIDState(isScanning: false, isRecognized: false, statusText: "Yüz Tanınamadı")
                self.onScanFailed?()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) {
                    if case .notRecognized = self.currentState {
                        self.currentState = .idle
                        WidgetSharedState.shared.updateFaceIDState(isScanning: false, isRecognized: false, statusText: "Face ID Hazır")
                    }
                }
            }
            return
        }
        
        let landmarksRequest = VNDetectFaceLandmarksRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        
        do {
            try handler.perform([landmarksRequest])
            
            guard let results = landmarksRequest.results, let primaryFace = results.first else {
                DispatchQueue.main.async {
                    if case .scanning = self.currentState {
                        self.currentState = .scanning(progress: 0.3)
                    }
                }
                return
            }
            
            if let embedding = FaceEmbedding.from(observation: primaryFace) {
                var maxScore: Float = 0.0
                for enrolled in enrolledEmbeddings {
                    let score = embedding.similarity(with: enrolled)
                    if score > maxScore {
                        maxScore = score
                    }
                }
                
                DispatchQueue.main.async {
                    self.lastMatchScore = maxScore
                    if maxScore >= self.recognitionThreshold {
                        self.consecutiveMatches += 1
                        if self.consecutiveMatches >= self.requiredConsecutiveMatches {
                            self.currentState = .recognized(confidence: maxScore)
                            self.stopRecognition()
                            WidgetSharedState.shared.updateFaceIDState(isScanning: false, isRecognized: true, statusText: "Kilit Açıldı")
                            AppLogger.info("Face recognized with confidence: \(maxScore)", category: .faceID)
                            self.onFaceRecognized?(maxScore)
                            NotificationCenter.default.post(
                                name: FaceRecognitionManager.faceRecognizedNotification,
                                object: self,
                                userInfo: ["confidence": maxScore]
                            )
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                                if case .recognized = self.currentState {
                                    self.currentState = .idle
                                    WidgetSharedState.shared.updateFaceIDState(isScanning: false, isRecognized: false, statusText: "Face ID Hazır")
                                }
                            }
                        } else {
                            self.currentState = .scanning(progress: 0.8)
                        }
                    } else {
                        self.currentState = .scanning(progress: 0.5)
                    }
                }
            }
        } catch {
            AppLogger.error("Vision request failed: \(error.localizedDescription)", category: .faceID)
        }
    }
}
