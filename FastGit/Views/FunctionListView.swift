//
//  FunctionListView.swift
//  FastGit
//
//  Created by FastGit Team
//

import SwiftUI

/// 功能列表选项类型
enum FunctionListOption: String, CaseIterable, Identifiable {
    case defaultHistory = "提交历史"
    case localChanges = "本地修改"
    case stashList = "Stash列表"
    
    var id: String { rawValue }
    
    /// 图标名称
    var iconName: String {
        switch self {
        case .defaultHistory:
            return "doc.text.below.ecg"
        case .localChanges:
            return "doc.text.below.ecg"
        case .stashList:
            return "tray.full"
        }
    }
    
    /// 是否已实现
    var isImplemented: Bool {
        switch self {
        case .defaultHistory:
            return true
        default:
            return false
        }
    }
}

/// 可展开功能列表类型
enum ExpandableFunctionType: String, CaseIterable, Identifiable {
    case localBranches = "本地分支"
    case remoteBranches = "远程分支"
    case tags = "标签列表"
    case submodules = "子模块列表"
    
    var id: String { rawValue }
    
    /// 图标名称
    var iconName: String {
        switch self {
        case .localBranches:
            return "point.3.connected.trianglepath.dotted"
        case .remoteBranches:
            return "point.3.connected.trianglepath.dotted"
        case .tags:
            return "tag"
        case .submodules:
            return "square.stack.3d.down.right"
        }
    }
    
    /// 主题颜色
    var themeColor: Color {
        switch self {
        case .localBranches:
            return .blue
        case .remoteBranches:
            return .green
        case .tags:
            return .orange
        case .submodules:
            return .purple
        }
    }
    
    /// 是否已实现
    var isImplemented: Bool {
        switch self {
        case .localBranches, .remoteBranches, .tags:
            return true  // 已有Git数据支持
        case .submodules:
            return false  // 暂未实现
        }
    }
}

/// 选中的功能项类型
enum SelectedFunctionItem: Equatable {
    case fixedOption(FunctionListOption)
    case expandableType(ExpandableFunctionType)
    case branchItem(String, isRemote: Bool)  // 分支名, 是否为远程分支
    case tagItem(String)  // 标签名
    case submoduleItem(String)  // 子模块名
}

/// 功能列表视图 - 实现两层结构的左侧功能导航
struct FunctionListView: View {
    @Binding var selectedItem: SelectedFunctionItem?
    @Binding var expandedSections: Set<ExpandableFunctionType>
    
    // Git数据
    let repository: GitRepository?
    let branches: [GitBranch]
    let tags: [GitTag]
    let submodules: [String]  // 暂时用字符串数组表示子模块
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // 上部分：固定功能选项
                fixedFunctionsSection
                
                Divider()
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                
                // 下部分：可展开功能列表
                expandableFunctionsSection
                
                Spacer(minLength: 20)
            }
            .padding(.vertical, 12)
        }
        .frame(width: 250)  // 稍微增加宽度以适应更多内容
        .background(.regularMaterial)
    }
    
    // MARK: - 子视图
    
    /// 固定功能选项区域
    private var fixedFunctionsSection: some View {
        VStack(spacing: 4) {
            // 标题
            HStack {
                Text("工作区")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            
            // 固定功能选项
            ForEach(FunctionListOption.allCases) { option in
                FixedFunctionButton(
                    option: option,
                    isSelected: selectedItem == .fixedOption(option),
                    action: {
                        selectedItem = .fixedOption(option)
                    }
                )
            }
        }
    }
    
    /// 可展开功能列表区域
    private var expandableFunctionsSection: some View {
        VStack(spacing: 8) {
            // 标题
            HStack {
                Text("仓库结构")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 4)
            
            // 可展开功能列表
            ForEach(ExpandableFunctionType.allCases) { type in
                ExpandableFunctionSection(
                    type: type,
                    isExpanded: expandedSections.contains(type),
                    isSelected: selectedItem == .expandableType(type),
                    items: getItemsForType(type),
                    selectedItem: selectedItem,
                    onToggleExpansion: {
                        toggleSection(type)
                    },
                    onSelectType: {
                        selectedItem = .expandableType(type)
                    },
                    onSelectItem: { item in
                        selectedItem = item
                    }
                )
            }
        }
    }
    
    // MARK: - 私有方法
    
    /// 切换展开/收缩状态
    private func toggleSection(_ type: ExpandableFunctionType) {
        if expandedSections.contains(type) {
            expandedSections.remove(type)
        } else {
            expandedSections.insert(type)
        }
    }
    
    /// 获取指定类型的数据项
    private func getItemsForType(_ type: ExpandableFunctionType) -> [SelectedFunctionItem] {
        switch type {
        case .localBranches:
            return branches.filter { !$0.isRemote }.map { .branchItem($0.shortName, isRemote: false) }
        case .remoteBranches:
            return branches.filter { $0.isRemote }.map { .branchItem($0.shortName, isRemote: true) }
        case .tags:
            return tags.map { .tagItem($0.name) }
        case .submodules:
            return submodules.map { .submoduleItem($0) }
        }
    }
}

