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
        let isExp: Bool
        if case .expanded = provider.expansionState { isExp = true } else { isExp = false }
        
        let width: CGFloat = isExp ? 780 : 380
        let height: CGFloat = isExp ? 270 : 44
        let yOffset: CGFloat = isTopAttached ? 0 : 2
        
        // In IslandHostingView coordinates: y=0 is at the top edge of the island, and height=44 covers the compact capsule
        let islandRect = CGRect(
            x: (bounds.width - width) / 2.0,
            y: yOffset,
            width: width,
            height: height
        )
        let isInside = islandRect.contains(localPoint)
        
        print("🎯 [HitTest] localPoint: \(localPoint), islandRect: \(islandRect), inside: \(isInside), isExp: \(isExp)")
        fflush(stdout)
        
        if isInside {
            let res = super.hitTest(point) ?? self
            print("🎯 [HitTest Result] -> returning: \(type(of: res))")
            fflush(stdout)
            return res
        }
        
        // Point is outside the visible island -> pass click directly to underlying windows/menu bar!
        return nil
    }
    
    public override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
    }
}
