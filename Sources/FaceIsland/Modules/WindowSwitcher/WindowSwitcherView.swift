import SwiftUI

public struct WindowSwitcherView: View {
    @Bindable private var windowManager = WindowManager.shared
    
    public init() {}
    
    private var gridColumns: [GridItem] {
        let count = max(1, windowManager.windows.count)
        let cols = count <= 3 ? count : (count <= 8 ? 4 : 5)
        return Array(repeating: GridItem(.flexible(minimum: 140, maximum: 200), spacing: 14), count: cols)
    }
    
    public var body: some View {
        ZStack {
            // Dark Frosted Glass Background
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.28), Color.white.opacity(0.04), Color.blue.opacity(0.25)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.2
                        )
                )
                .shadow(color: .black.opacity(0.75), radius: 35, x: 0, y: 15)
            
            VStack(spacing: 14) {
                // Header
                HStack {
                    Image(systemName: "macwindow.on.rectangle")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.blue)
                    Text("Pencere Değiştirici (Alt + Tab)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Spacer()
                    Text("\(windowManager.windows.count) açık pencere")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.65))
                }
                .padding(.horizontal, 22)
                .padding(.top, 16)
                
                // All Windows Grid (No clipping, all visible at once)
                if windowManager.windows.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "macwindow.badge.plus")
                            .font(.system(size: 32))
                            .foregroundColor(.white.opacity(0.3))
                        Text("Açık uygulama penceresi bulunamadı")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity, minHeight: 160)
                } else {
                    LazyVGrid(columns: gridColumns, spacing: 14) {
                        ForEach(Array(windowManager.windows.enumerated()), id: \.element.id) { index, win in
                            let isSelected = (index == windowManager.selectedIndex)
                            let isCurrent = (index == 0)
                            
                            Button(action: {
                                windowManager.selectedIndex = index
                                WindowSwitcherController.shared.hide()
                                windowManager.activateWindow(win)
                            }) {
                                VStack(spacing: 6) {
                                    // Window Thumbnail Box
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(Color.black.opacity(0.65))
                                        
                                        if let thumb = win.thumbnail {
                                            Image(nsImage: thumb)
                                                .resizable()
                                                .aspectRatio(contentMode: .fit)
                                                .cornerRadius(10)
                                        } else {
                                            Image(systemName: "macwindow")
                                                .font(.system(size: 32))
                                                .foregroundColor(.white.opacity(0.3))
                                        }
                                        
                                        // "Mevcut" Badge for current window
                                        if isCurrent {
                                            VStack {
                                                HStack {
                                                    Text("Mevcut")
                                                        .font(.system(size: 8.5, weight: .bold, design: .rounded))
                                                        .foregroundColor(isSelected ? .cyan : .purple)
                                                        .padding(.horizontal, 6)
                                                        .padding(.vertical, 2)
                                                        .background(isSelected ? Color.blue.opacity(0.4) : Color.purple.opacity(0.3))
                                                        .clipShape(Capsule())
                                                        .overlay(
                                                            Capsule()
                                                                .stroke(isSelected ? Color.cyan.opacity(0.6) : Color.purple.opacity(0.6), lineWidth: 0.8)
                                                        )
                                                        .padding(5)
                                                    Spacer()
                                                }
                                                Spacer()
                                            }
                                        }
                                        
                                        // App icon floating in bottom right
                                        if let icon = win.appIcon {
                                            VStack {
                                                Spacer()
                                                HStack {
                                                    Spacer()
                                                    Image(nsImage: icon)
                                                        .resizable()
                                                        .frame(width: 22, height: 22)
                                                        .clipShape(RoundedRectangle(cornerRadius: 5))
                                                        .shadow(radius: 3)
                                                        .padding(5)
                                                }
                                            }
                                        }
                                    }
                                    .frame(height: 110)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(
                                                isSelected ?
                                                LinearGradient(colors: [Color.cyan, Color.blue], startPoint: .topLeading, endPoint: .bottomTrailing) :
                                                (isCurrent ?
                                                    LinearGradient(colors: [Color.purple.opacity(0.8), Color.indigo.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing) :
                                                    LinearGradient(colors: [Color.white.opacity(0.18), Color.white.opacity(0.04)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                                ),
                                                lineWidth: isSelected ? 2.8 : (isCurrent ? 1.8 : 1)
                                            )
                                    )
                                    .shadow(color: isSelected ? Color.blue.opacity(0.65) : (isCurrent ? Color.purple.opacity(0.4) : Color.clear), radius: isSelected ? 10 : 6, y: 2)
                                    .scaleEffect(isSelected ? 1.04 : 1.0)
                                    
                                    // Title & App Name
                                    VStack(spacing: 1.5) {
                                        Text(win.appName)
                                            .font(.system(size: 11.5, weight: .bold, design: .rounded))
                                            .foregroundColor(isSelected ? .white : (isCurrent ? Color.purple.opacity(0.95) : .white.opacity(0.9)))
                                            .lineLimit(1)
                                        
                                        Text(win.windowTitle)
                                            .font(.system(size: 9.5, weight: .regular))
                                            .foregroundColor(isSelected ? .cyan.opacity(0.9) : (isCurrent ? Color.purple.opacity(0.7) : .white.opacity(0.60)))
                                            .lineLimit(1)
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                .padding(7)
                                .background(
                                    isSelected ?
                                    LinearGradient(colors: [Color.blue.opacity(0.32), Color.blue.opacity(0.12)], startPoint: .topLeading, endPoint: .bottomTrailing) :
                                    (isCurrent ?
                                        LinearGradient(colors: [Color.purple.opacity(0.22), Color.indigo.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing) :
                                        LinearGradient(colors: [Color.white.opacity(0.05), Color.white.opacity(0.02)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                    )
                                )
                                .cornerRadius(14)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(isSelected ? Color.blue.opacity(0.6) : (isCurrent ? Color.purple.opacity(0.4) : Color.clear), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                            .onHover { isHovering in
                                if isHovering {
                                    withAnimation(.easeInOut(duration: 0.12)) {
                                        windowManager.selectedIndex = index
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.bottom, 18)
                }
            }
        }
        .frame(minWidth: 620, maxWidth: 960)
        .padding(10)
    }
}
