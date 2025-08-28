//
//  CommitTableRowView.swift
//  FastGit
//
//  Created by FastGit Team
//

import SwiftUI

/// 提交历史表格行视图 - 模仿SourceGit的界面设计
struct CommitTableRowView: View {
    let commit: GitCommit
    let isEven: Bool
    
    var body: some View {
        HStack(spacing: 0) {
            // 路线图与主题列（包含分支和标签）
            roadmapAndSubjectColumn
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
            
            // 作者列
            authorColumn
                .frame(width: 120, alignment: .leading)
                .padding(.horizontal, 8)
            
            // SHA列
            shaColumn
                .frame(width: 100, alignment: .center)
                .padding(.horizontal, 8)
            
            // 时间列
            timeColumn
                .frame(width: 140, alignment: .trailing)
                .padding(.horizontal, 12)
        }
        .padding(.vertical, 8)
        .background(isEven ? Color.clear : Color.gray.opacity(0.05))
        .contentShape(Rectangle())
    }
    
    // MARK: - 列组件
    
    /// 路线图与主题列 - 显示分支、标签和提交信息
    private var roadmapAndSubjectColumn: some View {
        VStack(alignment: .leading, spacing: 4) {
            // 分支和标签引用
            if commit.hasReferences {
                referencesRow
            }
            
            // 提交信息
            commitMessageRow
        }
    }
    
    /// 分支和标签引用行
    private var referencesRow: some View {
        HStack(spacing: 4) {
            // 分支标签
            ForEach(commit.branches, id: \.self) { branchName in
                BranchTagBadge(
                    text: branchName,
                    type: .branch,
                    isLocalBranch: !branchName.contains("/")
                )
            }
            
            // 标签标签
            ForEach(commit.tags, id: \.self) { tagName in
                BranchTagBadge(
                    text: tagName,
                    type: .tag
                )
            }
            
            Spacer()
        }
    }
    
    /// 提交信息行
    private var commitMessageRow: some View {
        Text(commit.message.trimmingCharacters(in: .whitespacesAndNewlines))
            .font(.system(size: 13))
            .foregroundStyle(.primary)
            .lineLimit(1)
            .truncationMode(.tail)
    }
    
    /// 作者列
    private var authorColumn: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(commit.author.name)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }
    
    /// SHA列
    private var shaColumn: some View {
        Text(commit.shortSha)
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.gray.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
    
    /// 时间列
    private var timeColumn: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(formatCommitDate(commit.date))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - 辅助方法
    
    /// 格式化提交时间
    /// - Parameter date: 提交时间
    /// - Returns: 格式化的时间字符串
    private func formatCommitDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        let now = Date()
        let timeInterval = now.timeIntervalSince(date)
        
        if timeInterval < 60 {
            return "刚刚"
        } else if timeInterval < 3600 {
            let minutes = Int(timeInterval / 60)
            return "\(minutes)分钟前"
        } else if timeInterval < 86400 {
            let hours = Int(timeInterval / 3600)
            return "\(hours)小时前"
        } else if timeInterval < 2592000 { // 30天
            let days = Int(timeInterval / 86400)
            return "\(days)天前"
        } else {
            formatter.dateFormat = "yyyy/MM/dd"
            return formatter.string(from: date)
        }
    }
}

/// 分支/标签徽章类型
enum BadgeType {
    case branch
    case tag
}

/// 分支/标签徽章组件 - 类似SourceGit的样式
struct BranchTagBadge: View {
    let text: String
    let type: BadgeType
    let isLocalBranch: Bool
    
    init(text: String, type: BadgeType, isLocalBranch: Bool = true) {
        self.text = text
        self.type = type
        self.isLocalBranch = isLocalBranch
    }
    
    var body: some View {
        HStack(spacing: 2) {
            // 图标
            Image(systemName: iconName)
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(iconColor)
            
            // 文本
            Text(text)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(textColor)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .overlay(
            RoundedRectangle(cornerRadius: 3)
                .stroke(borderColor, lineWidth: 0.5)
        )
    }
    
    // MARK: - 样式计算属性
    
    private var iconName: String {
        switch type {
        case .branch:
            return isLocalBranch ? "arrow.branch" : "globe"
        case .tag:
            return "tag"
        }
    }
    
    private var iconColor: Color {
        switch type {
        case .branch:
            return isLocalBranch ? .green : .blue
        case .tag:
            return .orange
        }
    }
    
    private var textColor: Color {
        switch type {
        case .branch:
            return isLocalBranch ? .green : .blue
        case .tag:
            return .orange
        }
    }
    
    private var backgroundColor: Color {
        switch type {
        case .branch:
            return isLocalBranch ? Color.green.opacity(0.1) : Color.blue.opacity(0.1)
        case .tag:
            return Color.orange.opacity(0.1)
        }
    }
    
    private var borderColor: Color {
        switch type {
        case .branch:
            return isLocalBranch ? Color.green.opacity(0.3) : Color.blue.opacity(0.3)
        case .tag:
            return Color.orange.opacity(0.3)
        }
    }
}

#Preview {
    VStack(spacing: 1) {
        // 带分支和标签的提交
        CommitTableRowView(
            commit: GitCommit(
                sha: "a1b2c3d4e5f6789012345678901234567890abcd",
                message: "feat: add ncurses static lib",
                author: GitAuthor(name: "Zhu Chen", email: "zhu@example.com"),
                date: Date(),
                parents: [],
                branches: ["develop", "origin/develop"],
                tags: ["v1.15"]
            ),
            isEven: false
        )
        
        // 普通提交
        CommitTableRowView(
            commit: GitCommit(
                sha: "b2c3d4e5f6789012345678901234567890abcdef",
                message: "fix: Pe32 disassembly and iasl tool issue on Linux",
                author: GitAuthor(name: "Zhu Chen", email: "zhu@example.com"),
                date: Date().addingTimeInterval(-3600),
                parents: []
            ),
            isEven: true
        )
    }
    .frame(width: 800)
}