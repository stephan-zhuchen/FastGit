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
    // 新增：用于处理父提交点击事件的回调
    let onSelectParent: ((String) -> Void)?
    
    @State private var changedFiles: [GitFileStatus] = []
    @State private var isLoading = true
    
    private let gitService = GitService.shared
    
    // 更新初始化方法以接受回调
    init(commit: GitCommit, repository: GitRepository, onSelectParent: ((String) -> Void)? = nil) {
        self.commit = commit
        self.repository = repository
        self.onSelectParent = onSelectParent
    }
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(height: 250)
                    .frame(maxWidth: .infinity)
            } else {
                HStack(alignment: .top, spacing: 0) {
                    // --- MODIFIED: 使用 Grid 布局来优化左侧面板 ---
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
                            .padding()
                        
                        Divider()
                        
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 8) {
                                ForEach(changedFiles) { file in
                                    HStack {
                                        Text(file.status.rawValue)
                                            .font(.system(.caption, design: .monospaced))
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 4)
                                            .background(file.status.displayColor)
                                            .clipShape(RoundedRectangle(cornerRadius: 3))
                                        Text(file.path)
                                    }
                                    .padding(.horizontal)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    }
                    .frame(minWidth: 250)
                }
            }
        }
        .frame(height: 300)
        .background(Color(nsColor: .windowBackgroundColor))
        .task {
            await loadChanges()
        }
    }
    
    /// --- ADDED: 用于创建对齐网格视图的辅助方法 ---
    @ViewBuilder
    private func detailGridView() -> some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
            // Commit
            GridRow {
                Text("Commit")
                    .gridColumnAlignment(.trailing)
                    .foregroundStyle(.secondary)
                
                Text(commit.sha)
                    .textSelection(.enabled)
            }
            
            // Parents
            GridRow(alignment: .top) {
                Text("Parents")
                    .gridColumnAlignment(.trailing)
                    .foregroundStyle(.secondary)
                
                VStack(alignment: .leading) {
                    if commit.parents.isEmpty {
                        Text("(root commit)")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(commit.parents, id: \.self) { parentSha in
                            Button(action: {
                                onSelectParent?(parentSha)
                            }) {
                                Text(String(parentSha.prefix(10)))
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundStyle(.blue)
                                    .textSelection(.enabled)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            
            // Author
            GridRow {
                Text("Author")
                    .gridColumnAlignment(.trailing)
                    .foregroundStyle(.secondary)
                
                Text(commit.author.displayName)
                    .textSelection(.enabled)
            }
            
            // Committer (假设与 Author 相同)
            GridRow {
                Text("Committer")
                    .gridColumnAlignment(.trailing)
                    .foregroundStyle(.secondary)
                
                Text(commit.author.displayName)
                    .textSelection(.enabled)
            }
            
            // Date
            GridRow {
                Text("Date")
                    .gridColumnAlignment(.trailing)
                    .foregroundStyle(.secondary)
                
                Text(formattedDate(commit.date))
                    .textSelection(.enabled)
            }
        }
        .font(.system(.body, design: .monospaced))
    }
    
    private func loadChanges() async {
        isLoading = true
        changedFiles = await gitService.fetchChanges(for: commit, in: repository)
        isLoading = false
    }
    
    private func formattedDate(_ date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "EEE MMM dd yyyy HH:mm:ss 'GMT'Z (zzzz)"
        return dateFormatter.string(from: date)
    }
}

