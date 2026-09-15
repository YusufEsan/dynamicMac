import AppKit
import SwiftUI

public final class FloatingCapsuleController {
    public static let shared = FloatingCapsuleController()
    
    private var globalClickMonitor: Any?
    private var mouseMoveMonitor: Any?
    private var localMouseMoveMonitor: Any?
    
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
        if mouseMoveMonitor == nil {
            mouseMoveMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] _ in
                self?.updateMousePassthrough()
            }
        }
        if localMouseMoveMonitor == nil {
            localMouseMoveMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
                self?.updateMousePassthrough()
                return event
            }
        }
    }
    
    public func updateMousePassthrough() {
        guard let window = self.window, window.isVisible, SettingsManager.shared.forceFloatingCapsule else { return }
        let mouseLoc = NSEvent.mouseLocation
        let windowFrame = window.frame
        
        let provider = IslandContentProvider.shared
        let activeWidth: CGFloat = provider.currentVisualWidth
        let activeHeight: CGFloat = provider.currentVisualHeight
        let topOffset: CGFloat = 8
        
        let activeRect = CGRect(
            x: windowFrame.origin.x + (windowFrame.width - activeWidth) / 2.0,
            y: windowFrame.maxY - activeHeight - topOffset,
            width: activeWidth,
            height: activeHeight
        )
        
        let isInside = activeRect.insetBy(dx: -4, dy: -4).contains(mouseLoc)
        
        if isInside {
            if window.ignoresMouseEvents {
                window.ignoresMouseEvents = false
            }
        } else {
            if !window.ignoresMouseEvents {
                window.ignoresMouseEvents = true
            }
        }
    }
    
    @discardableResult
    public static func handleScreenClick() -> Bool {
        guard let window = FloatingCapsuleController.shared.window, window.isVisible, SettingsManager.shared.forceFloatingCapsule else { return false }
        let mouseLoc = NSEvent.mouseLocation
        let windowFrame = window.frame
        let provider = IslandContentProvider.shared
        
        if case .expanded = provider.expansionState {
            let width: CGFloat = provider.currentVisualWidth
            let height: CGFloat = provider.currentVisualHeight
            let expandedRect = CGRect(
                x: windowFrame.midX - (width / 2.0),
                y: windowFrame.maxY - height - 8,
                width: width,
                height: height
            )
            if !expandedRect.contains(mouseLoc) {
                DispatchQueue.main.async {
                    withAnimation(AnimationConstants.islandMorphSpring) {
                        provider.collapse()
                    }
                }
                return true
            }
        }
        return false
    }
    
    @MainActor
    public func setupWindow() {
        guard window == nil else { return }
        
        let canvasWidth: CGFloat = 780
        let canvasHeight: CGFloat = 380
        
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
        panel.level = NSWindow.Level(Int(CGWindowLevelForKey(.screenSaverWindow)) + 2)
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
        
        panel.contentView = IslandHostingView(rootView: IslandView(isTopAttached: false), isTopAttached: false)
        
        self.window = panel
    }
    
    public func show() {
        DispatchQueue.main.async {
            if self.window == nil { self.setupWindow() }
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
