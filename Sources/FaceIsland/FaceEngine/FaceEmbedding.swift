import Foundation
import Vision
import CoreGraphics

public struct FaceEmbedding: Codable, Equatable {
    public let vector: [Float]
    public let enrolledAt: Date
    public let label: String
    
    public init(vector: [Float], enrolledAt: Date = Date(), label: String = "Primary Face") {
        self.vector = vector
        self.enrolledAt = enrolledAt
        self.label = label
    }
    
    /// Calculate cosine similarity between two feature vectors (0.0 to 1.0)
    public func similarity(with other: FaceEmbedding) -> Float {
        guard vector.count == other.vector.count, !vector.isEmpty else { return 0 }
        
        var dotProduct: Float = 0.0
        var normA: Float = 0.0
        var normB: Float = 0.0
        
        for i in 0..<vector.count {
            let a = vector[i]
            let b = other.vector[i]
            dotProduct += a * b
            normA += a * a
            normB += b * b
        }
        
        let denom = sqrt(normA) * sqrt(normB)
        guard denom > 0 else { return 0 }
        return max(0.0, min(1.0, dotProduct / denom))
    }
    
    /// Extract normalized landmark points vector from VNFaceObservation
    public static func from(observation: VNFaceObservation) -> FaceEmbedding? {
        guard let landmarks = observation.landmarks else { return nil }
        
        var points: [Float] = []
        
        // Extract key facial landmark points
        let regions: [VNFaceLandmarkRegion2D?] = [
            landmarks.allPoints,
            landmarks.leftEye,
            landmarks.rightEye,
            landmarks.nose,
            landmarks.innerLips,
            landmarks.outerLips,
            landmarks.leftEyebrow,
            landmarks.rightEyebrow,
            landmarks.faceContour
        ]
        
        for region in regions {
            if let reg = region {
                for i in 0..<reg.pointCount {
                    let pt = reg.normalizedPoints[i]
                    points.append(Float(pt.x))
                    points.append(Float(pt.y))
                }
            }
        }
        
        guard points.count >= 20 else { return nil }
        
        // Normalize the vector length
        var norm: Float = 0.0
        for p in points { norm += p * p }
        norm = sqrt(norm)
        if norm > 0 {
            points = points.map { $0 / norm }
        }
        
        return FaceEmbedding(vector: points)
    }
}
