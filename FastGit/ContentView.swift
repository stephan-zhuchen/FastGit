//
//  ContentView.swift
//  FastGit
//
//  Created by 朱晨 on 2025/8/23.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = MainViewModel.shared
    @StateObject private var repositoryManager = RepositoryManager.shared
    @State private var selectedTab = 0
    @State private var openRepositories: [GitRepository] = []  // 已打开的仓库列表
    @State private var nextTabId = 1  // 下一个Tab的ID
    
    var body: some View {
        VStack(spacing: 0) {
            // 自定义Tab栏
            CustomTabBar(
                selectedTab: $selectedTab,
                tabs: createTabItems(),
                onCloseTab: { tabId in
                    if tabId > 0, let repository = repositoryForTabId(tabId) {
                        closeRepository(repository)
                    }
                }
            )
            
            Divider()
            
            // 内容区域
            Group {
                if selectedTab == 0 {
                    // 欢迎页面
                    WelcomeView(
                        onOpenRepository: {
                            viewModel.showFilePicker()
                        },
                        onCloneRepository: {
                            // TODO: 实现克隆仓库功能
                            print("克隆仓库功能待实现")
                        },
                        onOpenRecentRepository: { url in
                            await openNewRepository(at: url)
                        }
                    )
                } else if let repository = repositoryForTabId(selectedTab) {
                    // 仓库视图
                    RepositoryView(
                        repository: repository,
                        onClose: nil  // 不再需要工具栏关闭按钮，Tab自带关闭
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .fileImporter(
            isPresented: $viewModel.showingFilePicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    Task {
                        await openNewRepository(at: url)
                    }
                }
            case .failure(let error):
                viewModel.errorMessage = "选择文件夹失败: \(error.localizedDescription)"
            }
        }
        .alert("错误", isPresented: .constant(viewModel.errorMessage != nil && viewModel.errorMessage!.contains("选择文件夹失败"))) {
            Button("确定") {
                viewModel.clearError()
            }
        } message: {
            if let errorMessage = viewModel.errorMessage, errorMessage.contains("选择文件夹失败") {
                Text(errorMessage)
            }
        }
        .onAppear {
            // 在应用启动时清理无效仓库
            repositoryManager.cleanupInvalidRepositories()
            // 确保应用启动时显示欢迎页面
            selectedTab = 0
        }
    }
    
    // MARK: - 私有方法
    
    /// 创建 Tab 项列表
    /// - Returns: Tab项数组
    private func createTabItems() -> [TabItem] {
        var items: [TabItem] = [
            TabItem(id: 0, title: "欢迎", icon: "house", isClosable: false)
        ]
        
        // 添加仓库Tab项
        for (index, repository) in openRepositories.enumerated() {
            items.append(
                TabItem(
                    id: index + 1,
                    title: repository.displayName,
                    icon: "folder",
                    isClosable: true
                )
            )
        }
        
        return items
    }
    
    /// 根据Tab ID查找对应的仓库
    /// - Parameter tabId: Tab ID
    /// - Returns: 对应的仓库，如果不存在则返回nil
    private func repositoryForTabId(_ tabId: Int) -> GitRepository? {
        let index = tabId - 1
        guard index >= 0 && index < openRepositories.count else {
            return nil
        }
        return openRepositories[index]
    }
    
    /// 打开新仓库
    /// - Parameter url: 仓库URL
    private func openNewRepository(at url: URL) async {
        // 检查仓库是否已经打开
        if let existingIndex = openRepositories.firstIndex(where: { $0.path == url.path }) {
            // 仓库已打开，直接切换到对应的Tab
            selectedTab = existingIndex + 1
            print("✅ 仓库已打开，切换到Tab: \(openRepositories[existingIndex].displayName)")
            return
        }
        
        // 直接创建仓库，不依赖MainViewModel的单一状态
        guard url.hasDirectoryPath else {
            viewModel.errorMessage = "请选择一个有效的文件夹"
            return
        }
        
        let path = url.path
        
        // 检查是否是Git仓库
        let gitPath = url.appendingPathComponent(".git").path
        guard FileManager.default.fileExists(atPath: gitPath) else {
            viewModel.errorMessage = "所选文件夹不是一个Git仓库"
            return
        }
        
        // 为新打开的仓库创建SecurityScopedBookmark
        let securityManager = SecurityScopedResourceManager.shared
        let bookmarkCreated = securityManager.createBookmark(for: url)
        if bookmarkCreated {
            print("✅ 已为新仓库创建安全书签: \(path)")
        } else {
            print("⚠️ 为新仓库创建安全书签失败: \(path)")
        }
        
        // 开始访问安全作用域资源
        let isAccessingSecurityScope = url.startAccessingSecurityScopedResource()
        print("🔐 安全作用域访问: \(isAccessingSecurityScope ? "成功" : "失败")")
        
        // 直接使用GitService打开仓库
        let gitService = GitService.shared
        if let newRepository = await gitService.openRepository(at: path) {
            // 将仓库添加到Tab列表
            openRepositories.append(newRepository)
            
            // 将仓库添加到RepositoryManager（新仓库排在第一位）
            repositoryManager.setCurrentRepositoryAsNew(newRepository)
            
            // 切换到新打开的Tab
            let newTabIndex = openRepositories.count
            selectedTab = newTabIndex
            
            print("✅ 新仓库已添加到Tab: \(newRepository.displayName), Tab索引: \(newTabIndex)")
        } else {
            // 如果打开失败，停止访问
            if isAccessingSecurityScope {
                url.stopAccessingSecurityScopedResource()
            }
            viewModel.errorMessage = "无法打开Git仓库"
        }
    }
    
    /// 关闭仓库Tab
    /// - Parameter repository: 要关闭的仓库
    private func closeRepository(_ repository: GitRepository) {
        guard let index = openRepositories.firstIndex(where: { $0.id == repository.id }) else {
            return
        }
        
        openRepositories.remove(at: index)
        
        // 如果关闭的是当前选中的Tab，切换到欢迎页面
        if selectedTab == index + 1 {
            selectedTab = 0
        } else if selectedTab > index + 1 {
            // 如果关闭的Tab在当前选中Tab之前，需要调整selectedTab
            selectedTab -= 1
        }
        
        print("✅ 仓库Tab已关闭: \(repository.displayName)")
    }
}

#Preview {
    ContentView()
}
