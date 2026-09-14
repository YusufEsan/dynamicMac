import Foundation
import AppKit
import CoreGraphics

@Observable
public final class WindowManager {
    public static let shared = WindowManager()
    
    public var windows: [WindowItem] = []
    public var selectedIndex: Int = 0
    private var isRefreshing = false
    
    private init() {}
    
    public func refreshWindows() {
        guard !isRefreshing else { return }
        isRefreshing = true
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            defer { self?.isRefreshing = false }
            
            let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
            guard let infoList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
                return
            }
            
            var list: [WindowItem] = []
            
            for dict in infoList {
                guard let layer = dict[kCGWindowLayer as String] as? Int, layer == 0,
                      let windowId = dict[kCGWindowNumber as String] as? CGWindowID,
                      let pid = dict[kCGWindowOwnerPID as String] as? pid_t,
                      let ownerName = dict[kCGWindowOwnerName as String] as? String else {
                    continue
                }
                
                if ownerName == "FaceIsland" || ownerName == "Dock" || ownerName == "Window Server" {
                    continue
                }
                
                let title = (dict[kCGWindowName as String] as? String) ?? ownerName
                
                var boundsRect = CGRect.zero
                if let boundsDict = dict[kCGWindowBounds as String] as? [String: Any] {
                    boundsRect = CGRect(
                        x: boundsDict["X"] as? CGFloat ?? 0,
                        y: boundsDict["Y"] as? CGFloat ?? 0,
                        width: boundsDict["Width"] as? CGFloat ?? 0,
                        height: boundsDict["Height"] as? CGFloat ?? 0
                    )
                }
                
                guard boundsRect.width > 50, boundsRect.height > 50 else { continue }
                
                let runningApp = NSRunningApplication(processIdentifier: pid)
                let icon = runningApp?.icon
                
                var thumbnailImage: NSImage? = nil
                if let cgImage = CGWindowListCreateImage(
                    .null,
                    .optionIncludingWindow,
                    windowId,
                    [.boundsIgnoreFraming]
                ) {
                    thumbnailImage = NSImage(cgImage: cgImage, size: NSSize(width: boundsRect.width, height: boundsRect.height))
                }
                
                list.append(WindowItem(
                    id: windowId,
                    processIdentifier: pid,
                    appName: ownerName,
                    windowTitle: title,
                    bounds: boundsRect,
                    thumbnail: thumbnailImage,
                    appIcon: icon
                ))
            }
            
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.windows = list
                if self.selectedIndex >= list.count {
                    self.selectedIndex = 0
                }
            }
        }
    }
    
    public var selectedWindow: WindowItem? {
        guard !windows.isEmpty, selectedIndex >= 0, selectedIndex < windows.count else { return nil }
        return windows[selectedIndex]
    }
    
    public func selectNext() {
        guard !windows.isEmpty else { return }
        selectedIndex = (selectedIndex + 1) % windows.count
    }
    
    public func selectPrevious() {
        guard !windows.isEmpty else { return }
        selectedIndex = (selectedIndex - 1 + windows.count) % windows.count
    }
    
    public func activateSelected() {
        guard let selected = selectedWindow else { return }
        activateWindow(selected)
    }
    
    public func activateWindow(_ window: WindowItem) {
        let pid = window.processIdentifier
        let winTitle = window.windowTitle
        let appName = window.appName
        
        DispatchQueue.main.async {
            // 1. Activate the owning application
            if let app = NSRunningApplication(processIdentifier: pid) {
                app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
            }
            
            // 2. Bring specific window to front using Accessibility API
            DispatchQueue.global(qos: .userInteractive).async {
                let appRef = AXUIElementCreateApplication(pid)
                
                // Mark app as frontmost
                AXUIElementSetAttributeValue(appRef, kAXFrontmostAttribute as CFString, kCFBooleanTrue)
                
                var windowsRef: AnyObject?
                if AXUIElementCopyAttributeValue(appRef, kAXWindowsAttribute as CFString, &windowsRef) == .success,
                   let axWindows = windowsRef as? [AXUIElement], !axWindows.isEmpty {
                    
                    var matched = false
                    for axWin in axWindows {
                        var titleRef: AnyObject?
                        if AXUIElementCopyAttributeValue(axWin, kAXTitleAttribute as CFString, &titleRef) == .success,
                           let title = titleRef as? String {
                            if title == winTitle || winTitle.contains(title) || title.contains(winTitle) {
                                AXUIElementPerformAction(axWin, kAXRaiseAction as CFString)
                                AXUIElementSetAttributeValue(axWin, kAXMainAttribute as CFString, kCFBooleanTrue)
                                AXUIElementSetAttributeValue(axWin, kAXFocusedAttribute as CFString, kCFBooleanTrue)
                                matched = true
                                break
                            }
                        }
                    }
                    
                    if !matched, let firstWin = axWindows.first {
                        AXUIElementPerformAction(firstWin, kAXRaiseAction as CFString)
                        AXUIElementSetAttributeValue(firstWin, kAXMainAttribute as CFString, kCFBooleanTrue)
                        AXUIElementSetAttributeValue(firstWin, kAXFocusedAttribute as CFString, kCFBooleanTrue)
                    }
                } else {
                    // Fallback to AppleScript activation
                    let script = "tell application \"\(appName)\" to activate"
                    var error: NSDictionary?
                    if let scriptObj = NSAppleScript(source: script) {
                        scriptObj.executeAndReturnError(&error)
                    }
                }
            }
        }
    }
}
