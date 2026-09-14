import SwiftUI

public struct ModuleTabBar: View {
    @Bindable private var provider = IslandContentProvider.shared
    
    public init() {}
    
    public var body: some View {
        HStack(spacing: 8) {
            ForEach(IslandModuleType.allCases) { module in
                let isSelected = (provider.activeModule == module)
                
                Button(action: {
                    withAnimation(AnimationConstants.islandMorphSpring) {
                        provider.selectModule(module)
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: module.iconName)
                            .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                        
                        if isSelected {
                            Text(module.rawValue)
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .transition(.opacity.combined(with: .scale))
                        }
                    }
                    .padding(.horizontal, isSelected ? 10 : 8)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(isSelected ? Color.blue.opacity(0.35) : Color.white.opacity(0.08))
                    )
                    .overlay(
                        Capsule()
                            .stroke(isSelected ? Color.blue.opacity(0.6) : Color.clear, lineWidth: 1)
                    )
                    .foregroundColor(isSelected ? .white : .white.opacity(0.65))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
}
