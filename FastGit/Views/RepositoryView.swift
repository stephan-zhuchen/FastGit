//
//  RepositoryView.swift
//  FastGit
//
//  Created by FastGit Team
//

import SwiftUI

/// 仓库视图 - 实现三区域布局
struct RepositoryView: View {
    let repository: GitRepository
    let onClose: ((GitRepository) -> Void)?  // 关闭Tab的回调
    
    // 新的功能列表状态管理
    @State private var selectedFunctionItem: SelectedFunctionItem? = .expandableType(.localBranches)
    @State private var expandedSections: Set<ExpandableFunctionType> = [.localBranches]  // 默认展开本地分支
    
    // Git数据状态
    @State private var branches: [Branch] = []
    @State private var tags: [Tag] = []
    @State private var submodules: [String] = []  // 暂时为空
    @State private var isLoadingGitData = false
    
    // 默认初始化方法，保持向后兼容
    init(
        repository: GitRepository,
        onClose: ((GitRepository) -> Void)? = nil
    ) {
        self.repository = repository
        self.onClose = onClose
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // 左侧功能列表导航栏
            FunctionListView(
                selectedItem: $selectedFunctionItem,
                expandedSections: $expandedSections,
                repository: repository,
                branches: branches,
                tags: tags,
                submodules: submodules
            )
            
            Divider()
            
            // 右侧内容区域
            VStack(spacing: 0) {
                // 上方工具栏（不再显示关闭按钮）
                RepositoryToolbarView(onClose: nil)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                
                Divider()
                    .padding(.horizontal, 16)
                
                // 下方主体内容区域
                Group {
                    if let item = selectedFunctionItem {
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
        .task {
            await loadGitData()
        }
        .onChange(of: repository) { _, _ in
            Task {
                await loadGitData()
            }
        }
    }
    
    // MARK: - 子视图
    
    /// 根据选中的功能项返回对应的内容视图
    /// - Parameter item: 选中的功能项
    /// - Returns: 对应的视图
    @ViewBuilder
    private func contentView(for item: SelectedFunctionItem) -> some View {
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
                if branches.filter({ !$0.isRemote }).isEmpty {
                    emptyStateView(for: "本地分支", icon: "point.3.connected.trianglepath.dotted")
                } else {
                    branchListView(branches: branches.filter { !$0.isRemote }, title: "本地分支")
                }
            case .remoteBranches:
                if branches.filter({ $0.isRemote }).isEmpty {
                    emptyStateView(for: "远程分支", icon: "cloud")
                } else {
                    branchListView(branches: branches.filter { $0.isRemote }, title: "远程分支")
                }
            case .tags:
                if tags.isEmpty {
                    emptyStateView(for: "标签", icon: "tag")
                } else {
                    tagListView()
                }
            case .submodules:
                placeholderView(for: "子模块", icon: "square.stack.3d.down.right", color: .purple)
            }
            
        case .branchItem(let branchName, let isRemote):
            if let branch = branches.first(where: { $0.shortName == branchName && $0.isRemote == isRemote }) {
                branchDetailView(branch: branch)
            } else {
                Text("分支不存在")
                    .foregroundColor(.secondary)
            }
            
        case .tagItem(let tagName):
            if let tag = tags.first(where: { $0.name == tagName }) {
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
    
    /// 默认内容视图（无选择时显示）
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
    
    /// 占位符视图（用于未实现的功能）
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
                selectedFunctionItem = .expandableType(.localBranches)
                expandedSections.insert(.localBranches)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    /// 空状态视图
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
    
    /// 分支列表视图
    private func branchListView(branches: [Branch], title: String) -> some View {
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
                        isSelected: selectedFunctionItem == .branchItem(branch.shortName, isRemote: branch.isRemote),
                        onSelect: {
                            selectedFunctionItem = .branchItem(branch.shortName, isRemote: branch.isRemote)
                        }
                    )
                }
            }
            
            Spacer()
        }
    }
    
    /// 标签列表视图
    private func tagListView() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("标签列表")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(tags.count) 个标签")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            LazyVStack(spacing: 8) {
                ForEach(tags) { tag in
                    TagRowView(
                        tag: tag,
                        isSelected: selectedFunctionItem == .tagItem(tag.name),
                        onSelect: {
                            selectedFunctionItem = .tagItem(tag.name)
                        }
                    )
                }
            }
            
            Spacer()
        }
    }
    
    /// 分支详情视图
    private func branchDetailView(branch: Branch) -> some View {
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
    
    /// 标签详情视图
    private func tagDetailView(tag: Tag) -> some View {
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

// MARK: - Git数据加载
extension RepositoryView {
    /// 加载Git数据
    private func loadGitData() async {
        isLoadingGitData = true
        
        // 模拟分支数据（后续会替换为真实的GitService调用）
        branches = [
            Branch(name: "main", isCurrent: true, targetSha: "abc123"),
            Branch(name: "develop", isCurrent: false, targetSha: "def456"),
            Branch(name: "feature/new-ui", isCurrent: false, targetSha: "ghi789"),
            Branch(name: "origin/main", isRemote: true, targetSha: "abc123"),
            Branch(name: "origin/develop", isRemote: true, targetSha: "def456")
        ]
        
        // 模拟标签数据
        tags = [
            Tag(name: "v1.0.0", targetSha: "abc123", isAnnotated: true),
            Tag(name: "v1.1.0", targetSha: "def456", isAnnotated: true),
            Tag(name: "v0.9.0", targetSha: "xyz789", isAnnotated: false)
        ]
        
        // 模拟子模块数据（暂时为空）
        submodules = []
        
        isLoadingGitData = false
    }
}

// MARK: - 列表项组件

/// 分支行视图
private struct BranchRowView: View {
    let branch: Branch
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

/// 标签行视图
private struct TagRowView: View {
    let tag: Tag
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
    RepositoryView(
        repository: GitRepository(
            name: "FastGit", 
            path: "/Users/user/Documents/FastGit"
        )
    )
    .frame(width: 1000, height: 700)
}