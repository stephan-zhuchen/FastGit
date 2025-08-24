//
//  CommitTableRowView.swift
//  FastGit
//
//  Created by FastGit Team
//

import SwiftUI

/// 提交记录表格行视图 - 紧凑样式
/// 显示Commit的路线图、作者、提交指纹和提交时间
struct CommitTableRowView: View {
    let commit: Commit
    let isEven: Bool
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 0) {
            // 路线图与主题（提交信息）
            HStack(spacing: 8) {
                // 路线图图标
                Image(systemName: "circle.fill")
                    .font(.system(size: 6))
                    .foregroundStyle(.orange)
                
                // 连接线（如果不是第一个）
                Rectangle()
                    .fill(.orange.opacity(0.3))
                    .frame(width: 2, height: 20)
                    .offset(x: -3)
                
                // 提交信息
                Text(commit.message.trimmingCharacters(in: .whitespacesAndNewlines))
                    .font(.system(size: 13))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            
            // 作者
            HStack(spacing: 4) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
                
                Text(commit.author.name)
                    .font(.system(size: 13))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundStyle(.primary)
            }
            .frame(width: 120, alignment: .leading)
            .padding(.horizontal, 8)
            
            // 提交指纹（SHA）
            Text(commit.shortSha)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 100, alignment: .center)
                .padding(.horizontal, 8)
            
            // 提交时间
            Text(formatCommitDate(commit.date))
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(width: 140, alignment: .trailing)
                .padding(.horizontal, 12)
        }
        .padding(.vertical, 6)
        .background(rowBackground)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
    }
    
    // 行背景颜色
    private var rowBackground: some View {
        Group {
            if isHovered {
                Color.accentColor.opacity(0.08)
            } else if isEven {
                Color.clear
            } else {
                Color.primary.opacity(0.02)
            }
        }
    }
    
    // 格式化提交时间
    private func formatCommitDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd, HH:mm:ss"
        return formatter.string(from: date)
    }
}

#Preview {
    VStack(spacing: 0) {
        // 表格头部
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
        
        // 表格数据
        VStack(spacing: 0) {
            CommitTableRowView(
                commit: Commit(
                    sha: "9014e508192b4d5c7f8e6a3b9c2d8e4f",
                    message: "add ncurses static lib",
                    author: Author(name: "Zhu Chen", email: "zhu@example.com"),
                    date: Date(),
                    parents: []
                ),
                isEven: true
            )
            
            Divider()
                .padding(.leading, 12)
            
            CommitTableRowView(
                commit: Commit(
                    sha: "85051ca3db7f8e6a3b9c2d8e4f567890",
                    message: "add ncurses static library",
                    author: Author(name: "Zhu Chen", email: "zhu@example.com"),
                    date: Date().addingTimeInterval(-3600),
                    parents: []
                ),
                isEven: false
            )
            
            Divider()
                .padding(.leading, 12)
            
            CommitTableRowView(
                commit: Commit(
                    sha: "064be3dbd72c8e4f567890abcdef1234",
                    message: "fix compiler warning on Linux Cli build",
                    author: Author(name: "Zhu Chen", email: "zhu@example.com"),
                    date: Date().addingTimeInterval(-7200),
                    parents: []
                ),
                isEven: true
            )
        }
    }
    .background(.regularMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 10))
    .padding()
}