import SwiftUI
import AppKit
import CoreGraphics

/// Captures the Chrome browser window showing YouTube and displays it
/// as a live feed in the notch. This avoids all WKWebView issues
/// (Error 152, ads, popups, black screen) because it simply mirrors
/// what Chrome is already showing.
final class VideoPlayerNSImageView: NSImageView {
    override var intrinsicContentSize: NSSize {
        return NSSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric)
    }
}

public struct NotchVideoPlayerView: NSViewRepresentable {
    public let videoUrl: String
    public let startTime: Double
    
    public init(videoUrl: String, startTime: Double = 0.0) {
        self.videoUrl = videoUrl
        self.startTime = startTime
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    public class Coordinator: NSObject {
        var displayTimer: Timer?
        var boundsTimer: Timer?
        var targetWindowID: CGWindowID?
        var lastBoundsData: (left: Double, top: Double, width: Double, height: Double, outerW: Double, outerH: Double, topBar: Double)?
        var lastSearchTime: Date = .distantPast
        private let searchInterval: TimeInterval = 2.0
        
        func startCapture(in imageView: NSImageView) {
            findTargetWindow()
            updateVideoBounds()
            
            // Poll video bounds every 1.5s in background
            boundsTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
                self?.updateVideoBounds()
            }
            
            // Capture at ~24fps for smooth video feel
            displayTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 24.0, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                
                // Re-find window periodically if not found
                if self.targetWindowID == nil && Date().timeIntervalSince(self.lastSearchTime) > self.searchInterval {
                    self.findTargetWindow()
                }
                
                guard let windowID = self.targetWindowID else { return }
                
                // Capture the Chrome window frame
                guard let cgImage = CGWindowListCreateImage(
                    .null,
                    .optionIncludingWindow,
                    windowID,
                    [.boundsIgnoreFraming, .nominalResolution]
                ) else {
                    // Window may have closed, clear and re-search
                    self.targetWindowID = nil
                    return
                }
                
                let fullWidth = CGFloat(cgImage.width)
                let fullHeight = CGFloat(cgImage.height)
                
                // Determine exact video crop rect
                let cropRect: CGRect
                if let b = self.lastBoundsData {
                    let scaleX = fullWidth / CGFloat(b.outerW)
                    let scaleY = fullHeight / CGFloat(b.outerH)
                    let inset = 3.0
                    let pxX = (CGFloat(b.left) + inset) * scaleX
                    let pxY = (CGFloat(b.topBar + b.top) + inset) * scaleY
                    let pxW = max(50.0, (CGFloat(b.width) - (inset * 2.0)) * scaleX)
                    let pxH = max(50.0, (CGFloat(b.height) - (inset * 2.0)) * scaleY)
                    
                    let candidate = CGRect(x: pxX, y: pxY, width: pxW, height: pxH)
                    cropRect = candidate.intersection(CGRect(x: 0, y: 0, width: fullWidth, height: fullHeight))
                } else {
                    // Smart fallback for YouTube desktop layout
                    let topChrome = min(120.0, fullHeight * 0.14)
                    let ytHeader = fullWidth > 2000 ? 112.0 : 56.0
                    let topOffset = topChrome + ytHeader
                    let videoWidth = fullWidth * 0.68
                    let videoHeight = min(videoWidth * (9.0 / 16.0), fullHeight - topOffset)
                    cropRect = CGRect(x: 20.0, y: topOffset, width: videoWidth, height: videoHeight)
                }
                
                let croppedImage: CGImage
                if let cropped = cgImage.cropping(to: cropRect) {
                    croppedImage = cropped
                } else {
                    croppedImage = cgImage
                }
                
                let nsImage = NSImage(
                    cgImage: croppedImage,
                    size: NSSize(width: croppedImage.width, height: croppedImage.height)
                )
                
                DispatchQueue.main.async {
                    imageView.image = nsImage
                }
            }
        }
        
