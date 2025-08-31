//
//  ContentView.swift
//  FastGit
//
//  Created by FastGit Team
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = MainViewModel.shared
    @StateObject private var repositoryManager = RepositoryManager.shared
    @State private var selectedTab = 0
    @State private var openRepositories: [GitRepository] = []
    
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
                            print("克隆仓库功能待实现")
                        },
                        onOpenRecentRepository: { url in
                            await openNewRepository(at: url)
                        }
                    )
                    // 在欢迎页面的右下角添加一个设置按钮
                    .overlay(alignment: .bottomTrailing) {
                        // 使用 SettingsLink 来确保能正确打开设置窗口
                        if #available(macOS 14.0, *) {
                            SettingsLink {
                                Image(systemName: "gear")
                                    .font(.title2)
                                    .padding()
                            }
                            .buttonStyle(.plain)
                            .padding()
                        } else {
                            // Fallback for older macOS versions
                            Button(action: {
                                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                            }) {
                                Image(systemName: "gear")
                                    .font(.title2)
                                    .padding()
                            }
                            .buttonStyle(.plain)
                            .padding()
                        }
                    }
                } else if let repository = repositoryForTabId(selectedTab) {
                    // ** FIX: Pass the onOpenSubmodule callback to RepositoryView **
                    // ** 修复：将 onOpenSubmodule 回调传递给 RepositoryView **
                    RepositoryView(
                        viewModel: viewModel,
                        repository: repository,
                        onClose: { _ in
                            closeRepository(repository)
                        },
                        onOpenSubmodule: { submoduleURL in
                            // When a submodule is double-clicked, call the same logic
                            // as opening a new repository.
                            // 当子模块被双击时，调用与打开新仓库相同的逻辑。
                            Task {
                                await openNewRepository(at: submoduleURL)
                            }
                        }
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
        .alert("错误", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("确定") {
                viewModel.clearError()
            }
        } message: {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
            }
        }
        .onAppear {
            repositoryManager.cleanupInvalidRepositories()
            selectedTab = 0
        }
        .onChange(of: selectedTab) { _, newTabId in
            Task {
                if let repository = repositoryForTabId(newTabId) {
                    // If switching to a new repository tab, notify the ViewModel.
                    // The cache will prevent redundant reloads.
                    // 如果切换到一个仓库标签页，通知 ViewModel。缓存机制会防止重复加载。
                    await viewModel.loadRepositoryData(for: repository)
                    viewModel.currentRepository = repository
                } else {
                    // Switched to Welcome View, clear the data.
                    // 切换到欢迎页面，清空数据。
                    viewModel.currentRepository = nil
                    viewModel.commits = []
                    viewModel.branches = []
                    viewModel.tags = []
                    viewModel.submodules = []
                }
            }
        }
    }
    
    // MARK: - 私有方法
    
    private func createTabItems() -> [TabItem] {
        var items: [TabItem] = [
            TabItem(id: 0, title: "欢迎", icon: "house", isClosable: false)
        ]
        
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
    
    private func repositoryForTabId(_ tabId: Int) -> GitRepository? {
        let index = tabId - 1
        guard index >= 0 && index < openRepositories.count else {
            return nil
        }
        return openRepositories[index]
    }
    
    /// 打开新仓库 - 重构为使用ViewModel
    private func openNewRepository(at url: URL) async {
        // 检查仓库是否已经打开
        if let existingIndex = openRepositories.firstIndex(where: { $0.path == url.path }) {
            selectedTab = existingIndex + 1
            print("✅ 仓库已打开，切换到Tab: \(openRepositories[existingIndex].displayName)")
            return
        }
        
        // 使用ViewModel打开仓库
        await viewModel.openRepository(at: url)
        
        // 如果成功，将仓库添加到Tab列表
        if let newRepository = viewModel.currentRepository {
            openRepositories.append(newRepository)
            selectedTab = openRepositories.count
        }
    }
    
    private func closeRepository(_ repository: GitRepository) {
        guard let index = openRepositories.firstIndex(where: { $0.id == repository.id }) else {
            return
        }
        
        let closingTabId = index + 1
        
        // Clear cache for the closed repository
        viewModel.clearCache(for: repository)
        
        openRepositories.remove(at: index)
        
        if selectedTab == closingTabId {
            selectedTab = 0
        } else if selectedTab > closingTabId {
            selectedTab -= 1
        }
        
        print("✅ 仓库Tab已关闭: \(repository.displayName)")
    }
}

#Preview {
    ContentView()
}

