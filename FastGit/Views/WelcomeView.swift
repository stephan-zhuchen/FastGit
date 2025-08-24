//
//  WelcomeView.swift
//  FastGit
//
//  Created by FastGit Team
//

import SwiftUI
import AppKit

/// 欢迎界面视图
struct WelcomeView: View {
    let onOpenRepository: () -> Void
    let onCloneRepository: () -> Void
    @StateObject private var repositoryManager = RepositoryManager.shared
    
    var body: some View {
        VStack(spacing: 30) {
            // Logo和标题
            headerView
            
            // 操作按钮
            actionButtonsView
            
            // 最近仓库列表
            if repositoryManager.hasRecentRepositories {
                recentRepositoriesView
            }
            
            Spacer()
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            repositoryManager.cleanupInvalidRepositories()
        }
    }
    
    // MARK: - 子视图
    
    /// 头部标题区域
    private var headerView: some View {
        VStack(spacing: 16) {
            // Logo
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                
                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(.white)
            }
            
            VStack(spacing: 8) {
                Text("欢迎使用 FastGit")
                    .font(.largeTitle)
                    .fontWeight(.bold)
            }
        }
    }
    
    /// 操作按钮区域
    private var actionButtonsView: some View {
        HStack(spacing: 16) {
            Button(action: onOpenRepository) {
                HStack {
                    Image(systemName: "folder")
                    Text("打开本地仓库")
                }
                .frame(minWidth: 160)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            
            Button(action: onCloneRepository) {
                HStack {
                    Image(systemName: "square.and.arrow.down")
                    Text("克隆远程仓库")
                }
                .frame(minWidth: 160)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
    }
    
    /// 最近仓库列表
    private var recentRepositoriesView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("最近仓库")
                    .font(.headline)
                
                Spacer()
                
                Button("清除全部") {
                    repositoryManager.clearRecentRepositories()
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            
            // 可滚动的仓库列表（限制高度）
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(repositoryManager.recentRepositories.prefix(8), id: \.path) { repository in
                        RecentRepositoryRow(
                            repository: repository,
                            onSelect: {
                                Task {
                                    await openRecentRepository(repository)
                                }
                            },
                            onRemove: {
                                repositoryManager.removeRepository(repository)
                            }
                        )
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(maxHeight: 180) // 限制最大高度，避免挤压界面
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .frame(maxWidth: 450) // 略微增加宽度
    }
    
    // MARK: - 私有方法
    
    /// 打开最近仓库
    /// - Parameter repository: 要打开的仓库
    private func openRecentRepository(_ repository: GitRepository) async {
        // 检查仓库是否仍然存在
        guard repositoryManager.repositoryExists(at: repository.path) else {
            // 仓库不存在，从列表中移除
            repositoryManager.removeRepository(repository)
            return
        }
        
        // 优先尝试使用SecurityScopedResourceManager获取权限
        let securityManager = SecurityScopedResourceManager.shared
        if let secureURL = securityManager.getSecurityScopedURL(for: repository.path) {
            // 有已保存的权限，直接打开仓库
            openRepositoryWithSecureURL(secureURL, repository: repository)
            print("✅ 使用已保存的安全权限打开仓库: \(repository.displayName)")
        } else {
            // 没有保存的权限，请求用户授权
            print("⚠️ 需要为仓库重新获取访问权限: \(repository.displayName)")
            requestRepositoryAccess(for: repository)
        }
    }
    
    /// 请求仓库访问权限（使用更友好的方式）
    /// - Parameter repository: 需要权限的仓库
    private func requestRepositoryAccess(for repository: GitRepository) {
        // 使用SecurityScopedResourceManager来请求权限
        let securityManager = SecurityScopedResourceManager.shared
        
        if let secureURL = securityManager.getSecurityScopedURL(for: repository.path) {
            // 成功获取权限（可能是通过文件选择器）
            openRepositoryWithSecureURL(secureURL, repository: repository)
            print("✅ 成功获取仓库访问权限: \(repository.displayName)")
        } else {
            // 权限获取失败，用户可能取消了授权
            print("⚠️ 未能获取仓库访问权限: \(repository.displayName)")
            
            // 显示提示信息给用户
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "需要访问权限"
                alert.informativeText = "FastGit需要访问\"\(repository.displayName)\"仓库的权限才能继续操作。这是macOS安全要求。"
                alert.addButton(withTitle: "确定")
                alert.alertStyle = .informational
                alert.runModal()
            }
        }
    }
    
    /// 使用安全URL打开仓库
    /// - Parameters:
    ///   - url: 安全的仓库URL
    ///   - repository: 原始仓库信息（可选）
    private func openRepositoryWithSecureURL(_ url: URL, repository: GitRepository?) {
        let repositoryName = url.lastPathComponent
        let newRepository = GitRepository(name: repositoryName, path: url.path)
        
        // 设置当前仓库（使用不重排序的方法）
        repositoryManager.setCurrentRepositoryWithoutReordering(newRepository)
        
        // 如果这不是原始仓库，我们需要从最近列表中移除旧的记录
        if let original = repository, original.path != url.path {
            repositoryManager.removeRepository(original)
        }
        
        // 通知MainViewModel加载仓库（此时的URL已经有安全作用域权限）
        Task {
            let mainViewModel = MainViewModel.shared
            await mainViewModel.openRepository(at: url)
        }
    }
}

/// 最近仓库行视图
struct RecentRepositoryRow: View {
    let repository: GitRepository
    let onSelect: () -> Void
    let onRemove: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 12) {
            // 仓库图标
            Image(systemName: "folder")
                .foregroundStyle(.secondary)
                .font(.system(size: 16))
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(repository.displayName)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Text(repository.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            
            Spacer()
            
            if isHovered {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6) // 减少垂直内边距
        .background(isHovered ? Color(NSColor.selectedControlColor).opacity(0.3) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .onTapGesture(perform: onSelect)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

#Preview {
    WelcomeView(
        onOpenRepository: {
            print("打开仓库")
        },
        onCloneRepository: {
            print("克隆仓库")
        }
    )
}
