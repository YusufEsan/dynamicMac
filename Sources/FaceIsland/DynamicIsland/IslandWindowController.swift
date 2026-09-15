import AppKit
import SwiftUI

public final class IslandPanel: NSPanel {
    public override var canBecomeKey: Bool {
        return true
    }
    
    public override var canBecomeMain: Bool {
        return true
    }
}

public final class IslandWindowController {
    public static let shared = IslandWindowController()
    
    private var globalClickMonitor: Any?
    
    public var window: IslandPanel?
    
    private init() {
        setupClickMonitors()
    }
    
    private func setupClickMonitors() {
        if globalClickMonitor == nil {
            globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { _ in
                IslandWindowController.handleScreenClick()
            }
        }
    }
    
    @discardableResult
    public static func handleScreenClick() -> Bool {
        guard let window = IslandWindowController.shared.window, window.isVisible, !SettingsManager.shared.forceFloatingCapsule else { return false }
        let mouseLoc = NSEvent.mouseLocation
        guard let screen = window.screen ?? NSScreen.main ?? NSScreen.screens.first else { return false }
        let screenFrame = screen.frame
        
        let provider = IslandContentProvider.shared
        if case .expanded = provider.expansionState {
            let windowFrame = window.frame
            let expandedWidth: CGFloat = 780
            let expandedHeight: CGFloat = 380
            let expandedRect = CGRect(
                x: windowFrame.origin.x + (windowFrame.width - expandedWidth) / 2.0,
                y: windowFrame.maxY - expandedHeight,
                width: expandedWidth,
                height: expandedHeight
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
        let y = screenFrame.maxY - canvasHeight
        
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
        panel.hidesOnDeactivate = false
        panel.canHide = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.ignoresMouseEvents = false
        panel.becomesKeyOnlyIfNeeded = false
        panel.acceptsMouseMovedEvents = true
        
        panel.contentView = IslandHostingView(rootView: IslandView(isTopAttached: true), isTopAttached: true)
        
        self.window = panel
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        
        repositionWindow()
    }
    
    private var slideTimer: Timer?
    
    @MainActor
    public func repositionWindow(animate: Bool = true) {
        guard let window = self.window, let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let canvasWidth: CGFloat = 780
        let canvasHeight: CGFloat = 380
        let screenFrame = screen.frame
        
        let targetX: CGFloat
        switch SettingsManager.shared.notchAlignment {
        case .left:
            targetX = screenFrame.minX + 16
        case .right:
            targetX = screenFrame.maxX - canvasWidth - 16
        case .center:
            targetX = screenFrame.midX - (canvasWidth / 2.0)
        }
        let y = screenFrame.maxY - canvasHeight
        let targetFrame = NSRect(x: targetX, y: y, width: canvasWidth, height: canvasHeight)
        
        if animate && window.isVisible && abs(window.frame.origin.x - targetX) > 1.0 {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.32
                context.timingFunction = CAMediaTimingFunction(controlPoints: 0.175, 0.885, 0.32, 1.275)
                context.allowsImplicitAnimation = true
                window.animator().setFrame(targetFrame, display: true)
            }
        } else {
            window.setFrame(targetFrame, display: true)
        }
    }
    
    @objc private func screenParametersChanged() {
        DispatchQueue.main.async {
            self.repositionWindow()
        }
    }
    
    public func show() {
        DispatchQueue.main.async {
            if self.window == nil { self.setupWindow() }
            self.repositionWindow()
            self.window?.orderFrontRegardless()
        }
    }
    
    public func hide() {
        DispatchQueue.main.async {
            self.window?.orderOut(nil)
        }
    }
}
