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
        case .defaultHistory: return "clock"
        case .localChanges: return "doc.text.below.ecg"
        case .stashList: return "tray.full"
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
    case branchItem(String)
    case tagItem(String)
    case submoduleItem(String)
}


/// 功能列表视图
struct FunctionListView: View {
    @Binding var selectedItem: SelectedFunctionItem?
    @Binding var expandedSections: Set<ExpandableFunctionType>
    
    let repository: GitRepository?
    let branches: [GitBranch]
    let tags: [GitTag]
    let submodules: [String]
    let onOpenSubmodule: ((String) -> Void)?
    
    @State private var localBranchTree: [BranchTreeNode] = []
    @State private var remoteBranchTree: [BranchTreeNode] = []
    
    @State private var searchText = ""
    @State private var isCaseSensitive = false
    @State private var isWholeWord = false

    var body: some View {
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
    
    // MARK: - Data Processing & Filtering
    
    private func buildTrees() {
        localBranchTree = BranchTreeNode.buildTree(from: branches.filter { !$0.isRemote })
        remoteBranchTree = BranchTreeNode.buildTree(from: branches.filter { $0.isRemote })
    }
    
    private func checkMatch(in text: String, for pattern: String) -> Bool {
        if isWholeWord {
            let patternToSearch = isCaseSensitive ? pattern : pattern.lowercased()
            let textToSearchIn = isCaseSensitive ? text : text.lowercased()
            if let regex = try? NSRegularExpression(pattern: "\\b\(NSRegularExpression.escapedPattern(for: patternToSearch))\\b") {
                let range = NSRange(textToSearchIn.startIndex..., in: textToSearchIn)
                return regex.firstMatch(in: textToSearchIn, options: [], range: range) != nil
            }
            return false
        } else {
            if isCaseSensitive {
                return text.contains(pattern)
            } else {
                return text.localizedCaseInsensitiveContains(pattern)
            }
        }
    }

    private var filteredLocalBranchTree: [BranchTreeNode] {
        BranchTreeNode.filterTree(localBranchTree, with: searchText, checkMatch: checkMatch)
    }
    
    private var filteredRemoteBranchTree: [BranchTreeNode] {
        BranchTreeNode.filterTree(remoteBranchTree, with: searchText, checkMatch: checkMatch)
    }
    
    private var filteredTags: [GitTag] {
        if searchText.isEmpty { return tags }
        return tags.filter { checkMatch(in: $0.name, for: searchText) }
    }
    
    private var filteredSubmodules: [String] {
        if searchText.isEmpty { return submodules }
        return submodules.filter { checkMatch(in: $0, for: searchText) }
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
    
    private var expandableFunctionsSection: some View {
        ScrollView {
            VStack(spacing: 8) {
                HStack {
                    Text("仓库").font(.headline).fontWeight(.semibold).foregroundStyle(.primary)
                    Spacer()
                    CustomSearchBar(
                        searchText: $searchText,
                        isCaseSensitive: $isCaseSensitive,
                        isWholeWord: $isWholeWord
                    )
                    .frame(maxWidth: 130)
                }
                .padding(.horizontal, 16).padding(.bottom, 4)

                localBranchesSection
                remoteBranchesSection
                tagsSection
                submodulesSection
                
                Spacer()
            }
        }
    }
    
    @ViewBuilder
    private var localBranchesSection: some View {
        ExpandableFunctionSection(
            type: .localBranches, isExpanded: isSectionExpanded(.localBranches), itemCount: filteredLocalBranchTree.count,
            onToggleExpansion: { toggleSection(.localBranches) }
        ) {
            LocalBranchContentView(nodes: filteredLocalBranchTree, selectedItem: $selectedItem)
        }
    }
    
    @ViewBuilder
    private var remoteBranchesSection: some View {
        ExpandableFunctionSection(
            type: .remoteBranches, isExpanded: isSectionExpanded(.remoteBranches), itemCount: filteredRemoteBranchTree.count,
            onToggleExpansion: { toggleSection(.remoteBranches) }
        ) {
            RemoteBranchContentView(nodes: filteredRemoteBranchTree, selectedItem: $selectedItem)
        }
    }

    @ViewBuilder
    private var tagsSection: some View {
        ExpandableFunctionSection(
            type: .tags, isExpanded: isSectionExpanded(.tags), itemCount: filteredTags.count,
            onToggleExpansion: { toggleSection(.tags) }
        ) {
            TagsContentView(tags: filteredTags, selectedItem: $selectedItem)
        }
    }
    
    @ViewBuilder
    private var submodulesSection: some View {
        ExpandableFunctionSection(
            type: .submodules, isExpanded: isSectionExpanded(.submodules), itemCount: filteredSubmodules.count,
            onToggleExpansion: { toggleSection(.submodules) }
        ) {
            SubmodulesContentView(submodules: filteredSubmodules, onOpenSubmodule: onOpenSubmodule)
        }
    }
    
    private func toggleSection(_ type: ExpandableFunctionType) {
        if expandedSections.contains(type) {
            expandedSections.remove(type)
        } else {
            expandedSections.insert(type)
        }
    }

    private func isSectionExpanded(_ type: ExpandableFunctionType) -> Bool {
        !searchText.isEmpty || expandedSections.contains(type)
    }
}

// MARK: - Reusable Components & Section Content Views

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
                    Image(systemName: "chevron.right").font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary).rotationEffect(.degrees(isExpanded ? 90 : 0))
                    Image(systemName: type.iconName).font(.system(size: 16, weight: .medium)).foregroundStyle(type.themeColor).frame(width: 20)
                    Text(type.rawValue).font(.system(size: 14, weight: .medium)).foregroundStyle(.primary)
                    Spacer()
                    Text("\(itemCount)").font(.caption).foregroundStyle(.secondary).padding(.horizontal, 6).padding(.vertical, 2).background(Color.secondary.opacity(0.2)).clipShape(Capsule())
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

// MARK: - Section Content Views
private struct LocalBranchContentView: View {
    let nodes: [BranchTreeNode]
    @Binding var selectedItem: SelectedFunctionItem?

