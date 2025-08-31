//
//  CommitDetailView.swift
//  FastGit
//
//  Created by FastGit Team on 2025/8/30.
//

import SwiftUI

/// 一个视图，用于显示单个 commit 的详细信息。
struct CommitDetailView: View {
    let commit: GitCommit
    let repository: GitRepository
    let onSelectParent: ((String) -> Void)?
    let onClose: (() -> Void)?

    enum FileListViewMode {
        case list, tree
    }
    @State private var viewMode: FileListViewMode = .list
    @State private var isTreeExpanded = true
    @State private var fileTree: [FileTreeNode] = []
    
    @State private var changedFiles: [GitFileStatus] = []
    @State private var isLoading = true
    
    private let gitService = GitService.shared
    
    init(commit: GitCommit, repository: GitRepository, onSelectParent: ((String) -> Void)? = nil, onClose: (() -> Void)? = nil) {
        self.commit = commit
        self.repository = repository
        self.onSelectParent = onSelectParent
        self.onClose = onClose
    }
    
    var body: some View {
        HStack(spacing: 0) {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    HStack(alignment: .top, spacing: 0) {
                        // 左侧面板: 提交详情
                        ScrollView {
                            VStack(alignment: .leading) {
                                detailGridView()
                                
                                Divider()
                                    .padding(.vertical, 8)
                                
                                Text(commit.message)
                                    .font(.system(.body, design: .monospaced))
                                    .textSelection(.enabled)
                            }
                            .padding()
                        }
                        .frame(minWidth: 400, idealWidth: 500)
                        
                        Divider()
                        
                        // 右侧面板: 变更文件列表
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Changed Files (\(changedFiles.count))")
                                .font(.headline)
                                .padding([.top, .leading, .trailing])
                                .padding(.bottom, 8)
                            
                            Divider()
                            
                            if viewMode == .list {
                                flatListView()
                            } else {
                                treeListView()
                            }
                        }
                        .frame(minWidth: 250)
                    }
                }
            }
            
            detailSidebar()
        }
        .frame(height: 300)
        .background(Color(nsColor: .windowBackgroundColor))
        .task {
            await loadChanges()
        }
    }
    
    @ViewBuilder
    private func flatListView() -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 8) {
                ForEach(changedFiles) { file in
                    FileStatusRow(file: file)
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    @ViewBuilder
    private func treeListView() -> some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(fileTree) { node in
                    FileTreeNodeView(node: node, level: 0)
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    @ViewBuilder
    private func detailSidebar() -> some View {
        VStack(spacing: 8) {
            SidebarButton(iconName: "xmark", tooltip: "关闭", action: { onClose?() })
            
            Divider()
            
            SidebarButton(iconName: "list.bullet", tooltip: "平铺视图", isActive: viewMode == .list, action: { viewMode = .list })
            SidebarButton(iconName: "folder", tooltip: "树形视图", isActive: viewMode == .tree, action: { viewMode = .tree })
            
            SidebarButton(iconName: isTreeExpanded ? "rectangle.compress.vertical" : "rectangle.expand.vertical", tooltip: isTreeExpanded ? "全部折叠" : "全部展开", isDisabled: viewMode != .tree) {
                isTreeExpanded.toggle()
                for node in fileTree {
                    node.toggleExpansion(shouldExpand: isTreeExpanded)
                }
            }
            
            Spacer()
        }
        .padding(8)
        .frame(width: 40)
        .frame(maxHeight: .infinity)
        .background(.regularMaterial)
    }
    
    @ViewBuilder
    private func detailGridView() -> some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
            GridRow {
                Text("Commit").gridColumnAlignment(.trailing).foregroundStyle(.secondary)
                Text(commit.sha).textSelection(.enabled)
            }
            
            GridRow(alignment: .top) {
                Text("Parents").gridColumnAlignment(.trailing).foregroundStyle(.secondary)
                VStack(alignment: .leading) {
                    if commit.parents.isEmpty {
                        Text("(root commit)").foregroundStyle(.secondary)
                    } else {
                        ForEach(commit.parents, id: \.self) { parentSha in
                            Button(action: { onSelectParent?(parentSha) }) {
                                Text(String(parentSha.prefix(10)))
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundStyle(.blue).textSelection(.enabled)
                            }.buttonStyle(.plain)
                        }
                    }
                }
            }
            
            GridRow {
                Text("Author").gridColumnAlignment(.trailing).foregroundStyle(.secondary)
                Text(commit.author.displayName).textSelection(.enabled)
            }
            
            GridRow {
                Text("Committer").gridColumnAlignment(.trailing).foregroundStyle(.secondary)
                Text(commit.author.displayName).textSelection(.enabled)
            }
            
            GridRow {
                Text("Date").gridColumnAlignment(.trailing).foregroundStyle(.secondary)
                Text(formattedDate(commit.date)).textSelection(.enabled)
            }
        }.font(.system(.body, design: .monospaced))
    }
    
    private func loadChanges() async {
        isLoading = true
        let files = await gitService.fetchChanges(for: commit, in: repository)
        self.changedFiles = files
        self.fileTree = FileTreeNode.buildTree(from: files)
        isLoading = false
    }
    
    private func formattedDate(_ date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "EEE MMM dd yyyy HH:mm:ss 'GMT'Z (zzzz)"
        return dateFormatter.string(from: date)
    }
}


// --- 辅助视图 ---

/// 文件状态行视图 (用于平铺和树形列表)
struct FileStatusRow: View {
    let file: GitFileStatus

    var body: some View {
        HStack(spacing: 8) {
            Text(file.status.rawValue)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.white)
                .frame(width: 20, height: 16)
                .background(file.status.displayColor)
                .clipShape(RoundedRectangle(cornerRadius: 3))
            
            // --- 修改点: 直接显示完整路径 ---
            Text(file.path)
                .truncationMode(.middle)
            
            Spacer()
        }
        .padding(.horizontal)
    }
}

/// 树形节点视图
struct FileTreeNodeView: View {
    @ObservedObject var node: FileTreeNode
    let level: Int
    
    private var isFolder: Bool { node.file == nil }
    private var indent: CGFloat { CGFloat(level * 16) }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Spacer().frame(width: indent)
                
                if isFolder {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(node.isExpanded ? 90 : 0))
                }
                
                Image(systemName: isFolder ? "folder" : "doc")
                    .foregroundStyle(isFolder ? .secondary : .primary)
                    .frame(width: 16)

                Text(node.name)
                
                Spacer()
                
                if let file = node.file {
                    Text(file.status.rawValue)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.white)
                        .frame(width: 20, height: 16)
                        .background(file.status.displayColor)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 4)
            .background(Color.primary.opacity(0.001)) // Make the whole area tappable
            .onTapGesture {
                if isFolder {
                    withAnimation {
                        node.isExpanded.toggle()
                    }
                }
            }
            
            if node.isExpanded {
                ForEach(node.children) { childNode in
                    FileTreeNodeView(node: childNode, level: level + 1)
                }
            }
        }
    }
}


/// 侧边栏按钮
struct SidebarButton: View {
    let iconName: String
    let tooltip: String
    var isActive: Bool = false
    var isDisabled: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: iconName)
                .font(.system(size: 14))
                .frame(width: 24, height: 24)
                .background(isActive ? Color.accentColor.opacity(0.2) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .foregroundStyle(isDisabled ? .tertiary : .primary)
        .help(tooltip)
    }
}

