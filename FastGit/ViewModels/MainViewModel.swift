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
    
    // MARK: - 发布属性
    @Published var currentRepository: GitRepository?
    @Published var commits: [Commit] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showingFilePicker = false
    
    // MARK: - 私有属性
    private var repositoryURL: URL?
    private var isAccessingSecurityScopedResource = false
    
    // MARK: - 依赖
    private let gitService = GitService.shared
    
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
        
        // 开始访问安全作用域资源
        isAccessingSecurityScopedResource = url.startAccessingSecurityScopedResource()
        repositoryURL = url
        
        print("🔐 安全作用域访问: \(isAccessingSecurityScopedResource ? "成功" : "失败")")
        
        // 打开仓库
        if let repository = await gitService.openRepository(at: path) {
            self.currentRepository = repository
            
            // 获取提交历史
            await loadCommitHistory()
        } else {
            // 如果打开失败，停止访问
            stopAccessingCurrentRepository()
        }
    }
    
    /// 加载提交历史
    func loadCommitHistory() async {
        guard let repository = currentRepository else { return }
        
        isLoading = true
        commits = await gitService.fetchCommitHistory(for: repository)
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