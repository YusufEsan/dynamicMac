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
            let expandedWidth: CGFloat = 780
            let expandedHeight: CGFloat = 300
            let expandedRect = CGRect(
                x: screenFrame.midX - (expandedWidth / 2.0),
                y: screenFrame.maxY - expandedHeight,
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
        let canvasHeight: CGFloat = 340
        
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
        panel.level = NSWindow.Level(Int(CGWindowLevelForKey(.maximumWindow)))
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
    
    @MainActor
    public func repositionWindow() {
        guard let window = self.window, let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let canvasWidth: CGFloat = 780
        let canvasHeight: CGFloat = 340
        let screenFrame = screen.frame
        let x = screenFrame.midX - (canvasWidth / 2.0)
        let y = screenFrame.maxY - canvasHeight
        window.setFrame(NSRect(x: x, y: y, width: canvasWidth, height: canvasHeight), display: true)
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
