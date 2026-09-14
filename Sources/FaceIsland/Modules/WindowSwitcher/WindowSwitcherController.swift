import AppKit
import SwiftUI
import CoreGraphics

public final class WindowSwitcherController {
    public static let shared = WindowSwitcherController()
    
    private var window: NSPanel?
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    public var isVisible: Bool = false
    
    private init() {}
    
    @MainActor
    public func setup() {
        setupPanel()
        setupEventTap()
    }
    
    @MainActor
    private func setupPanel() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 920, height: 420),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = false
        
        let hostingView = NSHostingView(rootView: WindowSwitcherView())
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        panel.contentView = hostingView
        panel.center()
        self.window = panel
    }
    
    public func setupEventTap() {
        let eventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.flagsChanged.rawValue)
        
        let callback: CGEventTapCallBack = { proxy, type, event, refcon in
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            let flags = event.flags
            let isOptionDown = flags.contains(.maskAlternate)
            let isCommandDown = flags.contains(.maskCommand)
            let isShiftDown = flags.contains(.maskShift)
            
            // Key Code 48 is 'Tab'
            if type == .keyDown && keyCode == 48 && (isOptionDown || isCommandDown) {
                DispatchQueue.main.async {
                    if !WindowSwitcherController.shared.isVisible {
                        WindowSwitcherController.shared.show()
                    } else {
                        if isShiftDown {
                            WindowManager.shared.selectPrevious()
                        } else {
                            WindowManager.shared.selectNext()
                        }
                    }
                }
                return nil
            }
            
            // ESC key while visible
            if type == .keyDown && keyCode == 53 && WindowSwitcherController.shared.isVisible {
                DispatchQueue.main.async {
                    WindowSwitcherController.shared.hide()
                }
                return nil
            }
            
            // Return / Enter key while visible
            if type == .keyDown && keyCode == 36 && WindowSwitcherController.shared.isVisible {
                DispatchQueue.main.async {
                    let win = WindowManager.shared.selectedWindow
                    WindowSwitcherController.shared.hide()
                    if let win = win {
                        WindowManager.shared.activateWindow(win)
                    }
                }
                return nil
            }
            
            // Modifiers released -> Activate selected window
            if type == .flagsChanged && WindowSwitcherController.shared.isVisible {
                if !isOptionDown && !isCommandDown {
                    DispatchQueue.main.async {
                        let win = WindowManager.shared.selectedWindow
                        WindowSwitcherController.shared.hide()
                        if let win = win {
                            WindowManager.shared.activateWindow(win)
                        }
                    }
                }
            }
            
            return Unmanaged.passRetained(event)
        }
        
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: callback,
            userInfo: nil
        ) else {
            return
        }
        
        self.eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }
    
    public func show() {
        DispatchQueue.main.async {
            if self.window == nil { self.setupPanel() }
            WindowManager.shared.refreshWindows()
            self.window?.center()
            self.window?.orderFrontRegardless()
            self.isVisible = true
        }
    }
    
    public func hide() {
        DispatchQueue.main.async {
            self.window?.orderOut(nil)
            self.isVisible = false
        }
    }
    
    public func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }
}
