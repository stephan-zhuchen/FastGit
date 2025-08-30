//
//  FunctionListView.swift
//  FastGit
//
//  Created by FastGit Team
//

import SwiftUI

// --- Enums: FunctionListOption, ExpandableFunctionType, SelectedFunctionItem ---
// --- 枚举：FunctionListOption, ExpandableFunctionType, SelectedFunctionItem ---
/// 功能列表选项类型
enum FunctionListOption: String, CaseIterable, Identifiable {
    case defaultHistory = "提交历史"
    case localChanges = "本地修改"
    case stashList = "Stash列表"
    
    var id: String { rawValue }
    
    var iconName: String {
        switch self {
        case .defaultHistory: return "doc.text.below.ecg"
        case .localChanges: return "doc.text.below.ecg"
        case .stashList: return "tray.full"
        }
    }
    
    var isImplemented: Bool {
        switch self {
        case .defaultHistory: return true
        default: return false
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
    
    var iconName: String {
        switch self {
        case .localBranches: return "point.3.connected.trianglepath.dotted"
        case .remoteBranches: return "cloud"
        case .tags: return "tag"
        case .submodules: return "square.stack.3d.down.right"
        }
    }
    
    var themeColor: Color {
        switch self {
        case .localBranches: return .blue
        case .remoteBranches: return .green
        case .tags: return .orange
        case .submodules: return .purple
        }
    }
}

/// 选中的功能项类型
enum SelectedFunctionItem: Equatable, Hashable {
    case fixedOption(FunctionListOption)
    case expandableType(ExpandableFunctionType)
    // Now using full branch name for unique identification
    // 现在使用完整分支名作为唯一标识
    case branchItem(String) // Branch full name, e.g., "origin/feature/new-ui"
    case tagItem(String)
    case submoduleItem(String)
}


/// 功能列表视图
struct FunctionListView: View {
    @Binding var selectedItem: SelectedFunctionItem?
    @Binding var expandedSections: Set<ExpandableFunctionType>
    
    // Git data
    let repository: GitRepository?
    let branches: [GitBranch]
    let tags: [GitTag]
    let submodules: [String]
    
    // State for the branch trees
    @State private var localBranchTree: [BranchTreeNode] = []
    @State private var remoteBranchTree: [BranchTreeNode] = []

    var body: some View {
        // ** FIX: Use VStack instead of ScrollView to control scrolling behavior **
        // ** 修复：使用 VStack 替代 ScrollView 来控制滚动行为 **
        VStack(spacing: 0) {
            fixedFunctionsSection
            Divider().padding(.horizontal, 12).padding(.vertical, 8)
            expandableFunctionsSection
        }
        .padding(.vertical, 12)
        .background(.regularMaterial)
        .onAppear(perform: buildTrees)
        .onChange(of: branches) { _, _ in buildTrees() }
    }
    
    // MARK: - Data Processing
    private func buildTrees() {
        localBranchTree = BranchTreeNode.buildTree(from: branches.filter { !$0.isRemote })
        remoteBranchTree = BranchTreeNode.buildTree(from: branches.filter { $0.isRemote })
    }

    // MARK: - Subviews
    private var fixedFunctionsSection: some View {
        VStack(spacing: 4) {
            HStack {
                Text("工作区").font(.headline).fontWeight(.semibold).foregroundStyle(.primary)
                Spacer()
            }
            .padding(.horizontal, 16).padding(.bottom, 8)
            
            ForEach(FunctionListOption.allCases) { option in
                FixedFunctionButton(
                    option: option,
                    isSelected: selectedItem == .fixedOption(option),
                    action: { selectedItem = .fixedOption(option) }
                )
            }
        }
    }
    
    // ** FIX: Wrap expandable content in a ScrollView **
    // ** 修复：将可展开内容包裹在 ScrollView 中 **
    private var expandableFunctionsSection: some View {
        ScrollView {
            VStack(spacing: 8) {
                HStack {
                    Text("仓库").font(.headline).fontWeight(.semibold).foregroundStyle(.primary)
                    Spacer()
                }
                .padding(.horizontal, 16).padding(.bottom, 4)

                // Local Branches Section
                ExpandableFunctionSection(
                    type: .localBranches,
                    isExpanded: expandedSections.contains(.localBranches),
                    itemCount: branches.filter { !$0.isRemote }.count,
                    onToggleExpansion: { toggleSection(.localBranches) }
                ) {
                    // This content is usually short, no ScrollView needed
                    // 这部分内容通常很短，不需要 ScrollView
                    VStack(spacing: 2) {
                        ForEach(localBranchTree) { node in
                            BranchNodeView(node: node, level: 0, selectedItem: $selectedItem)
                        }
                    }
                }

                // Remote Branches Section
                ExpandableFunctionSection(
                    type: .remoteBranches,
                    isExpanded: expandedSections.contains(.remoteBranches),
                    itemCount: branches.filter { $0.isRemote }.count,
                    onToggleExpansion: { toggleSection(.remoteBranches) }
                ) {
                    // ** FIX: Limit height and make this section scrollable **
                    // ** 修复：限制高度并使此部分可滚动 **
                    ScrollView {
                        VStack(spacing: 2) {
                            ForEach(remoteBranchTree) { node in
                                BranchNodeView(node: node, level: 0, selectedItem: $selectedItem)
                            }
                        }
                    }
                    .frame(maxHeight: 200) // Adjust max height as needed (可根据需要调整最大高度)
                }
                
                // Tags Section
                ExpandableFunctionSection(
                    type: .tags,
                    isExpanded: expandedSections.contains(.tags),
                    itemCount: tags.count,
                    onToggleExpansion: { toggleSection(.tags) }
                ) {
                    // ** FIX: Limit height and make this section scrollable **
                    // ** 修复：限制高度并使此部分可滚动 **
                    ScrollView {
                        VStack(spacing: 2) {
                            ForEach(tags) { tag in
                                TagItemButton(
                                    tag: tag,
                                    isSelected: selectedItem == .tagItem(tag.name),
                                    onSelect: { selectedItem = .tagItem(tag.name) }
                                )
                            }
                        }
                    }
                    .frame(maxHeight: 200) // Adjust max height as needed (可根据需要调整最大高度)
                }
                
                // Submodules Section
                ExpandableFunctionSection(
                    type: .submodules,
                    isExpanded: expandedSections.contains(.submodules),
                    itemCount: submodules.count,
                    onToggleExpansion: { toggleSection(.submodules) }
                ) {
                    // Placeholder
                }
                
                // This Spacer pushes everything up
                // 这个 Spacer 将所有内容向上推
                Spacer()
            }
        }
    }
    
    private func toggleSection(_ type: ExpandableFunctionType) {
        if expandedSections.contains(type) {
            expandedSections.remove(type)
        } else {
            expandedSections.insert(type)
        }
    }
}

// MARK: - Reusable Components

// ... (ExpandableFunctionSection, BranchNodeView, etc. remain the same)
// ... (ExpandableFunctionSection, BranchNodeView 等组件保持不变)


private struct ExpandableFunctionSection<Content: View>: View {
    let type: ExpandableFunctionType
    let isExpanded: Bool
    let itemCount: Int
    let onToggleExpansion: () -> Void
    @ViewBuilder let content: () -> Content
    
    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onToggleExpansion) {
                HStack(spacing: 12) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    
                    Image(systemName: type.iconName).font(.system(size: 16, weight: .medium)).foregroundStyle(type.themeColor).frame(width: 20)
                    Text(type.rawValue).font(.system(size: 14, weight: .medium)).foregroundStyle(.primary)
                    Spacer()
                    if itemCount > 0 {
                        Text("\(itemCount)").font(.caption).foregroundStyle(.secondary).padding(.horizontal, 6).padding(.vertical, 2).background(Color.secondary.opacity(0.2)).clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(isHovered ? Color.primary.opacity(0.05) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)
            .onHover { hovering in withAnimation(.easeInOut(duration: 0.2)) { isHovered = hovering } }

            if isExpanded {
                content().padding(.top, 2).padding(.bottom, 4)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
    }
}

/// A view that recursively renders a branch tree node.
/// 一个递归渲染分支树节点的视图。
struct BranchNodeView: View {
    @ObservedObject var node: BranchTreeNode
    let level: Int
    @Binding var selectedItem: SelectedFunctionItem?
    @State private var isHovered = false

    private var indent: CGFloat { CGFloat(level * 16 + 20) }

    @ViewBuilder
    private var buttonContent: some View {
        HStack(spacing: 6) {
            // Folder chevron
            if node.branch == nil {
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(node.isExpanded ? 90 : 0))
            } else {
                // Spacer to align branch names
                Spacer().frame(width: 8)
            }
            
            // Icon
            Image(systemName: node.branch == nil ? "folder" : (node.branch!.isRemote ? "cloud" : "point.3.connected.trianglepath.dotted"))
                .font(.system(size: 12))
                .foregroundStyle(iconColor)
                .frame(width: 16, alignment: .center)
            
            // Name
            Text(node.name)
                .font(.system(size: 13))
                .fontWeight(node.branch?.isCurrent ?? false ? .bold : .regular)
                .foregroundStyle(isSelected ? .white : .primary)
                .lineLimit(1)
            
            Spacer()
        }
        .padding(.leading, indent)
        .padding(.vertical, 4)
        .padding(.trailing, 8)
    }
    
    private var iconColor: Color {
        if node.branch == nil { return .secondary.opacity(0.8) }
        if node.branch!.isCurrent { return .accentColor }
        return .secondary
    }
    
    private var backgroundStyle: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(
                isSelected ? Color.accentColor :
                isHovered ? Color.primary.opacity(0.05) : Color.clear
            )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Button(action: {
                if let branch = node.branch {
                    selectedItem = .branchItem(branch.name) // Select the branch
                } else {
                    node.toggleExpanded() // Expand/collapse the folder
                }
            }) {
                buttonContent
            }
            .buttonStyle(.plain)
            .background(backgroundStyle)
            .padding(.horizontal, 8)
            .onHover { hovering in isHovered = hovering }
            
            if node.isExpanded {
                ForEach(node.children) { childNode in
                    BranchNodeView(node: childNode, level: level + 1, selectedItem: $selectedItem)
                }
            }
        }
    }
    
