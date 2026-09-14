import SwiftUI

public struct IslandSquircle: Shape {
    public var cornerRadius: CGFloat
    public var isTopAttached: Bool
    
    public init(cornerRadius: CGFloat = 20, isTopAttached: Bool = true) {
        self.cornerRadius = cornerRadius
        self.isTopAttached = isTopAttached
    }
    
    public func path(in rect: CGRect) -> Path {
        var path = Path()
        
        if isTopAttached {
            let topWingRadius: CGFloat = 12
            
            // Top left wing (inverted curve to screen bezel)
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addQuadCurve(
                to: CGPoint(x: rect.minX + topWingRadius, y: rect.minY + topWingRadius),
                control: CGPoint(x: rect.minX + topWingRadius, y: rect.minY)
            )
            
            // Left edge down
            path.addLine(to: CGPoint(x: rect.minX + topWingRadius, y: rect.maxY - cornerRadius))
            
            // Bottom left rounded corner
            path.addQuadCurve(
                to: CGPoint(x: rect.minX + topWingRadius + cornerRadius, y: rect.maxY),
                control: CGPoint(x: rect.minX + topWingRadius, y: rect.maxY)
            )
            
            // Bottom edge
            path.addLine(to: CGPoint(x: rect.maxX - topWingRadius - cornerRadius, y: rect.maxY))
            
            // Bottom right rounded corner
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX - topWingRadius, y: rect.maxY - cornerRadius),
                control: CGPoint(x: rect.maxX - topWingRadius, y: rect.maxY)
            )
            
            // Right edge up
            path.addLine(to: CGPoint(x: rect.maxX - topWingRadius, y: rect.minY + topWingRadius))
            
            // Top right wing (inverted curve to screen bezel)
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: rect.minY),
                control: CGPoint(x: rect.maxX - topWingRadius, y: rect.minY)
            )
            
            path.closeSubpath()
        } else {
            path.addRoundedRect(in: rect, cornerSize: CGSize(width: cornerRadius, height: cornerRadius))
        }
        
        return path
    }
}

public struct IslandSquircleBorder: Shape {
    public var cornerRadius: CGFloat
    public var isTopAttached: Bool
    
    public init(cornerRadius: CGFloat = 20, isTopAttached: Bool = true) {
        self.cornerRadius = cornerRadius
        self.isTopAttached = isTopAttached
    }
    
    public func path(in rect: CGRect) -> Path {
        var path = Path()
        
        if isTopAttached {
            let topWingRadius: CGFloat = 12
            
            // Start at top left wing
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addQuadCurve(
                to: CGPoint(x: rect.minX + topWingRadius, y: rect.minY + topWingRadius),
                control: CGPoint(x: rect.minX + topWingRadius, y: rect.minY)
            )
            
            // Left edge down
            path.addLine(to: CGPoint(x: rect.minX + topWingRadius, y: rect.maxY - cornerRadius))
            
            // Bottom left rounded corner
            path.addQuadCurve(
                to: CGPoint(x: rect.minX + topWingRadius + cornerRadius, y: rect.maxY),
                control: CGPoint(x: rect.minX + topWingRadius, y: rect.maxY)
            )
            
            // Bottom edge
            path.addLine(to: CGPoint(x: rect.maxX - topWingRadius - cornerRadius, y: rect.maxY))
            
            // Bottom right rounded corner
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX - topWingRadius, y: rect.maxY - cornerRadius),
                control: CGPoint(x: rect.maxX - topWingRadius, y: rect.maxY)
            )
            
            // Right edge up
            path.addLine(to: CGPoint(x: rect.maxX - topWingRadius, y: rect.minY + topWingRadius))
            
            // Top right wing (ends at maxX, minY - does NOT connect across the top)
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: rect.minY),
                control: CGPoint(x: rect.maxX - topWingRadius, y: rect.minY)
            )
        } else {
            path.addRoundedRect(in: rect, cornerSize: CGSize(width: cornerRadius, height: cornerRadius))
        }
        
        return path
    }
}
