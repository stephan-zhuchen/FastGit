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

    @State private var selectedCommitSha: String?
    
    @State private var commits: [GitCommit] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    // MARK: - Search State
    @State private var searchText = ""
    @State private var isCaseSensitive = false
    @State private var isWholeWord = false
    
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
            let patternToSearch = isCaseSensitive ? pattern : pattern.lowercased()
            let textToSearchIn = isCaseSensitive ? text : text.lowercased()
            if let regex = try? NSRegularExpression(pattern: "\\b\(NSRegularExpression.escapedPattern(for: patternToSearch))\\b") {
                let range = NSRange(textToSearchIn.startIndex..., in: textToSearchIn)
                return regex.firstMatch(in: textToSearchIn, options: [], range: range) != nil
            }
            return false
        } else {
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
                historyListView
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
    
    private var historyToolbar: some View {
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
    }

    private var listHeader: some View {
        HStack(spacing: 0) {
            Text("Description")
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
            Text("Author")
                .frame(width: 120, alignment: .leading)
                .padding(.horizontal, 8)
            Text("Commit")
                .frame(width: 100, alignment: .center)
                .padding(.horizontal, 8)
            Text("Date")
                .frame(width: 140, alignment: .trailing)
                .padding(.horizontal, 12)
        }
        .font(.subheadline)
        .fontWeight(.semibold)
        .foregroundStyle(.secondary)
        .padding(.vertical, 8)
    }
    
    // --- MODIFIED: 整个列表视图现在由 ScrollViewReader 包裹 ---
    private var historyListView: some View {
        VStack(spacing: 0) {
            historyToolbar
            Divider()
            
            VStack(spacing: 0) {
                listHeader
                Divider()
                // --- ADDED: 添加 ScrollViewReader ---
                ScrollViewReader { scrollViewProxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(filteredCommits.enumerated()), id: \.element.id) { index, commit in
                                // 将每一行内容放入一个 VStack 中，并为其添加 .id()
                                VStack(spacing: 0) {
                                    CommitTableRowView(commit: commit, isEven: index.isMultiple(of: 2))
                                        .background(selectedCommitSha == commit.sha ? Color.accentColor.opacity(0.2) : Color.clear)
                                        .onTapGesture {
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                if selectedCommitSha == commit.sha {
                                                    selectedCommitSha = nil
                                                } else {
                                                    selectedCommitSha = commit.sha
                                                }
                                            }
                                        }
                                    
                                    if selectedCommitSha == commit.sha {
                                        // --- MODIFIED: 传入 onSelectParent 回调 ---
                                        CommitDetailView(commit: commit, repository: repository, onSelectParent: { parentSha in
                                            // 使用 withAnimation 实现平滑滚动
                                            withAnimation(.easeInOut) {
                                                // 1. 更新选择项为父提交
                                                selectedCommitSha = parentSha
                                                // 2. 滚动到父提交的位置
                                                scrollViewProxy.scrollTo(parentSha, anchor: .center)
                                            }
                                        })
                                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                                    }
                                    
                                    Divider()
                                }
                                // --- ADDED: 为每一行设置唯一的 ID ---
                                .id(commit.sha)
                            }
                        }
                    }
                }
            }
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
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


#Preview {
    HistoryView(
        repository: GitRepository(
            name: "FastGit",
            path: "/Users/user/Documents/FastGit"
        )
    )
    .frame(width: 800, height: 600)
}

