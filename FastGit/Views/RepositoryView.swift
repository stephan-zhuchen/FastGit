//
//  RepositoryView.swift
//  FastGit
//
//  Created by FastGit Team
//

import SwiftUI
import AppKit

/// 仓库视图 - 实现三区域布局
struct RepositoryView: View {
    @AppStorage("sidebarWidth") private var sidebarWidth: Double = 280
    
    @ObservedObject var viewModel: MainViewModel
    let repository: GitRepository
    let onClose: ((GitRepository) -> Void)?
    
    // ** ADDED: Callback for opening a submodule **
    // ** 新增：用于打开子模块的回调 **
    let onOpenSubmodule: ((URL) -> Void)?

    init(
        viewModel: MainViewModel,
        repository: GitRepository,
        onClose: ((GitRepository) -> Void)? = nil,
        onOpenSubmodule: ((URL) -> Void)? = nil // Add the new parameter with a default value
    ) {
        self.viewModel = viewModel
        self.repository = repository
        self.onClose = onClose
        self.onOpenSubmodule = onOpenSubmodule
    }
    
    var body: some View {
        HStack(spacing: 0) {
            FunctionListView(
                selectedItem: $viewModel.selectedFunctionItem,
                expandedSections: $viewModel.expandedSections,
                repository: repository,
                branches: viewModel.branches,
                tags: viewModel.tags,
                submodules: viewModel.submodules,
                // ** FIX: Pass the submodule opening logic to the FunctionListView **
                // ** 修复：将打开子模块的逻辑传递给 FunctionListView **
                onOpenSubmodule: { submodulePath in
                    // Construct the full path of the submodule from the parent repository's path.
                    // 从父仓库的路径构造出子模块的完整路径。
                    let parentPath = repository.path
                    let fullSubmoduleURL = URL(fileURLWithPath: parentPath).appendingPathComponent(submodulePath)
                    
                    // Call the callback to notify the main view to open a new tab.
                    // 调用回调，通知主视图打开新标签页。
                    onOpenSubmodule?(fullSubmoduleURL)
                }
            )
            .frame(width: sidebarWidth)
            
            // ** FIX: Moved gesture logic here for robustness **
            // ** 修复：将手势逻辑移至此处以增强健壮性 **
            DraggableDivider()
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let newWidth = value.location.x
                            let minWidth: Double = 200
                            let maxWidth: Double = 500
                            self.sidebarWidth = max(minWidth, min(newWidth, maxWidth))
                        }
                )

            // --- MODIFIED: Conditionally show Toolbar ---
            // --- 修改：条件性显示工具栏 ---
            if viewModel.selectedFunctionItem != .fixedOption(.localChanges) {
                VStack(spacing: 0) {
                    RepositoryToolbarView(onClose: nil)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                    
                    Divider()
                        .padding(.horizontal, 16)
                    
                    mainContentArea
                }
            } else {
                // For LocalChangesView, don't show the toolbar.
                // 对于“本地修改”视图，不显示工具栏。
                contentView(for: .fixedOption(.localChanges))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .navigationTitle(repository.displayName)
        .navigationSubtitle(repository.path)
        .task(id: repository.path) {
             await viewModel.loadRepositoryData(for: repository)
        }
    }
    
