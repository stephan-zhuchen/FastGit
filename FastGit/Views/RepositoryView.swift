//
//  RepositoryView.swift
//  FastGit
//
//  Created by FastGit Team
//

import SwiftUI

/// 仓库视图 - 实现三区域布局
struct RepositoryView: View {
    @ObservedObject var viewModel: MainViewModel
    let repository: GitRepository
    let onClose: ((GitRepository) -> Void)?

    // ** ADDED: State for resizable sidebar **
    // ** 新增：用于可变侧边栏的状态 **
    @AppStorage("sidebarWidth") private var sidebarWidth: Double = 250.0
    private let minSidebarWidth: Double = 200
    private let maxSidebarWidth: Double = 500

    init(
        viewModel: MainViewModel,
        repository: GitRepository,
        onClose: ((GitRepository) -> Void)? = nil
    ) {
        self.viewModel = viewModel
        self.repository = repository
        self.onClose = onClose
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // ** MODIFIED: Apply resizable width **
            // ** 修改：应用可变的宽度 **
            FunctionListView(
                selectedItem: $viewModel.selectedFunctionItem,
                expandedSections: $viewModel.expandedSections,
                repository: repository,
                branches: viewModel.branches,
                tags: viewModel.tags,
                submodules: viewModel.submodules
            )
            .frame(width: sidebarWidth)
            
            // ** ADDED: Draggable divider **
            // ** 新增：可拖动的分隔线 **
            DraggableDivider(width: $sidebarWidth, minWidth: minSidebarWidth, maxWidth: maxSidebarWidth)
            
            // 右侧内容区域
            VStack(spacing: 0) {
                RepositoryToolbarView(onClose: nil)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                
                Divider()
                    .padding(.horizontal, 16)
                
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
        }
        .navigationTitle(repository.displayName)
        .navigationSubtitle(repository.path)
        // ** MODIFICATION: Use .task(id:) to trigger loading only when the repo changes **
        // ** 修改：使用 .task(id:) 来确保只在仓库变化时触发加载 **
        .task(id: repository.path) {
            // ** FIX: Explicitly capture viewModel to help the compiler **
            // ** 修复：显式捕获 viewModel 以帮助编译器 **
            let vm = viewModel
            await vm.loadRepositoryData(for: repository)
        }
    }
    
    // ... (The rest of the file remains the same)
    // ... (文件的其余部分保持不变)
    
    // MARK: - 子视图
    
    /// 根据选中的功能项返回对应的内容视图
    @ViewBuilder
    private func contentView(for item: SelectedFunctionItem) -> some View {
        // 所有逻辑现在都从ViewModel读取数据
        switch item {
        case .fixedOption(let option):
            switch option {
            case .defaultHistory:
                HistoryView(repository: repository)
            case .localChanges:
                placeholderView(for: "本地修改", icon: "doc.text.below.ecg", color: .blue)
            case .stashList:
                placeholderView(for: "Stash列表", icon: "tray.full", color: .purple)
            }
            
        case .expandableType(let type):
            // This case might not be strictly necessary if a default branch is always selected,
            // but it's good for handling the state where a category is selected but no specific item.
            // 如果总是默认选中一个分支，这个 case 可能不是必需的，但它可以处理只选中了分类但未选中具体项的状态。
            switch type {
            case .localBranches:
                if viewModel.branches.filter({ !$0.isRemote }).isEmpty {
                    emptyStateView(for: "本地分支", icon: "point.3.connected.trianglepath.dotted")
                } else {
                    HistoryView(repository: repository) // Default to showing history for the current branch
                }
            case .remoteBranches:
                 HistoryView(repository: repository) // Default to showing history for the current branch
            case .tags:
                if viewModel.tags.isEmpty {
                    emptyStateView(for: "标签", icon: "tag")
                } else {
                    tagListView()
                }
            case .submodules:
                placeholderView(for: "子模块", icon: "square.stack.3d.down.right", color: .purple)
            }
            
        // ** FIX: Updated case to handle the new branchItem definition **
        // ** 修复：更新 case 以处理新的 branchItem 定义 **
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
            placeholderView(for: "子模块: \(submoduleName)", icon: "cube", color: .purple)
        }
    }
    
    // MARK: - 子视图方法
    
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
            Image(systemName: icon)
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

// MARK: - Draggable Divider

/// A view that acts as a draggable divider to resize the sidebar.
/// 一个可拖动的分隔线视图，用于调整侧边栏大小。
private struct DraggableDivider: View {
    @Binding var width: Double
    let minWidth: Double
    let maxWidth: Double

    @State private var dragOffset: CGFloat = 0

    var body: some View {
        Divider()
            .frame(width: 8)
            .background(Color.black.opacity(0.001)) // Make a wider hit area
            .contentShape(Rectangle())
            .onHover { inside in
                if inside {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let newWidth = width + value.translation.width - dragOffset
                        self.width = max(minWidth, min(newWidth, maxWidth))
                        // We don't update dragOffset here to make dragging smoother
                    }
                    .onEnded { _ in
                        dragOffset = 0 // Reset on end
                    }
            )
    }
}

// MARK: - List Item Components

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

