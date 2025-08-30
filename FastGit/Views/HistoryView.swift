//
//  HistoryView.swift
//  FastGit
//
//  Created by FastGit Team
//

import SwiftUI

/// 提交历史视图
struct HistoryView: View {
    let repository: GitRepository
    let startingSha: String?

    @State private var commits: [GitCommit] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    // 依赖
    private let gitService = GitService.shared
    
    // 初始化
    init(repository: GitRepository, startingSha: String? = nil) {
        self.repository = repository
        self.startingSha = startingSha
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isLoading {
                // 加载状态
                loadingView
            } else if let errorMessage = errorMessage, !errorMessage.isEmpty {
                // 错误状态
                errorView(errorMessage)
            } else if commits.isEmpty {
                // 空状态
                emptyView
            } else {
                // 提交历史表格
                historyTableView
            }
        }
        // 为整个视图设置最小宽度和高度，防止窗口过小导致内容显示不佳
        .frame(minWidth: 650, minHeight: 400)
        .onAppear {
            // 当历史视图出现时，加载当前仓库的提交历史
            Task {
                await loadCommitHistory()
            }
        }
        .onChange(of: repository) { _, _ in
            // 当仓库变化时，重新加载提交历史
            Task {
                await loadCommitHistory()
            }
        }
        .onChange(of: startingSha) { _, _ in
            // 当起点变化时，重新加载
            Task {
                await loadCommitHistory()
            }
        }
    }
    
    // MARK: - 子视图
    
    /// 加载状态视图
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("正在加载提交历史...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    /// 错误状态视图
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
            
            VStack(spacing: 8) {
                Text("加载失败")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(message)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            HStack(spacing: 12) {
                Button("重试") {
                    Task {
                        errorMessage = nil
                        await loadCommitHistory()
                    }
                }
                .buttonStyle(.borderedProminent)
                
                Button("关闭") {
                    errorMessage = nil
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    /// 空状态视图
    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.badge.questionmark")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("暂无提交记录")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("这个仓库可能是空的或者没有提交历史")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    /// 提交历史表格视图
    private var historyTableView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 表格标题栏
            HStack {
                Text("提交历史")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                HStack(spacing: 12) {
                    Text("\(commits.count) 个提交")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.quaternary)
                        .clipShape(Capsule())
                    
                    Button(action: {
                        Task { await loadCommitHistory() }
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(isLoading)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.regularMaterial)
            
            Divider()
            
            Table(commits) {
                // 1. 路线图与主题列 (Roadmap & Subject)
                TableColumn("路线图与主题", content: { commit in
                    VStack(alignment: .leading, spacing: 4) {
                        if commit.hasReferences {
                            HStack(spacing: 4) {
                                ForEach(commit.branches, id: \.self) { branchName in
                                    BranchTagBadge(text: branchName, type: .branch, isLocalBranch: !branchName.contains("/"))
                                }
                                ForEach(commit.tags, id: \.self) { tagName in
                                    BranchTagBadge(text: tagName, type: .tag)
                                }
                                Spacer()
                            }
                        }
                        Text(commit.message.trimmingCharacters(in: .whitespacesAndNewlines))
                            .font(.system(size: 13))
                    }
                    .padding(.vertical, 4)
                })
                .width(min: 250, ideal: 400)
                
                // 2. 作者列 (Author)
                TableColumn("作者", content: { commit in
                    Text(commit.author.name)
                })
                .width(min: 80, ideal: 120, max: 200)

                // 3. 提交指纹列 (SHA)
                TableColumn("提交指纹", content: { commit in
                    Text(commit.shortSha)
                        .font(.system(.body, design: .monospaced))
                })
                .width(min: 60, ideal: 60, max: 100)

                // 4. 提交时间列 (Date)
                TableColumn("提交时间", content: { commit in
                    Text(formatCommitDate(commit.date))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                })
                .width(min: 120, ideal: 120, max: 150)
            }
            .tableStyle(.inset(alternatesRowBackgrounds: true))
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    // MARK: - 私有方法
    
    /// 加载提交历史
    private func loadCommitHistory() async {
        isLoading = true
        errorMessage = nil
        
        let (fetchedCommits, _, _) = await gitService.fetchCommitHistory(for: repository, startingFromSha: startingSha)
        commits = fetchedCommits
        
        isLoading = false
    }
    
    private func formatCommitDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        // 设置日期格式为 "年-月-日 时:分:秒"
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }
}

#Preview {
    HistoryView(
        repository: GitRepository(
            name: "FastGit",
            path: "/Users/user/Documents/FastGit"
        )
    )
    .frame(width: 800, height: 600)
}
