import AppKit
import SwiftUI

public final class IslandHostingView<Content: View>: NSHostingView<Content> {
    public var isTopAttached: Bool = true
    
    public init(rootView: Content, isTopAttached: Bool = true) {
        self.isTopAttached = isTopAttached
        super.init(rootView: rootView)
    }
    
    @MainActor required dynamic init(rootView: Content) {
        self.isTopAttached = true
        super.init(rootView: rootView)
    }
    
    @MainActor required dynamic init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
    
    public override var acceptsFirstResponder: Bool {
        return true
    }
    
    public override func hitTest(_ point: NSPoint) -> NSView? {
        let localPoint = self.convert(point, from: nil)
        
        let provider = IslandContentProvider.shared
        let width: CGFloat = provider.currentVisualWidth
        let height: CGFloat = provider.currentVisualHeight
        let yOffset: CGFloat = isTopAttached ? 0 : 8
        let rectX: CGFloat = (bounds.width - width) / 2.0
        
        let rectY = self.isFlipped ? yOffset : (bounds.height - height - yOffset)
        let islandRect = CGRect(
            x: rectX,
            y: rectY,
            width: width,
            height: height
        )
        let isInside = islandRect.contains(localPoint)
        
        if isInside {
            return super.hitTest(point) ?? self
        }
        
        // Point is outside the visible island -> pass click directly to underlying windows/menu bar!
        return nil
    }
    
    public override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
    }
}