    private var isSelected: Bool {
        guard let branch = node.branch else { return false }
        return selectedItem == .branchItem(branch.name)
    }
}


private struct FixedFunctionButton: View {
    let option: FunctionListOption
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: option.iconName).font(.system(size: 16, weight: .medium)).foregroundStyle(isSelected ? .white : .primary).frame(width: 20)
                Text(option.rawValue).font(.system(size: 14, weight: .medium)).foregroundStyle(isSelected ? .white : .primary)
                Spacer()
                if !option.isImplemented {
                    Image(systemName: "clock.badge").font(.system(size: 12)).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor : isHovered ? Color.primary.opacity(0.08) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .disabled(!option.isImplemented)
        .opacity(option.isImplemented ? 1.0 : 0.6)
        .padding(.horizontal, 8)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) { isHovered = hovering && option.isImplemented }
        }
    }
}

// ** ADDED: A simple button for tag items **
// ** 新增：用于标签项的简单按钮 **
private struct TagItemButton: View {
    let tag: GitTag
    let isSelected: Bool
    let onSelect: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 6) {
                Spacer().frame(width: 8) // Indent spacer
                Image(systemName: "tag")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.orange)
                    .frame(width: 16, alignment: .center)
                
                Text(tag.name)
                    .font(.system(size: 13))
                    .foregroundStyle(isSelected ? .white : .primary)
                    .lineLimit(1)
                
                Spacer()
            }
            .padding(.leading, 20) // Static indent for tags
            .padding(.vertical, 4)
            .padding(.trailing, 8)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    isSelected ? Color.orange.opacity(0.8) :
                    isHovered ? Color.primary.opacity(0.05) : Color.clear
                )
        )
        .padding(.horizontal, 8)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}


