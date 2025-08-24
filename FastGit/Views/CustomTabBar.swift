//
//  CustomTabBar.swift
//  FastGit
//
//  Created by FastGit Team
//

import SwiftUI

/// 自定义Tab项数据模型
struct TabItem: Identifiable, Equatable {
    let id: Int
    let title: String
    let icon: String
    let isClosable: Bool
    
    static func == (lhs: TabItem, rhs: TabItem) -> Bool {
        return lhs.id == rhs.id
    }
}

/// 浏览器风格的自定义TabBar
struct CustomTabBar: View {
    @Binding var selectedTab: Int
    let tabs: [TabItem]
    let onCloseTab: ((Int) -> Void)?
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            // Tab标签项
            ForEach(tabs) { tab in
                TabBarItem(
                    tab: tab,
                    isSelected: selectedTab == tab.id,
                    onSelect: {
                        selectedTab = tab.id
                    },
                    onClose: tab.isClosable ? {
                        onCloseTab?(tab.id)
                    } : nil
                )
            }
            
            // 右侧填充区域
            Spacer()
        }
        .background(.regularMaterial)
        .frame(height: 40)
    }
}

/// 单个Tab项组件
private struct TabBarItem: View {
    let tab: TabItem
    let isSelected: Bool
    let onSelect: () -> Void
    let onClose: (() -> Void)?
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 8) {
            // Tab图标
            Image(systemName: tab.icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(isSelected ? .primary : .secondary)
            
            // Tab标题
            Text(tab.title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isSelected ? .primary : .secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            
            // 关闭按钮
            if let onClose = onClose {
                Button(action: {
                    onClose()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 16, height: 16)
                        .background(
                            Circle()
                                .fill(.quaternary)
                                .opacity(isHovered ? 1.0 : 0.0)
                        )
                }
                .buttonStyle(.plain)
                .opacity(isSelected || isHovered ? 1.0 : 0.0)
                .animation(.easeInOut(duration: 0.2), value: isHovered)
                .animation(.easeInOut(duration: 0.2), value: isSelected)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(minWidth: 120, maxWidth: 200)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(
                    isSelected ? Color.accentColor.opacity(0.3) : Color.clear,
                    lineWidth: 1
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}

#Preview {
    @Previewable @State var selectedTab = 0
    
    return CustomTabBar(
        selectedTab: $selectedTab,
        tabs: [
            TabItem(id: 0, title: "欢迎", icon: "house", isClosable: false),
            TabItem(id: 1, title: "FastGit", icon: "folder", isClosable: true),
            TabItem(id: 2, title: "另一个项目", icon: "folder", isClosable: true)
        ],
        onCloseTab: { tabId in
            print("关闭Tab: \(tabId)")
        }
    )
    .frame(width: 600, height: 40)
}