    var body: some View {
        VStack(spacing: 2) {
            ForEach(nodes) { node in
                BranchNodeView(node: node, level: 0, selectedItem: $selectedItem)
            }
        }
    }
}

private struct RemoteBranchContentView: View {
    let nodes: [BranchTreeNode]
    @Binding var selectedItem: SelectedFunctionItem?

    var body: some View {
        ScrollView {
            VStack(spacing: 2) {
                ForEach(nodes) { node in
                    BranchNodeView(node: node, level: 0, selectedItem: $selectedItem)
                }
            }
        }
        .frame(maxHeight: 200)
    }
}

private struct TagsContentView: View {
    let tags: [GitTag]
    @Binding var selectedItem: SelectedFunctionItem?

    var body: some View {
        ScrollView {
            VStack(spacing: 2) {
                ForEach(tags) { tag in
                    TagItemButton(
                        tag: tag, isSelected: selectedItem == .tagItem(tag.name),
                        onSelect: { selectedItem = .tagItem(tag.name) }
                    )
                }
            }
        }
        .frame(maxHeight: 200)
    }
}

private struct SubmodulesContentView: View {
    let submodules: [String]
    let onOpenSubmodule: ((String) -> Void)?

    var body: some View {
        ScrollView {
            VStack(spacing: 2) {
                ForEach(submodules, id: \.self) { submoduleName in
                    SubmoduleItemButton(
                        submoduleName: submoduleName,
                        onDoubleTap: { onOpenSubmodule?(submoduleName) }
                    )
                }
            }
        }
        .frame(maxHeight: 200)
    }
}


// MARK: - Item Views

struct BranchNodeView: View {
    @ObservedObject var node: BranchTreeNode
    let level: Int
    @Binding var selectedItem: SelectedFunctionItem?
    @State private var isHovered = false

    private var indent: CGFloat { CGFloat(level * 16 + 20) }

    private var iconName: String {
        guard let branch = node.branch else { return "folder" }
        return branch.isRemote ? "cloud" : "point.3.connected.trianglepath.dotted"
    }
    