// MARK: - Preview
#if DEBUG
struct FunctionListView_Previews: PreviewProvider {
    // A stateful container to make the preview interactive
    // 一个有状态的容器，使预览可交互
    struct PreviewWrapper: View {
        @State private var selectedItem: SelectedFunctionItem? = .branchItem("main")
        @State private var expandedSections: Set<ExpandableFunctionType> = [.localBranches, .remoteBranches, .tags]

        // Mock data for preview
        // 用于预览的模拟数据
        private let mockBranches: [GitBranch] = [
            GitBranch(name: "main", isCurrent: true, isRemote: false, targetSha: "abc"),
            GitBranch(name: "develop", isCurrent: false, isRemote: false, targetSha: "def"),
            GitBranch(name: "origin/main", isCurrent: false, isRemote: true, targetSha: "abc"),
            GitBranch(name: "origin/develop", isCurrent: false, isRemote: true, targetSha: "def"),
            GitBranch(name: "origin/feature/new-ui-component", isCurrent: false, isRemote: true, targetSha: "ghi"),
            GitBranch(name: "origin/feature/user-authentication", isCurrent: false, isRemote: true, targetSha: "jkl"),
            GitBranch(name: "origin/bugfix/login-crash", isCurrent: false, isRemote: true, targetSha: "mno"),
        ]
        
        private let mockTags: [GitTag] = (1...20).map { i in
            GitTag(name: "v1.0.\(i)", targetSha: "sha-\(i)")
        }

        var body: some View {
            FunctionListView(
                selectedItem: $selectedItem,
                expandedSections: $expandedSections,
                repository: nil,
                branches: mockBranches,
                tags: mockTags,
                submodules: []
            )
        }
    }

    static var previews: some View {
        PreviewWrapper()
            .frame(width: 250, height: 600)
    }
}
#endif

