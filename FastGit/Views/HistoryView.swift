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
    
    // MARK: - Search State
    @State private var searchText = ""
    @State private var isCaseSensitive = false
    @State private var isWholeWord = false
    
    @State private var tableID = UUID()
    
    // 依赖
    private let gitService = GitService.shared
    
    // 初始化
    init(repository: GitRepository, startingSha: String? = nil) {
        self.repository = repository
        self.startingSha = startingSha
    }

    // MARK: - Filtering Logic
    private var filteredCommits: [GitCommit] {
        if searchText.isEmpty {
            return commits
        }
        
        return commits.filter { commit in
            let targets = [commit.message, commit.author.name] + commit.branches + commit.tags
            
            for target in targets {
                if checkMatch(in: target, for: searchText) {
                    return true
                }
            }
            return false
        }
    }
    
    private func checkMatch(in text: String, for pattern: String) -> Bool {
        if isWholeWord {
            // Whole word matching logic
            let patternToSearch = isCaseSensitive ? pattern : pattern.lowercased()
            let textToSearchIn = isCaseSensitive ? text : text.lowercased()
            
            // Use regular expression for robust whole word search
            if let regex = try? NSRegularExpression(pattern: "\\b\(NSRegularExpression.escapedPattern(for: patternToSearch))\\b") {
                let range = NSRange(textToSearchIn.startIndex..., in: textToSearchIn)
                return regex.firstMatch(in: textToSearchIn, options: [], range: range) != nil
            }
            return false
        } else {
            // Substring matching logic
            if isCaseSensitive {
                return text.contains(pattern)
            } else {
                return text.localizedCaseInsensitiveContains(pattern)
            }
        }
    }

    // MARK: - Body
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isLoading {
                loadingView
            } else if let errorMessage = errorMessage, !errorMessage.isEmpty {
                errorView(errorMessage)
            } else if commits.isEmpty {
                emptyView
            } else {
                historyTableView
            }
        }
        .frame(minWidth: 650, minHeight: 400)
        .onAppear {
            Task { await loadCommitHistory() }
        }
        .onChange(of: repository) { _, _ in
            Task { await loadCommitHistory() }
        }
        .onChange(of: startingSha) { _, _ in
            Task { await loadCommitHistory() }
        }
    }
    
    // MARK: - Subviews
    
    private var historyTableView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 表格标题栏
            HStack {
                Text("提交历史")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                HStack(spacing: 12) {
                    CustomSearchBar(
                        searchText: $searchText,
                        isCaseSensitive: $isCaseSensitive,
                        isWholeWord: $isWholeWord
                    )
                    .frame(width: 200)

                    Text("\(filteredCommits.count) 个提交")
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
            
            Table(filteredCommits) {
                // ... (Table columns remain the same)
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
                
                TableColumn("作者", content: { commit in Text(commit.author.name) })
                .width(min: 80, ideal: 120, max: 200)

                TableColumn("提交指纹", content: { commit in Text(commit.shortSha).font(.system(.body, design: .monospaced)) })
                .width(min: 60, ideal: 60, max: 100)

                TableColumn("提交时间", content: { commit in Text(formatCommitDate(commit.date)).frame(maxWidth: .infinity, alignment: .trailing) })
                .width(min: 120, ideal: 120, max: 150)
            }
            .id(tableID)
            .tableStyle(.inset(alternatesRowBackgrounds: true))
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .onChange(of: searchText) { _, _ in tableID = UUID() }
        .onChange(of: isCaseSensitive) { _, _ in tableID = UUID() }
        .onChange(of: isWholeWord) { _, _ in tableID = UUID() }
    }
    
    // ... (loadingView, errorView, emptyView remain the same)
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView().scaleEffect(1.2)
            Text("正在加载提交历史...").font(.headline).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity).background(.regularMaterial).clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle").font(.system(size: 48)).foregroundStyle(.orange)
            VStack(spacing: 8) {
                Text("加载失败").font(.headline).foregroundColor(.primary)
                Text(message).font(.body).foregroundColor(.secondary).multilineTextAlignment(.center).padding(.horizontal)
            }
            HStack(spacing: 12) {
                Button("重试") { Task { errorMessage = nil; await loadCommitHistory() } }.buttonStyle(.borderedProminent)
                Button("关闭") { errorMessage = nil }.buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity).background(.regularMaterial).clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.badge.questionmark").font(.system(size: 48)).foregroundStyle(.tertiary)
            Text("暂无提交记录").font(.headline).foregroundColor(.secondary)
            Text("这个仓库可能是空的或者没有提交历史").font(.caption).foregroundStyle(.tertiary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity).background(.regularMaterial).clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    // MARK: - Helper Methods
    
    private func loadCommitHistory() async {
        isLoading = true
        errorMessage = nil
        let (fetchedCommits, _, _) = await gitService.fetchCommitHistory(for: repository, startingFromSha: startingSha)
        commits = fetchedCommits
        isLoading = false
    }
    
    private func formatCommitDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }
}

// ** REMOVED: Custom search components are now in SharedViews.swift **
// ** 移除：自定义搜索组件现在位于 SharedViews.swift 文件中 **

#Preview {
    HistoryView(
        repository: GitRepository(
            name: "FastGit",
            path: "/Users/user/Documents/FastGit"
        )
    )
    .frame(width: 800, height: 600)
}