        func updateVideoBounds() {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else { return }
                let scriptSource = """
                tell application "Google Chrome"
                    if not (exists front window) then return "none"
                    execute front window's active tab javascript "(() => {
                        const v = document.querySelector('video.html5-main-video') || document.querySelector('video');
                        if (!v) return 'none';
                        const r = v.getBoundingClientRect();
                        return [
                            Math.round(r.left),
                            Math.round(r.top),
                            Math.round(r.width),
                            Math.round(r.height),
                            Math.round(window.outerWidth),
                            Math.round(window.outerHeight),
                            Math.round(window.outerHeight - window.innerHeight)
                        ].join(',');
                    })()"
                end tell
                """
                guard let script = NSAppleScript(source: scriptSource) else { return }
                var errorInfo: NSDictionary?
                let result = script.executeAndReturnError(&errorInfo)
                if let output = result.stringValue, output != "none" && !output.isEmpty {
                    let parts = output.components(separatedBy: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
                    if parts.count >= 7 {
                        let left = parts[0]
                        let top = parts[1]
                        let width = parts[2]
                        let height = parts[3]
                        let outerW = max(100, parts[4])
                        let outerH = max(100, parts[5])
                        let topBar = parts[6]
                        
                        self.lastBoundsData = (left: left, top: top, width: width, height: height, outerW: outerW, outerH: outerH, topBar: topBar)
                    }
                }
            }
        }
        
        func findTargetWindow() {
            lastSearchTime = Date()
            
            guard let windowList = CGWindowListCopyWindowInfo(
                [.optionOnScreenOnly, .excludeDesktopElements],
                kCGNullWindowID
            ) as? [[String: Any]] else { return }
            
            // Priority 1: Find browser window with "YouTube" in title
            let browserNames = ["Google Chrome", "Chromium", "Arc", "Safari",
                              "Brave Browser", "Microsoft Edge", "Firefox",
                              "Opera", "Vivaldi"]
            
            for window in windowList {
                guard let ownerName = window[kCGWindowOwnerName as String] as? String,
                      let windowID = window[kCGWindowNumber as String] as? Int,
                      let windowTitle = window[kCGWindowName as String] as? String,
                      let layer = window[kCGWindowLayer as String] as? Int,
                      layer == 0 // Normal window layer
                else { continue }
                
                let isBrowser = browserNames.contains(where: { ownerName.contains($0) })
                let isYouTube = windowTitle.lowercased().contains("youtube") ||
                               windowTitle.lowercased().contains("youtu")
                
                if isBrowser && isYouTube {
                    self.targetWindowID = CGWindowID(windowID)
                    return
                }
            }
            
            // Priority 2: If no YouTube title found, try matching any Chrome window
            for window in windowList {
                guard let ownerName = window[kCGWindowOwnerName as String] as? String,
                      let windowID = window[kCGWindowNumber as String] as? Int,
                      let layer = window[kCGWindowLayer as String] as? Int,
                      layer == 0,
                      ownerName == "Google Chrome"
                else { continue }
                
                // Take the first Chrome window (likely the active one)
                self.targetWindowID = CGWindowID(windowID)
                return
            }
        }
        
        func stopCapture() {
            displayTimer?.invalidate()
            displayTimer = nil
            boundsTimer?.invalidate()
            boundsTimer = nil
            targetWindowID = nil
        }
    }
    
    public func makeNSView(context: Context) -> NSImageView {
        let imageView = VideoPlayerNSImageView()
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.imageAlignment = .alignCenter
        imageView.wantsLayer = true
        imageView.layer?.backgroundColor = NSColor.black.cgColor
        imageView.layer?.cornerRadius = 10
        imageView.layer?.masksToBounds = true
        imageView.layer?.contentsGravity = .resizeAspect
        
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        imageView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        imageView.setContentHuggingPriority(.defaultLow, for: .vertical)
        
        context.coordinator.startCapture(in: imageView)
        return imageView
    }
    
    public func updateNSView(_ nsView: NSImageView, context: Context) {
        // If URL changed, re-find the target window
        context.coordinator.findTargetWindow()
    }
    
    public static func dismantleNSView(_ nsView: NSImageView, coordinator: Coordinator) {
        coordinator.stopCapture()
    }
}
