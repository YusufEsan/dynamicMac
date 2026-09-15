import AppKit
import SwiftUI

public final class FloatingCapsuleController {
    public static let shared = FloatingCapsuleController()
    
    private var globalClickMonitor: Any?
    private var mouseMoveMonitor: Any?
    private var localMouseMoveMonitor: Any?
    private var isRepositioning = false
    
    public var window: IslandPanel?
    
    private init() {
        setupClickMonitors()
    }
    
    private func setupClickMonitors() {
        if globalClickMonitor == nil {
            globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { _ in
                FloatingCapsuleController.handleScreenClick()
            }
        }
    }
    
    @discardableResult
    public static func handleScreenClick() -> Bool {
        guard let window = FloatingCapsuleController.shared.window, window.isVisible, SettingsManager.shared.forceFloatingCapsule else { return false }
        let mouseLoc = NSEvent.mouseLocation
        let windowFrame = window.frame
        
        if windowFrame.insetBy(dx: -10, dy: -10).contains(mouseLoc) {
            return false
        }
        
        let provider = IslandContentProvider.shared
        if case .expanded = provider.expansionState {
            provider.collapse()
            return true
        }
        return false
    }
    
    @MainActor
    public func setupWindow() {
        guard window == nil else { return }
        
        let provider = IslandContentProvider.shared
        
        let canvasWidth: CGFloat = max(provider.currentVisualWidth, 320)
        let canvasHeight: CGFloat = max(provider.currentVisualHeight, 35)
        
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let screenFrame = screen.frame
        let x = screenFrame.midX - (canvasWidth / 2.0)
        let y = screenFrame.maxY - 70 - canvasHeight
        
        let panel = IslandPanel(
            contentRect: NSRect(x: x, y: y, width: canvasWidth, height: canvasHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.canHide = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.ignoresMouseEvents = false
        panel.becomesKeyOnlyIfNeeded = false
        panel.acceptsMouseMovedEvents = true
        
        // Wrap hosting view in a plain NSView to prevent NSHostingView from
        // auto-resizing the window (which causes recursive layout crashes).
        let hostingView = IslandHostingView(rootView: IslandView(isTopAttached: false), isTopAttached: false)
        let wrapper = IslandFlippedView(frame: NSRect(origin: .zero, size: NSSize(width: canvasWidth, height: canvasHeight)))
        wrapper.wantsLayer = true
        wrapper.layer?.backgroundColor = .clear
        hostingView.frame = wrapper.bounds
        hostingView.autoresizingMask = [.width, .height]
        wrapper.addSubview(hostingView)
        panel.contentView = wrapper
        
        self.window = panel
        
        IslandContentProvider.shared.onStateChanged = { [weak self] _ in
            guard let self = self, !self.isRepositioning else { return }
            DispatchQueue.main.async {
                self.repositionWindow(animate: true)
            }
        }
        
        repositionWindow(animate: false)
    }
    
    @MainActor
    public func repositionWindow(animate: Bool = true) {
        guard !isRepositioning else { return }
        guard let window = self.window, let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        isRepositioning = true
        defer { isRepositioning = false }
        let provider = IslandContentProvider.shared
        
        let canvasWidth: CGFloat = max(provider.currentVisualWidth, 320)
        let canvasHeight: CGFloat = max(provider.currentVisualHeight, 35)
        let screenFrame = screen.frame
        let x = screenFrame.midX - (canvasWidth / 2.0)
        let y = screenFrame.maxY - 70 - canvasHeight
        let targetFrame = NSRect(x: x, y: y, width: canvasWidth, height: canvasHeight)
        
        if animate && window.isVisible && (abs(window.frame.width - canvasWidth) > 1.0 || abs(window.frame.height - canvasHeight) > 1.0) {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.28
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                context.allowsImplicitAnimation = true
                window.animator().setFrame(targetFrame, display: true)
            }
        } else {
            window.setFrame(targetFrame, display: true)
        }
    }
    
    public func show() {
        DispatchQueue.main.async {
            if self.window == nil { self.setupWindow() }
            self.repositionWindow(animate: false)
            self.window?.orderFrontRegardless()
        }
    }
    
    public func hide() {
        DispatchQueue.main.async {
            self.window?.orderOut(nil)
        }
    }
    
    public func toggle() {
        if window?.isVisible == true {
            hide()
        } else {
            show()
        }
    }
}
