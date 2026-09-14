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
            // Unified Dark Card-Themed Background
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(red: 0.12, green: 0.12, blue: 0.14))
                .shadow(color: .black.opacity(0.50), radius: 24, x: 0, y: 12)
            
            VStack(spacing: 14) {
                headerView
                
                if windowManager.windows.isEmpty {
                    emptyStateView
                } else {
                    gridView
                }
            }
            .padding(16)
        }
        .frame(minWidth: 620, maxWidth: 960)
        .padding(10)
    }
    
    private var headerView: some View {
        HStack {
            Image(systemName: "macwindow.on.rectangle")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Color(red: 0.11, green: 0.84, blue: 0.38))
            
            Text("Pencere Değiştirici (Alt + Tab)")
                .font(.system(size: 13.5, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            Spacer()
            
            Text("\(windowManager.windows.count) açık pencere")
                .font(.system(size: 11.5, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.65))
        }
        .padding(.horizontal, 6)
        .padding(.top, 2)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "macwindow.badge.plus")
                .font(.system(size: 32))
                .foregroundColor(.white.opacity(0.3))
            Text("Açık uygulama penceresi bulunamadı")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity, minHeight: 160)
    }
    
    private var gridView: some View {
        LazyVGrid(columns: gridColumns, spacing: 14) {
            ForEach(Array(windowManager.windows.enumerated()), id: \.element.id) { index, win in
                WindowSwitcherCard(
                    window: win,
                    isSelected: index == windowManager.selectedIndex,
                    isCurrent: index == 0,
                    onSelect: {
                        windowManager.selectedIndex = index
                        WindowSwitcherController.shared.hide()
                        windowManager.activateWindow(win)
                    },
                    onHover: {
                        windowManager.selectedIndex = index
                    }
                )
            }
        }
        .padding(.horizontal, 2)
        .padding(.bottom, 4)
    }
}

private struct WindowSwitcherCard: View {
    let window: WindowItem
    let isSelected: Bool
    let isCurrent: Bool
    let onSelect: () -> Void
    let onHover: () -> Void
    
    private let emeraldColor = Color(red: 0.11, green: 0.84, blue: 0.38)
    
    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 6) {
                thumbnailArea
                labelArea
            }
            .padding(8)
            .background(isSelected ? Color(red: 0.20, green: 0.20, blue: 0.23) : Color(red: 0.16, green: 0.16, blue: 0.18))
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? emeraldColor : Color.white.opacity(0.06), lineWidth: isSelected ? 2 : 1)
            )
            .shadow(color: isSelected ? emeraldColor.opacity(0.35) : Color.black.opacity(0.40), radius: isSelected ? 10 : 3, y: 2)
            .scaleEffect(isSelected ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            if hovering {
                withAnimation(.easeInOut(duration: 0.12)) {
                    onHover()
                }
            }
        }
    }
    
    private var thumbnailArea: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.black.opacity(0.50))
            
            if let thumb = window.thumbnail {
                Image(nsImage: thumb)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .cornerRadius(7)
            } else {
                Image(systemName: "macwindow")
                    .font(.system(size: 30))
                    .foregroundColor(.white.opacity(0.3))
            }
            
            if isCurrent {
                currentBadge
            }
            
            if let icon = window.appIcon {
                appIconOverlay(icon: icon)
            }
        }
        .frame(height: 110)
    }
    
    private var currentBadge: some View {
        VStack {
            HStack {
                Text("Mevcut")
                    .font(.system(size: 8.5, weight: .bold, design: .rounded))
                    .foregroundColor(isSelected ? emeraldColor : .white.opacity(0.85))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(isSelected ? emeraldColor.opacity(0.20) : Color.white.opacity(0.12))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(isSelected ? emeraldColor.opacity(0.50) : Color.white.opacity(0.18), lineWidth: 0.8)
                    )
                    .padding(5)
                Spacer()
            }
            Spacer()
        }
    }
    
    private func appIconOverlay(icon: NSImage) -> some View {
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
    
    private var labelArea: some View {
        VStack(spacing: 1.5) {
            Text(window.appName)
                .font(.system(size: 11.5, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
            
            Text(window.windowTitle)
                .font(.system(size: 9.5, weight: .regular))
                .foregroundColor(isSelected ? emeraldColor : .white.opacity(0.60))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
}
