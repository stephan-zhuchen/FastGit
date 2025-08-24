//
//  SidebarNavigationView.swift
//  FastGit
//
//  Created by FastGit Team
//

import SwiftUI

/// 侧边栏导航选项
enum SidebarNavigationOption: String, CaseIterable {
    case history = "历史"
    case changes = "修改"
    case branches = "分支"
    case stash = "Stash"
    
    /// 图标名称
    var iconName: String {
        switch self {
        case .history:
            return "clock.arrow.circlepath"
        case .changes:
            return "doc.text.below.ecg"
        case .branches:
            return "point.3.connected.trianglepath.dotted"
        case .stash:
            return "tray.full"
        }
    }
    
    /// 是否已实现
    var isImplemented: Bool {
        switch self {
        case .history:
            return true
        case .changes, .branches, .stash:
            return false
        }
    }
}

/// 侧边栏功能导航视图
struct SidebarNavigationView: View {
    @Binding var selectedOption: SidebarNavigationOption?
    
    var body: some View {
        VStack(spacing: 8) {
            // 导航标题
            HStack {
                Text("功能")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            
            // 导航按钮列表
            VStack(spacing: 4) {
                ForEach(SidebarNavigationOption.allCases, id: \.self) { option in
                    NavigationButton(
                        option: option,
                        isSelected: selectedOption == option,
                        action: {
                            if option.isImplemented {
                                selectedOption = option
                            } else {
                                // 暂未实现的功能，显示提示
                                print("⚠️ \(option.rawValue)功能暂未实现")
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 8)
            
            Spacer()
        }
        .frame(width: 200)
        .background(.regularMaterial)
    }
}

/// 导航按钮组件
private struct NavigationButton: View {
    let option: SidebarNavigationOption
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: option.iconName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(isSelected ? .white : .primary)
                    .frame(width: 20)
                
                Text(option.rawValue)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(isSelected ? .white : .primary)
                
                Spacer()
                
                // 未实现功能的标识
                if !option.isImplemented {
                    Image(systemName: "clock.badge")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        isSelected ? Color.accentColor :
                        isHovered ? Color.primary.opacity(0.08) : Color.clear
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(!option.isImplemented)
        .opacity(option.isImplemented ? 1.0 : 0.6)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering && option.isImplemented
            }
        }
    }
}

#Preview {
    SidebarNavigationView(selectedOption: .constant(.history))
        .frame(height: 400)
}