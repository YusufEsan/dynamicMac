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
            globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown]) { _ in
                IslandWindowController.handleScreenClick()
            }
        }
    }
    
    @discardableResult
    public static func handleScreenClick() -> Bool {
        let mouseLoc = NSEvent.mouseLocation
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return false }
        let screenFrame = screen.frame
        
        let provider = IslandContentProvider.shared
        if case .compact = provider.expansionState {
            let notchWidth: CGFloat = 400
            let notchHeight: CGFloat = 70
            let notchRect = CGRect(
                x: screenFrame.midX - (notchWidth / 2.0),
                y: screenFrame.maxY - notchHeight,
                width: notchWidth,
                height: notchHeight
            )
            let inside = notchRect.contains(mouseLoc)
            print("🌍 [GlobalClick Notch] mouseLoc: \(mouseLoc), notchRect: \(notchRect), inside: \(inside)")
            if inside {
                print("⚡ [GlobalClick Action] Expanding to music!")
                DispatchQueue.main.async {
                    withAnimation(AnimationConstants.islandMorphSpring) {
                        provider.expansionState = .expanded(.music)
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
        panel.level = NSWindow.Level(Int(CGShieldingWindowLevel()) + 1)
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
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