    @ViewBuilder
    private var buttonContent: some View {
        HStack(spacing: 6) {
            if node.branch == nil {
                Image(systemName: "chevron.right").font(.system(size: 8, weight: .bold)).foregroundStyle(.secondary).rotationEffect(.degrees(node.isExpanded ? 90 : 0))
            } else {
                Spacer().frame(width: 8)
            }
            Image(systemName: iconName).font(.system(size: 12)).foregroundStyle(iconColor).frame(width: 16, alignment: .center)
            Text(node.name).font(.system(size: 13)).fontWeight(node.branch?.isCurrent ?? false ? .bold : .regular).foregroundStyle(isSelected ? .white : .primary).lineLimit(1)
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
        RoundedRectangle(cornerRadius: 6).fill(isSelected ? Color.accentColor : isHovered ? Color.primary.opacity(0.05) : Color.clear)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Button(action: {
                if let branch = node.branch { selectedItem = .branchItem(branch.name) }
                else { node.toggleExpanded() }
            }) { buttonContent }
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
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 8).fill(isSelected ? Color.accentColor : isHovered ? Color.primary.opacity(0.08) : Color.clear))
        }
        .buttonStyle(.plain)
        .opacity(1.0)
        .padding(.horizontal, 8)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) { isHovered = hovering }
        }
    }
}

private struct TagItemButton: View {
    let tag: GitTag
    let isSelected: Bool
    let onSelect: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 6) {
                Spacer().frame(width: 8)
                Image(systemName: "tag").font(.system(size: 12)).foregroundStyle(Color.orange).frame(width: 16, alignment: .center)
                Text(tag.name).font(.system(size: 13)).foregroundStyle(isSelected ? .white : .primary).lineLimit(1)
                Spacer()
            }
            .padding(.leading, 20)
            .padding(.vertical, 4)
            .padding(.trailing, 8)
        }
        .buttonStyle(.plain)
        .background(RoundedRectangle(cornerRadius: 6).fill(isSelected ? Color.orange.opacity(0.8) : isHovered ? Color.primary.opacity(0.05) : Color.clear))
        .padding(.horizontal, 8)
        .onHover { hovering in isHovered = hovering }
    }
}

private struct SubmoduleItemButton: View {
    let submoduleName: String
    let onDoubleTap: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 6) {
            Spacer().frame(width: 8)
            Image(systemName: "cube.box").font(.system(size: 12)).foregroundStyle(Color.purple).frame(width: 16, alignment: .center)
            Text(submoduleName).font(.system(size: 13)).foregroundStyle(.primary).lineLimit(1)
            Spacer()
        }
        .padding(.leading, 20)
        .padding(.vertical, 4)
        .padding(.trailing, 8)
        .background(RoundedRectangle(cornerRadius: 6).fill(isHovered ? Color.primary.opacity(0.05) : Color.clear))
        .padding(.horizontal, 8)
        .onHover { hovering in isHovered = hovering }
        .onTapGesture(count: 2) { onDoubleTap() }
    }
}

#if DEBUG
struct FunctionListView_Previews: PreviewProvider {
    struct PreviewWrapper: View {
        @State private var selectedItem: SelectedFunctionItem? = .branchItem("main")
        @State private var expandedSections: Set<ExpandableFunctionType> = [.localBranches, .remoteBranches, .tags, .submodules]
        
        private let mockBranches: [GitBranch] = [
            GitBranch(name: "main", isCurrent: true, isRemote: false, targetSha: "abc"),
            GitBranch(name: "develop", isCurrent: false, isRemote: false, targetSha: "def"),
            GitBranch(name: "origin/main", isCurrent: false, isRemote: true, targetSha: "abc"),
            GitBranch(name: "origin/develop", isCurrent: false, isRemote: true, targetSha: "def"),
            GitBranch(name: "origin/feature/new-ui-component", isCurrent: false, isRemote: true, targetSha: "ghi"),
            GitBranch(name: "origin/feature/user-authentication", isCurrent: false, isRemote: true, targetSha: "jkl"),
            GitBranch(name: "origin/bugfix/login-crash", isCurrent: false, isRemote: true, targetSha: "mno"),
        ]
        
        private let mockTags: [GitTag] = (1...20).map { i in GitTag(name: "v1.0.\(i)", targetSha: "sha-\(i)") }
        private let mockSubmodules: [String] = ["External/SwiftGitX", "Libraries/Networking", "Frameworks/UIComponents"]

        var body: some View {
            FunctionListView(
                selectedItem: $selectedItem,
                expandedSections: $expandedSections,
                repository: nil, branches: mockBranches, tags: mockTags, submodules: mockSubmodules,
                onOpenSubmodule: { submoduleName in print("ACTION: Double-clicked to open submodule: \(submoduleName)") }
            )
        }
    }

    static var previews: some View {
        PreviewWrapper().frame(width: 250, height: 600)
    }
}
#endif