/// 固定功能按钮组件
private struct FixedFunctionButton: View {
    let option: FunctionListOption
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
            .padding(.horizontal, 16)
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
        .padding(.horizontal, 8)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering && option.isImplemented
            }
        }
    }
}

/// 可展开功能区域组件
private struct ExpandableFunctionSection: View {
    let type: ExpandableFunctionType
    let isExpanded: Bool
    let isSelected: Bool
    let items: [SelectedFunctionItem]
    let selectedItem: SelectedFunctionItem?
    let onToggleExpansion: () -> Void
    let onSelectType: () -> Void
    let onSelectItem: (SelectedFunctionItem) -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题行（可点击展开/收缩）
            Button(action: onToggleExpansion) {
                HStack(spacing: 12) {
                    // 展开/收缩箭头
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .animation(.easeInOut(duration: 0.2), value: isExpanded)
                    
                    // 图标
                    Image(systemName: type.iconName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(type.themeColor)
                        .frame(width: 20)
                    
                    // 标题
                    Text(type.rawValue)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    // 数量标识
                    if !items.isEmpty {
                        Text("\(items.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.2))
                            .clipShape(Capsule())
                    }
                    
                    // 未实现功能的标识
                    if !type.isImplemented {
                        Image(systemName: "clock.badge")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isHovered ? Color.primary.opacity(0.05) : Color.clear)
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHovered = hovering
                }
            }
            
            // 展开的内容
            if isExpanded && type.isImplemented {
                VStack(spacing: 2) {
                    ForEach(items.indices, id: \.self) { index in
                        let item = items[index]
                        ExpandableItemButton(
                            item: item,
                            type: type,
                            isSelected: selectedItem == item,
                            action: {
                                onSelectItem(item)
                            }
                        )
                    }
                }
                .padding(.leading, 32)  // 缩进子项
                .padding(.bottom, 4)
            }
        }
    }
}

/// 可展开项按钮组件
private struct ExpandableItemButton: View {
    let item: SelectedFunctionItem
    let type: ExpandableFunctionType
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                // 项目图标
                itemIcon
                
                // 项目名称
                Text(itemDisplayName)
                    .font(.system(size: 13))
                    .foregroundStyle(isSelected ? .white : .primary)
                    .lineLimit(1)
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        isSelected ? type.themeColor :
                        isHovered ? Color.primary.opacity(0.05) : Color.clear
                    )
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
    
    /// 项目图标
    private var itemIcon: some View {
        Group {
            switch item {
            case .branchItem(_, let isRemote):
                Image(systemName: isRemote ? "cloud" : "point.3.connected.trianglepath.dotted")
                    .font(.system(size: 12))
                    .foregroundStyle(isSelected ? .white : type.themeColor)
            case .tagItem:
                Image(systemName: "tag.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(isSelected ? .white : type.themeColor)
            case .submoduleItem:
                Image(systemName: "cube")
                    .font(.system(size: 12))
                    .foregroundStyle(isSelected ? .white : type.themeColor)
            default:
                EmptyView()
            }
        }
        .frame(width: 16)
    }
    
    /// 项目显示名称
    private var itemDisplayName: String {
        switch item {
        case .branchItem(let name, _):
            return name
        case .tagItem(let name):
            return name
        case .submoduleItem(let name):
            return name
        default:
            return ""
        }
    }
}

#Preview {
    FunctionListView(
        selectedItem: .constant(.expandableType(.localBranches)),
        expandedSections: .constant([.localBranches, .tags]),
        repository: GitRepository(name: "FastGit", path: "/Users/user/FastGit"),
        branches: [
            GitBranch(name: "main", isCurrent: true),
            GitBranch(name: "develop"),
            GitBranch(name: "origin/main", isRemote: true),
            GitBranch(name: "origin/develop", isRemote: true)
        ],
        tags: [
            GitTag(name: "v1.0.0", targetSha: "abc123"),
            GitTag(name: "v1.1.0", targetSha: "def456")
        ],
        submodules: ["SwiftGitX", "TestFramework"]
    )
    .frame(height: 600)
}
