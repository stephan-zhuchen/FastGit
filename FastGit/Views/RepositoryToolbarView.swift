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
        case .sync:
            return "arrow.triangle.2.circlepath"
        }
    }
    
    /// 是否已实现
    var isImplemented: Bool {
        // 当前都是预留功能
        return false
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
        case .sync:
            return "同步远程仓库"
        }
    }
}

/// 仓库工具栏视图
struct RepositoryToolbarView: View {
    let onClose: (() -> Void)?  // 关闭Tab的回调
    @State private var isLoading = false
    
    // 默认初始化方法，保持向后兼容
    init(onClose: (() -> Void)? = nil) {
        self.onClose = onClose
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // 工具栏标题
            HStack {
                Image(systemName: "hammer")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                Text("Git 操作")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Git操作按钮组
            HStack(spacing: 8) {
                ForEach(GitOperation.allCases, id: \.self) { operation in
                    ToolbarButton(
                        operation: operation,
                        isLoading: isLoading,
                        action: {
                            performGitOperation(operation)
                        }
                    )
                }
                
                // 分隔线
                if onClose != nil {
                    Divider()
                        .frame(height: 16)
                    
                    // 关闭Tab按钮
                    Button(action: {
                        onClose?()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help("关闭当前Tab")
                    .onHover { hovering in
                        // 可以添加悬停效果
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    // MARK: - 私有方法
    
    /// 执行Git操作
    /// - Parameter operation: 要执行的操作
    private func performGitOperation(_ operation: GitOperation) {
        guard operation.isImplemented else {
            print("⚠️ \(operation.rawValue)功能暂未实现")
            return
        }
        
        // 模拟操作执行
        withAnimation {
            isLoading = true
        }
        
        // TODO: 实现具体的Git操作
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                isLoading = false
            }
        }
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
                    .fill(
                        isHovered && operation.isImplemented 
                        ? Color.accentColor.opacity(0.1) 
                        : Color.clear
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(
                        isHovered && operation.isImplemented 
                        ? Color.accentColor.opacity(0.3) 
                        : Color.clear,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(!operation.isImplemented || isLoading)
        .opacity(operation.isImplemented ? 1.0 : 0.5)
        .help(operation.tooltip)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering && operation.isImplemented
            }
        }
    }
}

#Preview {
    RepositoryToolbarView()
        .padding()
}