import SwiftUI

public struct ClipboardModuleView: View {
    private var clipboardManager = ClipboardManager.shared
    @State private var selectedTab: ClipboardDeviceSource? = nil
    @State private var searchText: String = ""
    @State private var copiedItemId: UUID? = nil
    
    public init() {}
    
    private var displayedItems: [ClipboardItem] {
        var list = clipboardManager.items
        if let tab = selectedTab {
            list = list.filter { $0.source == tab }
        }
        if !searchText.isEmpty {
            list = list.filter { $0.text.localizedCaseInsensitiveContains(searchText) }
        }
        return list
    }
    
    private var gridColumns: [GridItem] {
        let count = displayedItems.count
        if count <= 1 {
            return [GridItem(.flexible())]
        } else if count == 2 {
            return [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]
        } else if count == 3 {
            return [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]
        } else {
            return [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8)
            ]
        }
    }
    
    public var body: some View {
        VStack(spacing: 8) {
            // Header Row: Filter Pills + Search + Clear All
            HStack(spacing: 8) {
                // Tümü Pill
                filterButton(title: "Tümü (\(clipboardManager.items.count))", icon: nil, isSelected: selectedTab == nil) {
                    selectedTab = nil
                }
                
                // Mac Pill
                filterButton(title: "Mac (\(clipboardManager.items.filter { $0.source == .mac }.count))", icon: "laptopcomputer", isSelected: selectedTab == .mac) {
                    selectedTab = .mac
                }
                
                // iPhone Pill
                filterButton(title: "iPhone (\(clipboardManager.items.filter { $0.source == .phone }.count))", icon: "iphone", isSelected: selectedTab == .phone) {
                    selectedTab = .phone
                }
                
                Spacer()
                
                // Search Input
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.6))
                    
                    TextField("Pano içinde ara...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11.5, weight: .medium, design: .rounded))
                        .foregroundColor(.white)
                        .frame(width: displayedItems.count <= 1 ? 120 : 150)
                    
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.10))
                .cornerRadius(8)
                
                // Clear All Button
                if !clipboardManager.items.isEmpty {
                    Button(action: {
                        withAnimation(AnimationConstants.quickInteractive) {
                            clipboardManager.clearAllNonPinned()
                        }
                    }) {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.6))
                            .padding(5)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Sabitlenmemiş geçmişi temizle")
                }
            }
            .padding(.horizontal, 2)
            
            // Content: Multi-Column Horizontal-First Flow Grid of Cards
            if displayedItems.isEmpty {
                emptyStateView
            } else {
                ScrollView(.vertical, showsIndicators: displayedItems.count > 8) {
                    LazyVGrid(columns: gridColumns, spacing: 8) {
                        ForEach(displayedItems.prefix(40)) { item in
                            clipboardCard(item: item)
                        }
                    }
                    .padding(.horizontal, 2)
                    .padding(.vertical, 2)
                }
                .frame(height: displayedItems.count <= 4 ? 74 : 154)
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }
    
    // MARK: - Clipboard Card Component
    private func clipboardCard(item: ClipboardItem) -> some View {
        let isCopied = (copiedItemId == item.id)
        
        return Button(action: {
            clipboardManager.copyToPasteboard(item: item)
            withAnimation(AnimationConstants.quickInteractive) {
                copiedItemId = item.id
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                if copiedItemId == item.id {
                    withAnimation { copiedItemId = nil }
                }
            }
        }) {
            VStack(alignment: .leading, spacing: 4) {
                // Card Header: Device icon + Device name + Delete
                HStack(spacing: 5) {
                    Image(systemName: item.source.iconName)
                        .font(.system(size: 10))
                        .foregroundColor(item.source == .phone ? .green : .blue)
                    
                    Text(item.source == .phone ? "iPhone" : "Mac")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(item.source == .phone ? .green.opacity(0.9) : .blue.opacity(0.9))
                    
                    Spacer()
                    
                    if item.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 8))
                            .foregroundColor(.yellow)
                    }
                    
                    Button(action: {
                        withAnimation(AnimationConstants.quickInteractive) {
                            clipboardManager.deleteItem(id: item.id)
                        }
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white.opacity(0.4))
                            .padding(2)
                    }
                    .buttonStyle(.plain)
                }
                
                // Text Preview
                Text(item.text)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(isCopied ? .green : .white.opacity(0.9))
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Footer
                HStack {
                    if isCopied {
                        Text("Kopyalandı! ✓")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.green)
                    } else {
                        Text("\(item.charCount) karakter")
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.45))
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        clipboardManager.togglePin(id: item.id)
                    }) {
                        Image(systemName: item.isPinned ? "star.fill" : "star")
                            .font(.system(size: 9))
                            .foregroundColor(item.isPinned ? .yellow : .white.opacity(0.3))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, minHeight: 70, maxHeight: 70)
            .background(isCopied ? Color.green.opacity(0.18) : Color.white.opacity(0.08))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isCopied ? Color.green.opacity(0.8) : Color.white.opacity(0.12), lineWidth: 1)
            )
            .scaleEffect(isCopied ? 1.03 : 1.0)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 36, height: 36)
                
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.4))
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text("Pano Geçmişi Boş")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                
                Text("Mac veya iPhone'unuzdan metin kopyaladığınızda burada görünecektir.")
                    .font(.system(size: 10.5))
                    .foregroundColor(.white.opacity(0.55))
                    .lineLimit(1)
            }
            
            Spacer()
        }
        .padding(.horizontal, 14)
        .frame(height: 70)
        .background(Color.white.opacity(0.04))
        .cornerRadius(10)
    }
    
    private func filterButton(title: String, icon: String? = nil, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: {
            withAnimation(AnimationConstants.quickInteractive) {
                action()
            }
        }) {
            HStack(spacing: 4) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 9))
                }
                Text(title)
                    .font(.system(size: 10.5, weight: isSelected ? .bold : .medium, design: .rounded))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isSelected ? Color.blue.opacity(0.35) : Color.white.opacity(0.06))
            .foregroundColor(isSelected ? .white : .white.opacity(0.7))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
