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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
    /// - Parameter message: 错误信息
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
                    // 提交计数标签
                    Text("\(commits.count) 个提交")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.quaternary)
                        .clipShape(Capsule())
                    
                    // 刷新按钮
                    Button(action: {
                        Task {
                            await loadCommitHistory()
                        }
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
            
            // 表格头部
            HStack(spacing: 0) {
                // 提交信息列头
                Text("路线图与主题")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                
                // 作者列头
                Text("作者")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .frame(width: 120, alignment: .leading)
                    .padding(.horizontal, 8)
                
                // SHA列头
                Text("提交指纹")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .frame(width: 100, alignment: .center)
                    .padding(.horizontal, 8)
                
                // 时间列头
                Text("提交时间")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .frame(width: 140, alignment: .trailing)
                    .padding(.horizontal, 12)
            }
            .padding(.vertical, 8)
            .background(.quaternary.opacity(0.3))
            
            Divider()
            
            // 提交数据表格
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(commits.enumerated()), id: \.element.id) { index, commit in
                        CommitTableRowView(commit: commit, isEven: index % 2 == 0)
                            .onTapGesture {
                                // TODO: 选择提交处理
                                print("选择提交: \(commit.shortSha)")
                            }
                        
                        if index < commits.count - 1 {
                            Divider()
                                .padding(.leading, 12)
                        }
                    }
                }
            }
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