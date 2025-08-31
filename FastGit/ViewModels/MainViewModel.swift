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
    @Published var selectedFunctionItem: SelectedFunctionItem? = .fixedOption(.defaultHistory)
    @Published var expandedSections: Set<ExpandableFunctionType> = [.localBranches]

    // --- Toolbar State ---
    @Published var isPerformingToolbarAction = false
    @Published var showingNewBranchSheet = false
    @Published var hasUncommittedChanges = false
    @Published var newBranchOptions = NewBranchOptions(baseBranch: GitBranch(name: ""))

    
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
        
        let (fetchedCommits, fetchedBranches, fetchedTags) = await historyData
        let fetchedSubmodules = await submoduleData

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
            case .fetch, .pull, .sync:
                isPerformingToolbarAction = true
                await gitService.fetch(for: repository)
                await self.refreshData(for: repository)
                isPerformingToolbarAction = false
                
            case .newBranch:
                let statusItems = await gitService.fetchStatus(for: repository)
                // --- 最终修复点: 同时排除 .ignored 和 .untracked ---
                self.hasUncommittedChanges = statusItems.contains {
                    $0.displayStatus != .ignored && $0.displayStatus != .untracked
                }

                if let currentBranch = self.branches.first(where: { $0.isCurrent }) {
                    self.newBranchOptions = NewBranchOptions(baseBranch: currentBranch)
                    self.showingNewBranchSheet = true
                } else {
                    self.errorMessage = "无法确定当前分支以创建新分支。"
                }
                
            case .push:
                print("⚠️ Push functionality is not yet implemented.")
                break
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

