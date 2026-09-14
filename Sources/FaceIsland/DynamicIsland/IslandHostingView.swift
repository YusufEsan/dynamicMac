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
        
        let width: CGFloat = isExp ? 780 : 420
        let height: CGFloat = isExp ? 290 : 65
        
        // In NSHostingView coordinate system, y = 0 is at the top edge of the window!
        let islandRect = CGRect(x: (bounds.width - width) / 2.0, y: 0, width: width, height: height)
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
        let localPoint = self.convert(event.locationInWindow, from: nil)
        print("🖱️ [MouseDown] localPoint: \(localPoint), windowLoc: \(event.locationInWindow)")
        fflush(stdout)
        
        let provider = IslandContentProvider.shared
        let isExp: Bool
        if case .expanded = provider.expansionState { isExp = true } else { isExp = false }
        
        if !isExp {
            print("⚡ [MouseDown Action] Triggering expand to music!")
            fflush(stdout)
            DispatchQueue.main.async {
                withAnimation(AnimationConstants.islandMorphSpring) {
                    provider.expansionState = .expanded(.music)
                }
            }
            return
        }
        super.mouseDown(with: event)
    }
}
