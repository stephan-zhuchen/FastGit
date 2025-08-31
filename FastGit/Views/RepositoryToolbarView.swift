//
//  RepositoryToolbarView.swift
//  FastGit
//
//  Created by FastGit Team
//

import SwiftUI

/// Git操作选项
enum GitOperation: String, CaseIterable {
    case pull = "Pull"
    case push = "Push"
    case fetch = "Fetch"
    case newBranch = "Branch" // 新增
    case sync = "同步"
    
    /// 图标名称
    var iconName: String {
        switch self {
        case .pull:
            return "arrow.down.circle"
        case .push:
            return "arrow.up.circle"
        case .fetch:
            return "arrow.clockwise.circle"
        case .newBranch:
            return "plus"
        case .sync:
            return "arrow.triangle.2.circlepath"
        }
    }
    
    /// 工具提示
    var tooltip: String {
        switch self {
        case .pull:
            return "从远程拉取更新"
        case .push:
            return "推送到远程仓库"
        case .fetch:
            return "获取远程更新"
        case .newBranch:
            return "创建新分支"
        case .sync:
            return "同步远程仓库"
        }
    }
}

/// 仓库工具栏视图
struct RepositoryToolbarView: View {
    @ObservedObject var viewModel: MainViewModel
    let repository: GitRepository
    
    var body: some View {
        HStack(spacing: 12) {
            HStack {
                Image(systemName: "hammer")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                Text("Git 操作")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                ForEach(GitOperation.allCases, id: \.self) { operation in
                    ToolbarButton(
                        operation: operation,
                        isLoading: viewModel.isPerformingToolbarAction,
                        action: {
                            viewModel.handleToolbarAction(operation, for: repository)
                        }
                    )
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

/// 工具栏按钮组件
private struct ToolbarButton: View {
    let operation: GitOperation
    let isLoading: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: operation.iconName)
                        .font(.system(size: 14, weight: .medium))
                }
                
                Text(operation.rawValue)
                    .font(.system(size: 13, weight: .medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovered ? Color.accentColor.opacity(0.1) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isHovered ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(operation == .push || isLoading)
        .opacity(operation == .push ? 0.5 : 1.0)
        .help(operation.tooltip)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}

