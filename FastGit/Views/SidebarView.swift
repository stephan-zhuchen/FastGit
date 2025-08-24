//
//  SidebarView.swift
//  FastGit
//
//  Created by FastGit Team
//

import SwiftUI
import AppKit

/// 侧边栏视图
struct SidebarView: View {
    @StateObject private var repositoryManager = RepositoryManager.shared
    @Binding var selectedRepository: GitRepository?
    let onOpenRepository: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 头部
            headerView
            
            Divider()
            
            // 仓库列表
            repositoriesListSection
            
            Spacer()
                .contentShape(Rectangle())
                .onTapGesture {
                    deselectRepository()
                }
            
            // 底部操作区域
            bottomActionsView
        }
        .frame(minWidth: 200, maxWidth: 300)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    // MARK: - 子视图
    
    /// 头部标题
    private var headerView: some View {
        HStack {
            Text("FastGit")
                .font(.title2)
                .fontWeight(.bold)
            
            Spacer()
            
            Button(action: onOpenRepository) {
                Image(systemName: "plus")
            }
            .buttonStyle(.borderless)
            .help("打开新仓库")
        }
        .padding()
    }
    
    /// 仓库列表区域
    private var repositoriesListSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("仓库列表")
                    .font(.headline)
                    .padding(.horizontal)
                
                Spacer()
                
                if repositoryManager.hasRecentRepositories {
                    Menu {
                        Button("清除全部") {
                            // 清除所有仓库和当前状态（RepositoryManager会处理当前仓库清除）
                            repositoryManager.clearRecentRepositories()
                            // 清除侧边栏选择状态
                            selectedRepository = nil
                        }
                        Button("清理无效仓库") {
                            repositoryManager.cleanupInvalidRepositories()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .buttonStyle(.borderless)
                    .padding(.trailing)
                }
            }
            
            if repositoryManager.hasRecentRepositories {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(repositoryManager.recentRepositories, id: \.path) { repository in
                            SidebarRepositoryRow(
                                repository: repository,
                                isCurrentRepository: repositoryManager.currentRepository?.path == repository.path,
                                isSelected: selectedRepository?.path == repository.path,
                                onSelect: {
                                    selectRepository(repository)
                                },
                                onRemove: {
                                    // 移除仓库和清理状态（关键修复）
                                    let wasCurrentRepository = repositoryManager.currentRepository?.path == repository.path
                                    let wasSelectedRepository = selectedRepository?.path == repository.path
                                    
                                    // 从列表中移除仓库
                                    repositoryManager.removeRepository(repository)
                                    
                                    // 如果移除的是当前选中的仓库，清理所有相关状态
                                    if wasCurrentRepository || wasSelectedRepository {
                                        selectedRepository = nil
                                        repositoryManager.setCurrentRepository(nil)
                                        
                                        // 清理MainViewModel状态（关键修复）
                                        Task {
                                            let mainViewModel = MainViewModel.shared
                                            mainViewModel.currentRepository = nil
                                            mainViewModel.commits.removeAll()
                                        }
                                    }
                                }
                            )
                        }
                    }
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "folder.badge.plus")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    
                    Text("暂无仓库")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    
                    Text("点击下方按钮打开您的第一个Git仓库")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            }
        }
    }
    
    /// 底部操作区域
    private var bottomActionsView: some View {
        VStack(spacing: 8) {
            Divider()
            
            Button(action: onOpenRepository) {
                HStack {
                    Image(systemName: "folder.badge.plus")
                    Text("打开仓库")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .padding(.horizontal)
            .padding(.bottom)
        }
    }
    
    // MARK: - 私有方法
    
    /// 取消选择仓库（显示欢迎界面）
    private func deselectRepository() {
        selectedRepository = nil
        repositoryManager.setCurrentRepository(nil)
        print("✅ 已取消仓库选择，显示欢迎界面")
    }
    
    /// 选择仓库
    /// - Parameter repository: 要选择的仓库
    private func selectRepository(_ repository: GitRepository) {
        // 检查仓库路径是否仍然有效
        guard repositoryManager.repositoryExists(at: repository.path) else {
            // 仓库路径无效，从列表中移除
            repositoryManager.removeRepository(repository)
            return
        }
        
        // 更新选择状态（但不更新当前仓库，直到实际打开）
        selectedRepository = repository

        // 优先尝试使用SecurityScopedResourceManager获取权限
        let securityManager = SecurityScopedResourceManager.shared
        if let secureURL = securityManager.getSecurityScopedURL(for: repository.path) {
            // 有已保存的权限，直接打开仓库
            openRepositoryWithSecureURL(secureURL, repository: repository)
            print("✅ 使用已保存的安全权限打开仓库: \(repository.displayName)")
        } else {
            // 没有保存的权限，显示友好的权限请求
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
        print("📁 开始打开仓库: \(url.lastPathComponent)")
        repositoryManager.debugPrintRepositoryOrder()
        
        // 对于已存在的仓库，直接使用原始对象，且不修改列表
        if let originalRepository = repository {
            // 仅更新选择状态和当前仓库引用（不修改列表）
            selectedRepository = originalRepository
            repositoryManager.setCurrentRepositoryReference(originalRepository)
            
            print("📁 打开后的仓库列表:")
            repositoryManager.debugPrintRepositoryOrder()
            
            // 通知MainViewModel加载仓库（此时的URL已经有安全作用域权限）
            Task {
                let mainViewModel = MainViewModel.shared
                await mainViewModel.openRepository(at: url)
            }
        } else {
            // 如果没有原始仓库信息，创建新的仓库对象（这种情况很少见）
            let repositoryName = url.lastPathComponent
            let newRepository = GitRepository(name: repositoryName, path: url.path)
            
            // 更新选择状态和当前仓库
            selectedRepository = newRepository
            repositoryManager.setCurrentRepositoryWithoutReordering(newRepository)
            
            print("📁 创建新仓库后的列表:")
            repositoryManager.debugPrintRepositoryOrder()
            
            // 通知MainViewModel加载仓库
            Task {
                let mainViewModel = MainViewModel.shared
                await mainViewModel.openRepository(at: url)
            }
        }
    }
}

/// 侧边栏仓库行视图
struct SidebarRepositoryRow: View {
    let repository: GitRepository
    let isCurrentRepository: Bool // 是否为当前打开的仓库
    let isSelected: Bool
    let onSelect: () -> Void
    let onRemove: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        HStack {
            // 仓库图标 - 当前仓库使用实心图标
            Image(systemName: isCurrentRepository ? "folder.fill" : "folder")
                .foregroundStyle(isCurrentRepository ? .blue : .secondary)
                .frame(width: 16)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(repository.displayName)
                        .font(.body)
                        .fontWeight(isCurrentRepository ? .medium : .regular)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    
                    // 当前仓库标识
                    if isCurrentRepository {
                        Text("当前")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue)
                            .clipShape(Capsule())
                    }
                }
                
                Text(repository.path)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            
            Spacer()
            
            if isHovered {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .help("从列表中移除")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Group {
                if isCurrentRepository {
                    // 当前仓库的背景高亮
                    Color.blue.opacity(0.1)
                } else if isHovered {
                    // 悬停时的背景
                    Color(NSColor.controlAccentColor).opacity(0.1)
                } else {
                    Color.clear
                }
            }
        )
        .overlay(
            // 当前仓库的左侧边框高亮
            isCurrentRepository ? 
            Rectangle()
                .fill(Color.blue)
                .frame(width: 3)
                .offset(x: -12)
            : nil,
            alignment: .leading
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .padding(.horizontal, 8)
        .onTapGesture(perform: onSelect)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

#Preview {
    SidebarView(
        selectedRepository: .constant(nil),
        onOpenRepository: {
            print("打开仓库")
        }
    )
    .frame(width: 250, height: 400)
}