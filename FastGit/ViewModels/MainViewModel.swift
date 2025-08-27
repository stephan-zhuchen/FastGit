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
    
    // MARK: - 发布属性
    @Published var currentRepository: GitRepository?
    @Published var commits: [Commit] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showingFilePicker = false
    
    // MARK: - Function List State
    @Published var branches: [Branch] = []
    @Published var tags: [Tag] = []
    @Published var submodules: [String] = []
    @Published var selectedFunctionItem: SelectedFunctionItem? = .expandableType(.localBranches) {
        didSet {
            // 当选择项变化时，加载对应的提交历史
            Task {
                await loadHistoryForSelection()
            }
        }
    }
    @Published var expandedSections: Set<ExpandableFunctionType> = [.localBranches]

    // MARK: - 私有属性
    private var repositoryURL: URL?
    private var isAccessingSecurityScopedResource = false
    
    // MARK: - 依赖
    private let gitService = GitService.shared
    private let repositoryManager = RepositoryManager.shared
    
    // MARK: - 初始化
    init() {
        setupBindings()
    }
    
    // MARK: - 公共方法
    
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
        
        // 检查是否是Git仓库
        let gitPath = url.appendingPathComponent(".git").path
        guard FileManager.default.fileExists(atPath: gitPath) else {
            errorMessage = "所选文件夹不是一个Git仓库"
            return
        }
        
        // 为新打开的仓库创建SecurityScopedBookmark（关键修复）
        let securityManager = SecurityScopedResourceManager.shared
        let bookmarkCreated = securityManager.createBookmark(for: url)
        if bookmarkCreated {
            print("✅ 已为新仓库创建安全书签: \(path)")
        } else {
            print("⚠️ 为新仓库创建安全书签失败: \(path)")
        }
        
        // 开始访问安全作用域资源
        isAccessingSecurityScopedResource = url.startAccessingSecurityScopedResource()
        repositoryURL = url
        
        print("🔐 安全作用域访问: \(isAccessingSecurityScopedResource ? "成功" : "失败")")
        
        // 打开仓库
        if let repository = await gitService.openRepository(at: path) {
            self.currentRepository = repository
            
            // 将仓库添加到RepositoryManager（新仓库排在第一位）
            repositoryManager.setCurrentRepositoryAsNew(repository)
            
            // 获取仓库数据
            await loadRepositoryData()
        } else {
            // 如果打开失败，停止访问
            stopAccessingCurrentRepository()
        }
    }
    
    /// 加载仓库核心数据（提交、分支、标签等）
    func loadRepositoryData() async {
        guard let repository = currentRepository else { return }
        
        isLoading = true

        // 1. Fetch sidebar data first
        let (fetchedBranches, fetchedTags) = await gitService.fetchRepositorySidebarData(for: repository)
        self.branches = fetchedBranches
        self.tags = fetchedTags
        self.submodules = [] // Not implemented yet

        // 2. Fetch initial history from HEAD, using the sidebar data for annotations
        self.commits = await gitService.fetchHistory(for: repository, branches: fetchedBranches, tags: fetchedTags, startingFrom: nil)

        // 3. Reset selection state
        self.selectedFunctionItem = .expandableType(.localBranches)
        self.expandedSections = [.localBranches]

        isLoading = false
    }

    /// 根据当前选择项加载提交历史
    private func loadHistoryForSelection() async {
        guard let repository = currentRepository, let selection = selectedFunctionItem else { return }

        var targetSha: String?

        // 确定要加载历史的SHA
        switch selection {
        case .branchItem(let branchName, let isRemote):
            targetSha = branches.first { $0.shortName == branchName && $0.isRemote == isRemote }?.targetSha
        case .tagItem(let tagName):
            targetSha = tags.first { $0.name == tagName }?.targetSha
        default:
            // 如果选择的不是分支或标签，则不重新加载历史
            return
        }

        guard let sha = targetSha else {
            print("⚠️ 无法为选择项找到目标SHA: \(selection)")
            return
        }

        isLoading = true
        // 使用已有的分支和标签数据来获取特定SHA的历史
        self.commits = await gitService.fetchHistory(for: repository, branches: self.branches, tags: self.tags, startingFrom: sha)
        isLoading = false
    }
    
    /// 显示文件选择器
    func showFilePicker() {
        showingFilePicker = true
    }
    
    /// 清除错误信息
    func clearError() {
        errorMessage = nil
    }
    
    /// 停止访问当前仓库的安全作用域资源
    private func stopAccessingCurrentRepository() {
        if isAccessingSecurityScopedResource, let url = repositoryURL {
            url.stopAccessingSecurityScopedResource()
            isAccessingSecurityScopedResource = false
            repositoryURL = nil
            print("🔓 已停止访问安全作用域资源")
        }
    }
    
    deinit {
        // 使用Task.detached在主线程上执行清理操作
        let url = repositoryURL
        let isAccessing = isAccessingSecurityScopedResource
        
        if isAccessing, let url = url {
            url.stopAccessingSecurityScopedResource()
            print("🔓 在deinit中已停止访问安全作用域资源")
        }
    }
    
    // MARK: - 私有方法
    
    /// 设置数据绑定
    private func setupBindings() {
        // 监听GitService的状态变化
        gitService.$currentRepository
            .receive(on: DispatchQueue.main)
            .assign(to: &$currentRepository)
        
        gitService.$isLoading
            .receive(on: DispatchQueue.main)
            .assign(to: &$isLoading)
        
        gitService.$errorMessage
            .receive(on: DispatchQueue.main)
            .assign(to: &$errorMessage)
    }
}