    /// The main content area that shows different views based on selection.
    /// 根据选择显示不同视图的主内容区域。
    private var mainContentArea: some View {
        Group {
            if let item = viewModel.selectedFunctionItem {
                contentView(for: item)
            } else {
                defaultContentView
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private func contentView(for item: SelectedFunctionItem) -> some View {
        switch item {
        case .fixedOption(let option):
            switch option {
            case .defaultHistory:
                HistoryView(repository: repository)
            case .localChanges:
                LocalChangesView(repository: repository)
            case .stashList:
                placeholderView(for: "Stash列表", icon: "tray.full", color: .purple)
            }
            
        case .expandableType(let type):
            switch type {
            case .localBranches, .remoteBranches:
                 HistoryView(repository: repository)
            case .tags:
                if viewModel.tags.isEmpty {
                    emptyStateView(for: "标签", icon: "tag")
                } else {
                    tagListView()
                }
            case .submodules:
                 HistoryView(repository: repository)
            }
            
        case .branchItem(let branchFullName):
            if let branch = viewModel.branches.first(where: { $0.name == branchFullName }) {
                branchDetailView(branch: branch)
            } else {
                Text("分支不存在: \(branchFullName)")
                    .foregroundColor(.secondary)
            }
            
        case .tagItem(let tagName):
            if let tag = viewModel.tags.first(where: { $0.name == tagName }) {
                tagDetailView(tag: tag)
            } else {
                Text("标签不存在")
                    .foregroundColor(.secondary)
            }
            
        case .submoduleItem(let submoduleName):
            // When a submodule is single-clicked, just show the main history
            // 当子模块被单击时，仅显示主历史记录
            HistoryView(repository: repository)
        }
    }
    
    private var defaultContentView: some View {
        VStack(spacing: 20) {
            Image(systemName: "sidebar.left")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("请从左侧选择功能")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("选择左侧功能列表中的功能来查看相应内容")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func placeholderView(for title: String, icon: String, color: Color = .orange) -> some View {
        VStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(color)
            VStack(spacing: 8) {
                Text("\(title)功能")
                    .font(.headline)
                    .foregroundColor(.primary)
                Text("此功能正在开发中，敬请期待")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    private func emptyStateView(for title: String, icon: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "icon")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)
            Text("暂无\(title)")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("当前仓库中没有找到\(title)数据")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func tagListView() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("标签列表")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(viewModel.tags.count) 个标签")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            LazyVStack(spacing: 8) {
                ForEach(viewModel.tags) { tag in
                    TagRowView(
                        tag: tag,
                        isSelected: viewModel.selectedFunctionItem == .tagItem(tag.name),
                        onSelect: {
                            viewModel.selectedFunctionItem = .tagItem(tag.name)
                        }
                    )
                }
            }
            Spacer()
        }
    }
    
    private func branchDetailView(branch: GitBranch) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("分支: \(branch.shortName)")
                    .font(.title2)
                    .fontWeight(.semibold)
                if branch.isCurrent {
                    Text("当前")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
                if branch.isRemote {
                    Text("远程")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
                Spacer()
            }
            if let sha = branch.targetSha {
                Text("目标提交: \(String(sha.prefix(8)))")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            HistoryView(repository: repository, startingSha: branch.targetSha)
        }
    }
    
    private func tagDetailView(tag: GitTag) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("标签: \(tag.name)")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text(tag.isAnnotated ? "注释标签" : "轻量标签")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(tag.isAnnotated ? Color.orange : Color.gray)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                Spacer()
            }
            Text("目标提交: \(String(tag.targetSha.prefix(8)))")
                .font(.body)
                .foregroundStyle(.secondary)
            if let message = tag.message {
                Text("标签消息: \(message)")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            if let tagger = tag.taggerInfo {
                Text("创建者: \(tagger)")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            HistoryView(repository: repository, startingSha: tag.targetSha)
        }
    }
}


// ** FIX: Simplified DraggableDivider **
// ** 修复：简化 DraggableDivider **
private struct DraggableDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color(nsColor: .separatorColor))
            .frame(width: 1)
            .contentShape(Rectangle().inset(by: -5)) // Make the draggable area larger
            .onHover { inside in
                if inside {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
    }
}


// ... (TagRowView remains the same)
// ... (TagRowView 保持不变)
private struct TagRowView: View {
    let tag: GitTag
    let isSelected: Bool
    let onSelect: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: "tag.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.orange)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(tag.name)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        if tag.isAnnotated {
                            Text("注释")
                                .font(.caption2)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.orange)
                                .foregroundColor(.white)
                                .clipShape(Capsule())
                        }
                        Spacer()
                    }
                    Text(String(tag.targetSha.prefix(8)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        isSelected ? Color.orange.opacity(0.2) :
                        isHovered ? Color.primary.opacity(0.05) : Color.clear
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.orange : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

