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
    let onClose: ((GitRepository) -> Void)?  // 关闭Tab的回调

    // 修改初始化方法以接收ViewModel
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
            // 左侧功能列表导航栏 - 使用ViewModel的数据和状态
            FunctionListView(
                selectedItem: $viewModel.selectedFunctionItem,
                expandedSections: $viewModel.expandedSections,
                repository: repository,
                branches: viewModel.branches,
                tags: viewModel.tags,
                submodules: viewModel.submodules
            )
            
            Divider()
            
            // 右侧内容区域
            VStack(spacing: 0) {
                // 上方工具栏
                RepositoryToolbarView(onClose: nil)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                
                Divider()
                    .padding(.horizontal, 16)
                
                // 下方主体内容区域 - 使用ViewModel的状态
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
        // 移除.task和.onChange，数据加载由ViewModel触发
    }
    
    // MARK: - 子视图
    
    /// 根据选中的功能项返回对应的内容视图
    @ViewBuilder
    private func contentView(for item: SelectedFunctionItem) -> some View {
        // 所有逻辑现在都从ViewModel读取数据
        switch item {
        case .fixedOption(let option):
            switch option {
            case .localChanges:
                placeholderView(for: "本地修改", icon: "doc.text.below.ecg", color: .blue)
            case .stashList:
                placeholderView(for: "Stash列表", icon: "tray.full", color: .purple)
            }
            
        case .expandableType(let type):
            switch type {
            case .localBranches:
                if viewModel.branches.filter({ !$0.isRemote }).isEmpty {
                    emptyStateView(for: "本地分支", icon: "point.3.connected.trianglepath.dotted")
                } else {
                    branchListView(branches: viewModel.branches.filter { !$0.isRemote }, title: "本地分支")
                }
            case .remoteBranches:
                if viewModel.branches.filter({ $0.isRemote }).isEmpty {
                    emptyStateView(for: "远程分支", icon: "cloud")
                } else {
                    branchListView(branches: viewModel.branches.filter { $0.isRemote }, title: "远程分支")
                }
            case .tags:
                if viewModel.tags.isEmpty {
                    emptyStateView(for: "标签", icon: "tag")
                } else {
                    tagListView()
                }
            case .submodules:
                placeholderView(for: "子模块", icon: "square.stack.3d.down.right", color: .purple)
            }
            
        case .branchItem(let branchName, let isRemote):
            if let branch = viewModel.branches.first(where: { $0.shortName == branchName && $0.isRemote == isRemote }) {
                branchDetailView(branch: branch)
            } else {
                Text("分支不存在")
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
            Button("返回本地分支") {
                viewModel.selectedFunctionItem = .expandableType(.localBranches)
                viewModel.expandedSections.insert(.localBranches)
            }
            .buttonStyle(.borderedProminent)
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
    
    private func branchListView(branches: [GitBranch], title: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(branches.count) 个分支")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            LazyVStack(spacing: 8) {
                ForEach(branches) { branch in
                    BranchRowView(
                        branch: branch,
                        isSelected: viewModel.selectedFunctionItem == .branchItem(branch.shortName, isRemote: branch.isRemote),
                        onSelect: {
                            viewModel.selectedFunctionItem = .branchItem(branch.shortName, isRemote: branch.isRemote)
                        }
                    )
                }
            }
            Spacer()
        }
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
            HistoryView(repository: repository)
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
            HistoryView(repository: repository)
        }
    }
}

// 移除Git数据加载扩展
// MARK: - 列表项组件

private struct BranchRowView: View {
    let branch: GitBranch
    let isSelected: Bool
    let onSelect: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: branch.isRemote ? "cloud" : "point.3.connected.trianglepath.dotted")
                    .font(.system(size: 14))
                    .foregroundStyle(branch.isRemote ? .blue : .green)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(branch.shortName)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        if branch.isCurrent {
                            Text("当前")
                                .font(.caption2)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.green)
                                .foregroundColor(.white)
                                .clipShape(Capsule())
                        }
                        Spacer()
                    }
                    if let sha = branch.targetSha {
                        Text(String(sha.prefix(8)))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        isSelected ? Color.accentColor.opacity(0.2) :
                        isHovered ? Color.primary.opacity(0.05) : Color.clear
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1)
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

#Preview {
    // 更新Preview以使用ViewModel
    RepositoryView(
        viewModel: MainViewModel.shared, // 使用共享实例
        repository: GitRepository(
            name: "FastGit", 
            path: "/Users/user/Documents/FastGit"
        )
    )
    .frame(width: 1000, height: 700)
}