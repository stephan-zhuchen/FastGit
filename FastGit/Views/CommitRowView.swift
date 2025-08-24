//
//  CommitRowView.swift
//  FastGit
//
//  Created by FastGit Team
//

import SwiftUI

/// 提交记录行视图 - 任务1.2: 提交历史可视化
/// 显示Commit的SHA（缩写）、提交信息、作者和日期
struct CommitRowView: View {
    let commit: Commit
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // SHA标识 - 使用单独样式突出显示
            Text(commit.shortSha)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.primary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(.quaternary, lineWidth: 1)
                )
            
            VStack(alignment: .leading, spacing: 6) {
                // 提交消息 - 主要内容
                Text(commit.message.trimmingCharacters(in: .whitespacesAndNewlines))
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                
                // 元数据：作者和时间信息
                HStack {
                    // 作者信息
                    Label {
                        Text(commit.author.name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } icon: {
                        Image(systemName: "person.crop.circle")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    
                    Spacer()
                    
                    // 时间信息
                    Label {
                        Text(commit.date.formatted(.relative(presentation: .named)))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    } icon: {
                        Image(systemName: "clock")
                            .font(.caption2)
                            .foregroundStyle(.quaternary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
    }
}

#Preview {
    List {
        CommitRowView(
            commit: Commit(
                sha: "abc123def456789",
                message: "Add new feature for repository management",
                author: Author(name: "John Doe", email: "john@example.com"),
                date: Date(),
                parents: ["def456abc789123"]
            )
        )
        CommitRowView(
            commit: Commit(
                sha: "def456abc789123",
                message: "Fix bug in commit history loading\n\nThis commit resolves the issue where commit history was not loading properly in some cases.",
                author: Author(name: "Jane Smith", email: "jane@example.com"),
                date: Date().addingTimeInterval(-3600),
                parents: []
            )
        )
    }
}