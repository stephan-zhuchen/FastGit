//
//  CommitRowView.swift
//  FastGit
//
//  Created by FastGit Team
//

import SwiftUI

/// 提交记录行视图
struct CommitRowView: View {
    let commit: Commit
    
    var body: some View {
        HStack(spacing: 12) {
            // SHA标识
            Text(commit.shortSha)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            
            VStack(alignment: .leading, spacing: 4) {
                // 提交消息
                Text(commit.message)
                    .font(.body)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                // 作者和时间信息
                HStack {
                    Text(commit.author.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Text(commit.date.formatted(.relative(presentation: .named)))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 4)
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