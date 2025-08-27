//
//  HistoryView.swift
//  FastGit
//
//  Created by FastGit Team
//

import SwiftUI

/// 提交历史视图 (Refactored to be stateless)
struct HistoryView: View {
    let repository: GitRepository
    let commits: [Commit] // Data is now passed in
    
    // ViewModel to check loading state
    @ObservedObject private var viewModel = MainViewModel.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Check loading/empty state from the view model or passed-in data
            if viewModel.isLoading {
                loadingView
            } else if commits.isEmpty {
                emptyView
            } else {
                historyTableView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - 子视图
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("正在加载数据...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
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
    
    private var historyTableView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Table header
            HStack {
                Text("提交历史")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(commits.count) 个提交")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.quaternary)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.regularMaterial)
            
            Divider()
            
            // Table header row
            HStack(spacing: 0) {
                Text("路线图与主题")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                
                Text("作者")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .frame(width: 120, alignment: .leading)
                    .padding(.horizontal, 8)
                
                Text("提交指纹")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .frame(width: 100, alignment: .center)
                    .padding(.horizontal, 8)
                
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
            
            // Table content
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(commits.enumerated()), id: \.element.id) { index, commit in
                        CommitTableRowView(commit: commit, isEven: index % 2 == 0)
                            .onTapGesture {
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
}

#Preview {
    // Preview needs to be updated to provide mock commits
    HistoryView(
        repository: GitRepository(
            name: "FastGit",
            path: "/Users/user/Documents/FastGit"
        ),
        commits: [
            Commit(sha: "a1b2c3d4", message: "Initial commit", author: Author(name: "Test User", email: ""), date: Date(), parents: [], branches: ["main"], tags: ["v1.0"]),
            Commit(sha: "e5f6g7h8", message: "feat: Add new feature", author: Author(name: "Test User", email: ""), date: Date(), parents: ["a1b2c3d4"], branches: [], tags: [])
        ]
    )
    .frame(width: 800, height: 600)
}