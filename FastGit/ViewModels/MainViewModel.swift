//
//  MainViewModel.swift
//  FastGit
//
//  Created by FastGit Team
//

import Foundation
import SwiftUI

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
    @Published var selectedFunctionItem: SelectedFunctionItem? = .expandableType(.localBranches)
    @Published var expandedSections: Set<ExpandableFunctionType> = [.localBranches]

    // MARK: - Private Properties
    private var repositoryURL: URL?
    private var isAccessingSecurityScopedResource = false
    
    // ** ADDED: Data Cache **
    // ** 新增：数据缓存 **
    private var repositoryCache: [String: RepositoryDataCache] = [:]
    
    // MARK: - Dependencies
    private let gitService = GitService.shared
    private let repositoryManager = RepositoryManager.shared
    
    // MARK: - Initialization
    init() {
        // The setupBindings() call is no longer needed with the new architecture.
        // 在新的架构下不再需要 setupBindings() 调用。
    }
    
    // MARK: - Public Methods
    
    /// 打开仓库
    /// - Parameter url: 仓库URL
    func openRepository(at url: URL) async {
        // 停止之前的访问
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
                // Optionally, show an error to the user.
                // （可选）向用户显示错误。
            }
        }
        
        // 开始访问安全作用域资源
        isAccessingSecurityScopedResource = url.startAccessingSecurityScopedResource()
        repositoryURL = url
        
        print("🔐 安全作用域访问: \(isAccessingSecurityScopedResource ? "成功" : "失败")")
        
        if let repository = await gitService.openRepository(at: path) {
            self.currentRepository = repository
            repositoryManager.setCurrentRepositoryAsNew(repository)
            
            // ** MODIFICATION: Call the new caching data loader **
            // ** 修改：调用新的带缓存的数据加载方法 **
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
        
        // Fetch all data concurrently for better performance
        // 并发获取所有数据以提升性能
        async let historyData = gitService.fetchCommitHistory(for: repository)
        async let submoduleData = gitService.fetchSubmodules(for: repository)
        
        let (fetchedCommits, fetchedBranches, fetchedTags) = await historyData
        let fetchedSubmodules = await submoduleData

        self.commits = fetchedCommits
        self.branches = fetchedBranches
        self.tags = fetchedTags
        self.submodules = fetchedSubmodules // ** Update submodules **

        let newCacheEntry = RepositoryDataCache(
            branches: fetchedBranches,
            tags: fetchedTags,
            commits: fetchedCommits,
            submodules: fetchedSubmodules // ** Save to cache **
        )
        repositoryCache[repository.path] = newCacheEntry
        
        self.expandedSections = []
        self.selectedFunctionItem = .fixedOption(.defaultHistory)
        isLoading = false
    }

    /// Manually forces a refresh for the given repository.
    /// 为指定仓库手动强制刷新。
    func refreshData(for repository: GitRepository) async {
        print(" Manual refresh triggered for: \(repository.displayName)")
        repositoryCache.removeValue(forKey: repository.path)
        await loadRepositoryData(for: repository)
    }

    /// Clears the cache for a specific repository, e.g., when its tab is closed.
    /// 为特定仓库清除缓存（例如，当其标签页被关闭时）。
    func clearCache(for repository: GitRepository) {
        repositoryCache.removeValue(forKey: repository.path)
        print(" Cache cleared for repository: \(repository.displayName)")
    }
    
    /// 显示文件选择器
    func showFilePicker() {
        showingFilePicker = true
    }
    
    /// 清除错误信息
    func clearError() {
        errorMessage = nil
    }
    
    // MARK: - Private Methods
    
    /// 停止访问当前仓库的安全作用域资源
    private func stopAccessingCurrentRepository() {
        if isAccessingSecurityScopedResource, let url = repositoryURL {
            url.stopAccessingSecurityScopedResource()
            isAccessingSecurityScopedResource = false
            repositoryURL = nil
            print("🔓 已停止访问安全作用域资源")
        }
    }
    
    /// Updates all relevant @Published properties from a cache entry.
    /// 从一个缓存条目更新所有相关的 @Published 属性。
    private func updatePublishedProperties(from cache: RepositoryDataCache) {
        self.branches = cache.branches
        self.tags = cache.tags
        self.commits = cache.commits
        self.submodules = cache.submodules
    }
    
    // ** REMOVED: deinit is no longer safe or necessary here **
    // ** 移除：deinit 在这里不再安全或必要 **
    // deinit {
    //     stopAccessingCurrentRepository()
    // }
}

