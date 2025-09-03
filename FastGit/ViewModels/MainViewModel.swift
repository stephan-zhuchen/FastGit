//
//  MainViewModel.swift
//  FastGit
//
//  Created by FastGit Team
//

import Foundation
import SwiftUI
// 新增: 导入 SwiftGitX 以使用新的 FetchOptions
import SwiftGitX

/// 主视图模型 - 管理应用的主要状态
@MainActor
class MainViewModel: ObservableObject {
    
    // MARK: - 单例
    static let shared = MainViewModel()
    
    // MARK: - Published Properties
    @Published var currentRepository: GitRepository?
    @Published var commits: [GitCommit] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showingFilePicker = false
    
    // MARK: - Function List State
    @Published var branches: [GitBranch] = []
    @Published var tags: [GitTag] = []
    @Published var submodules: [String] = []
    @Published var remotes: [String] = []
    @Published var selectedFunctionItem: SelectedFunctionItem? = .fixedOption(.defaultHistory)
    @Published var expandedSections: Set<ExpandableFunctionType> = [.localBranches]

    // --- Toolbar State ---
    @Published var isPerformingToolbarAction = false
    @Published var showingNewBranchSheet = false
    @Published var showingPullSheet = false
    @Published var showingStashSheet = false
    @Published var showingPushSheet = false
    @Published var showingFetchSheet = false
    @Published var hasUncommittedChanges = false
    @Published var newBranchOptions = NewBranchOptions(baseBranch: GitBranch(name: ""))
    @Published var pullOptions: PullOptions?
    @Published var stashOptions = StashOptions()
    @Published var pushOptions: PushOptions?
    // 更新：使用新的 UIFetchOptions 结构体
    @Published var fetchOptions = UIFetchOptions()

    
    // MARK: - Private Properties
    private var repositoryURL: URL?
    private var isAccessingSecurityScopedResource = false
    
    private var repositoryCache: [String: RepositoryDataCache] = [:]
    
    // MARK: - Dependencies
    private let gitService = GitService.shared
    private let repositoryManager = RepositoryManager.shared
    
    // MARK: - Initialization
    init() {}
    
    // MARK: - Public Methods
    
    /// 打开仓库
    /// - Parameter url: 仓库URL
    func openRepository(at url: URL) async {
        stopAccessingCurrentRepository()
        
        guard url.hasDirectoryPath else {
            errorMessage = "请选择一个有效的文件夹"
            return
        }
        
        let path = url.path
        
        let gitPath = url.appendingPathComponent(".git").path
        guard FileManager.default.fileExists(atPath: gitPath) else {
            errorMessage = "所选文件夹不是一个Git仓库"
            return
        }
        
        let securityManager = SecurityScopedResourceManager.shared
        if !securityManager.hasValidAccess(for: path) {
            let bookmarkCreated = securityManager.createBookmark(for: url)
            if !bookmarkCreated {
                print("⚠️ 为新仓库创建安全书签失败: \(path)")
            }
        }
        
        isAccessingSecurityScopedResource = url.startAccessingSecurityScopedResource()
        repositoryURL = url
        
        print("🔐 安全作用域访问: \(isAccessingSecurityScopedResource ? "成功" : "失败")")
        
        if let repository = await gitService.openRepository(at: path) {
            self.currentRepository = repository
            repositoryManager.setCurrentRepositoryAsNew(repository)
            await loadRepositoryData(for: repository)
        } else {
            stopAccessingCurrentRepository()
        }
    }
    
    func loadRepositoryData(for repository: GitRepository) async {
        if let cachedData = repositoryCache[repository.path] {
            print("✅ Using cached data for repository: \(repository.displayName)")
            updatePublishedProperties(from: cachedData)
            selectedFunctionItem = .fixedOption(.defaultHistory)
            return
        }

        print(" Sourcing new data for repository: \(repository.displayName)")
        isLoading = true
        
        async let historyData = gitService.fetchCommitHistory(for: repository)
        async let submoduleData = gitService.fetchSubmodules(for: repository)
        async let remotesData = gitService.listRemotes(for: repository)
        
        let (fetchedCommits, fetchedBranches, fetchedTags) = await historyData
        let fetchedSubmodules = await submoduleData
        self.remotes = await remotesData

        self.commits = fetchedCommits
        self.branches = fetchedBranches
        self.tags = fetchedTags
        self.submodules = fetchedSubmodules

        let newCacheEntry = RepositoryDataCache(
            branches: fetchedBranches,
            tags: fetchedTags,
            commits: fetchedCommits,
            submodules: fetchedSubmodules
        )
        repositoryCache[repository.path] = newCacheEntry
        
        self.expandedSections = []
        self.selectedFunctionItem = .fixedOption(.defaultHistory)
        isLoading = false
    }

    func refreshData(for repository: GitRepository) async {
        print(" Manual refresh triggered for: \(repository.displayName)")
        repositoryCache.removeValue(forKey: repository.path)
        await loadRepositoryData(for: repository)
    }

    func clearCache(for repository: GitRepository) {
        repositoryCache.removeValue(forKey: repository.path)
        print(" Cache cleared for repository: \(repository.displayName)")
    }
    
    func showFilePicker() {
        showingFilePicker = true
    }
    
    func clearError() {
        errorMessage = nil
    }
    
    // --- Toolbar Action Handlers ---
    
