import AppKit
import SwiftUI

public final class IslandFlippedView: NSView {
    public override var isFlipped: Bool { return true }
}

public final class IslandHostingView<Content: View>: NSHostingView<Content> {
    public var isTopAttached: Bool = true
    
    public init(rootView: Content, isTopAttached: Bool = true) {
        self.isTopAttached = isTopAttached
        super.init(rootView: rootView)
        disableAutoSizing()
    }
    
    @MainActor required dynamic init(rootView: Content) {
        self.isTopAttached = true
        super.init(rootView: rootView)
        disableAutoSizing()
    }
    
    @MainActor required dynamic init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /// Prevent NSHostingView from auto-resizing the window.
    /// We manage window frame manually in IslandWindowController/FloatingCapsuleController.
    private func disableAutoSizing() {
        if #available(macOS 13.0, *) {
            self.sizingOptions = []
        }
    }
    
    /// Return no intrinsic size so AppKit doesn't try to fit the window to content.
    public override var intrinsicContentSize: NSSize {
        return NSSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric)
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
        let isExpanded: Bool = {
            if case .expanded = provider.expansionState { return true }
            return false
        }()
        
        if isExpanded {
            let width = max(provider.currentVisualWidth, bounds.width)
            let height = max(provider.currentVisualHeight, bounds.height)
            let rectX = (bounds.width - width) / 2.0
            let rectY = self.isFlipped ? 0 : (bounds.height - height)
            let islandRect = CGRect(x: rectX, y: rectY, width: width, height: height)
            if islandRect.contains(localPoint) {
                return super.hitTest(point) ?? self
            }
            return nil
        } else {
            if bounds.contains(localPoint) {
                return super.hitTest(point) ?? self
            }
            return nil
        }
    }
    
    public override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
    }
}

