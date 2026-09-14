import SwiftUI

public struct WindowSwitcherView: View {
    @Bindable private var windowManager = WindowManager.shared
    
    public init() {}
    
    private var colsCount: Int {
        let count = max(1, windowManager.windows.count)
        if count <= 4 { return count }
        if count <= 8 { return 4 }
        return 5
    }
    
    private var gridColumns: [GridItem] {
        return Array(repeating: GridItem(.fixed(172), spacing: 12), count: colsCount)
    }
    
    public var body: some View {
        ZStack(alignment: .center) {
            VStack(spacing: 12) {
                headerView
                
                if windowManager.windows.isEmpty {
                    emptyStateView
                } else {
                    gridView
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color(red: 0.12, green: 0.12, blue: 0.14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .animation(.spring(response: 0.30, dampingFraction: 0.8), value: windowManager.windows.count)
    }
    
    private var headerView: some View {
        HStack {
            Image(systemName: "macwindow.on.rectangle")
                .font(.system(size: 13.5, weight: .bold))
                .foregroundColor(Color(red: 0.11, green: 0.84, blue: 0.38))
            
            Text("Pencere Değiştirici (Alt + Tab)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            Spacer(minLength: 16)
            
            Text("\(windowManager.windows.count) açık pencere")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.65))
        }
        .padding(.horizontal, 4)
        .padding(.top, 2)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "macwindow.badge.plus")
                .font(.system(size: 30))
                .foregroundColor(.white.opacity(0.3))
            Text("Açık uygulama penceresi bulunamadı")
                .font(.system(size: 12.5))
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(width: 280, height: 130)
    }
    
    private var gridView: some View {
        LazyVGrid(columns: gridColumns, spacing: 12) {
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
            .padding(7)
            .frame(width: 172)
            .background(isSelected ? Color(red: 0.20, green: 0.20, blue: 0.23) : Color(red: 0.15, green: 0.15, blue: 0.17))
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? emeraldColor : Color.white.opacity(0.06), lineWidth: isSelected ? 2 : 1)
            )
            .shadow(color: isSelected ? emeraldColor.opacity(0.35) : Color.black.opacity(0.35), radius: isSelected ? 10 : 2, y: 2)
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
        .frame(height: 108)
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