    /// 处理工具栏按钮点击事件
    func handleToolbarAction(_ operation: GitOperation, for repository: GitRepository) {
        Task {
            switch operation {
            case .fetch:
                // 初始化 UI 专用的 options
                self.fetchOptions = UIFetchOptions()
                self.showingFetchSheet = true

            case .pull:
                let statusItems = await gitService.fetchStatus(for: repository)
                self.hasUncommittedChanges = statusItems.contains {
                    $0.displayStatus != .ignored && $0.displayStatus != .untracked
                }
                
                guard let localBranch = branches.first(where: { $0.isCurrent }),
                      let remoteBranch = branches.first(where: { $0.isRemote && $0.shortName == localBranch.name }) else {
                    self.errorMessage = "无法找到当前分支或其对应的远程分支。"
                    return
                }
                
                self.pullOptions = PullOptions(remoteBranch: remoteBranch, localBranch: localBranch)
                self.showingPullSheet = true

            case .newBranch:
                let statusItems = await gitService.fetchStatus(for: repository)
                self.hasUncommittedChanges = statusItems.contains {
                    $0.displayStatus != .ignored && $0.displayStatus != .untracked
                }

                if let currentBranch = self.branches.first(where: { $0.isCurrent }) {
                    self.newBranchOptions = NewBranchOptions(baseBranch: currentBranch)
                    self.showingNewBranchSheet = true
                } else {
                    self.errorMessage = "无法确定当前分支以创建新分支。"
                }
            
            case .stash:
                self.stashOptions = StashOptions()
                self.showingStashSheet = true
                
            case .push:
                guard let localBranch = branches.first(where: { $0.isCurrent }) else {
                    self.errorMessage = "无法找到要推送的当前分支。"
                    return
                }
                
                let remoteBranch = branches.first { $0.isRemote && $0.shortName == localBranch.name }
                self.pushOptions = PushOptions(localBranch: localBranch, remoteBranch: remoteBranch)
                self.showingPushSheet = true
            }
        }
    }
    
    /// 创建新分支
    func createNewBranch(for repository: GitRepository) {
        let branchName = newBranchOptions.branchName.trimmingCharacters(in: .whitespaces)
        guard !branchName.isEmpty else { return }
        
        Task {
            isPerformingToolbarAction = true
            let success = await gitService.createBranch(name: branchName, options: newBranchOptions, in: repository)
            if success {
                await self.refreshData(for: repository)
            }
            isPerformingToolbarAction = false
        }
    }
    
    /// 执行 Pull 操作
    func performPull(for repository: GitRepository) {
        guard let options = pullOptions else { return }
        print("Performing pull with options: \(options)")
        
        Task {
            isPerformingToolbarAction = true
            await gitService.pull(with: options, in: repository)
            await self.refreshData(for: repository)
            isPerformingToolbarAction = false
        }
    }

    /// 执行 Stash 操作
    func performStash(for repository: GitRepository) {
        print("Performing stash with options: \(stashOptions)")
        Task {
            isPerformingToolbarAction = true
            await gitService.stash(with: stashOptions, in: repository)
            await self.refreshData(for: repository)
            isPerformingToolbarAction = false
        }
    }
    
    /// 执行 Push 操作
    func performPush(for repository: GitRepository) {
        guard let options = pushOptions else { return }
        print("Performing push with options: \(options)")
        Task {
            isPerformingToolbarAction = true
            await gitService.push(with: options, in: repository)
            await self.refreshData(for: repository)
            isPerformingToolbarAction = false
        }
    }
    
    /// 执行 Fetch 操作
    func performFetch(for repository: GitRepository) {
        print("Performing fetch with options: \(fetchOptions)")

        let securityManager = SecurityScopedResourceManager.shared
        
        guard securityManager.hasSshFolderAccess else {
            self.errorMessage = "SSH文件夹访问未授权。\n\n请前往 设置 > 高级，并授权应用访问您的.ssh文件夹，以便执行需要SSH密钥的操作。"
            isPerformingToolbarAction = false
            return
        }

        Task {
            isPerformingToolbarAction = true
            
            let accessStarted = securityManager.startAccessingSshFolder()
            defer {
                if accessStarted {
                    securityManager.stopAccessingSshFolder()
                    print("ℹ️ 已停止访问SSH文件夹")
                }
            }
            
            if !accessStarted {
                 self.errorMessage = "无法开始访问SSH文件夹，请在设置中重新授权。"
                 isPerformingToolbarAction = false
                 return
            }
            
            // 更新：将 UI-options 转换为库专用的 options
            let libraryFetchOptions = FetchOptions(
                prune: self.fetchOptions.prune,
                fetchAllTags: self.fetchOptions.fetchAllTags
            )

            // 更新：调用 GitService 时传递正确的参数
            await gitService.fetch(
                remote: self.fetchOptions.remote,
                with: libraryFetchOptions,
                in: repository
            )
            
            await self.refreshData(for: repository)
            
            isPerformingToolbarAction = false
        }
    }
    
    // MARK: - Private Methods
    
    private func stopAccessingCurrentRepository() {
        if isAccessingSecurityScopedResource, let url = repositoryURL {
            url.stopAccessingSecurityScopedResource()
            isAccessingSecurityScopedResource = false
            repositoryURL = nil
            print("🔓 已停止访问安全作用域资源")
        }
    }
    
    private func updatePublishedProperties(from cache: RepositoryDataCache) {
        self.branches = cache.branches
        self.tags = cache.tags
        self.commits = cache.commits
        self.submodules = cache.submodules
    }
}
