//
//  RepositoryManager.swift
//  FastGit
//
//  Created by FastGit Team
//

import Foundation
import Combine

/// 仓库管理器 - 负责管理已打开的仓库和应用状态持久化
@MainActor
class RepositoryManager: ObservableObject {
    
    // MARK: - 单例
    static let shared = RepositoryManager()
    
    // MARK: - 发布属性
    @Published var recentRepositories: [GitRepository] = []
    @Published var currentRepository: GitRepository?
    
    // MARK: - 私有属性
    private let userDefaults = UserDefaults.standard
    private let maxRecentRepositories = 10
    private let securityManager = SecurityScopedResourceManager.shared
    
    // MARK: - 初始化
    private init() {
        loadRecentRepositories()
        loadLastOpenedRepository()
    }
    
    // MARK: - 仓库管理
    
    /// 添加新仓库到最近列表（新仓库排在第一位）
    /// - Parameter repository: 要添加的新仓库
    func addNewRepository(_ repository: GitRepository) {
        // 移除重复项
        recentRepositories.removeAll { $0.path == repository.path }
        
        // 添加到列表开头（新仓库优先显示）
        recentRepositories.insert(repository, at: 0)
        
        // 限制列表长度
        if recentRepositories.count > maxRecentRepositories {
            recentRepositories = Array(recentRepositories.prefix(maxRecentRepositories))
        }
        
        // 保存到UserDefaults
        saveRecentRepositories()
        
        print("✅ 新仓库已添加到列表首位: \(repository.displayName)")
    }
    
    /// 设置当前仓库
    /// - Parameter repository: 当前仓库
    func setCurrentRepository(_ repository: GitRepository?) {
        currentRepository = repository
        
        if let repository = repository {
            // 保存最后打开的仓库
            userDefaults.set(repository.path, forKey: AppConfig.UserDefaultsKeys.lastOpenedRepository)
            
            // 添加到最近列表（新仓库排在首位）
            addNewRepository(repository)
            
            print("✅ 当前仓库已设置: \(repository.displayName)")
        } else {
            userDefaults.removeObject(forKey: AppConfig.UserDefaultsKeys.lastOpenedRepository)
            print("✅ 当前仓库已清除")
        }
    }
    
    /// 设置当前仓库（不重新排序到首位）
    /// - Parameter repository: 当前仓库
    func setCurrentRepositoryWithoutReordering(_ repository: GitRepository?) {
        currentRepository = repository
        
        if let repository = repository {
            // 保存最后打开的仓库
            userDefaults.set(repository.path, forKey: AppConfig.UserDefaultsKeys.lastOpenedRepository)
            
            // 检查仓库是否已存在于列表中
            if let index = recentRepositories.firstIndex(where: { $0.path == repository.path }) {
                let existingRepo = recentRepositories[index]
                print("📝 检查仓库更新:")
                print("  - 原有时间: \(existingRepo.lastOpened)")
                print("  - 新的时间: \(repository.lastOpened)")
                print("  - 位置: \(index)")
                
                // 只有当时间不同时才更新，避免不必要的数据写入
                if existingRepo.lastOpened != repository.lastOpened {
                    recentRepositories[index] = repository
                    saveRecentRepositories()
                    print("✅ 仓库时间已更新（不重排序）: \(repository.displayName)")
                } else {
                    print("✅ 仓库时间相同，跳过更新: \(repository.displayName)")
                }
            } else {
                // 新仓库：添加到列表末尾（不重排序到首位）
                recentRepositories.append(repository)
                
                // 限制列表长度
                if recentRepositories.count > maxRecentRepositories {
                    recentRepositories = Array(recentRepositories.prefix(maxRecentRepositories))
                }
                
                saveRecentRepositories()
                print("✅ 新仓库已添加到列表末尾: \(repository.displayName)")
            }
        } else {
            userDefaults.removeObject(forKey: AppConfig.UserDefaultsKeys.lastOpenedRepository)
            print("✅ 当前仓库已清除")
        }
    }
    
    /// 设置当前仓库为新仓库（添加到列表首位）
    /// - Parameter repository: 新打开的仓库
    func setCurrentRepositoryAsNew(_ repository: GitRepository?) {
        currentRepository = repository
        
        if let repository = repository {
            // 保存最后打开的仓库
            userDefaults.set(repository.path, forKey: AppConfig.UserDefaultsKeys.lastOpenedRepository)
            
            // 添加新仓库到列表首位
            addNewRepository(repository)
            
            print("✅ 新仓库已设置为当前仓库: \(repository.displayName)")
        } else {
            userDefaults.removeObject(forKey: AppConfig.UserDefaultsKeys.lastOpenedRepository)
            print("✅ 当前仓库已清除")
        }
    }
    
    /// 仅设置当前仓库引用（不修改列表）
    /// - Parameter repository: 当前仓库
    func setCurrentRepositoryReference(_ repository: GitRepository?) {
        currentRepository = repository
        
        if let repository = repository {
            // 仅保存最后打开的仓库路径，不修改列表
            userDefaults.set(repository.path, forKey: AppConfig.UserDefaultsKeys.lastOpenedRepository)
            print("✅ 当前仓库引用已设置（不修改列表）: \(repository.displayName)")
        } else {
            userDefaults.removeObject(forKey: AppConfig.UserDefaultsKeys.lastOpenedRepository)
            print("✅ 当前仓库引用已清除")
        }
    }
    
    /// 从最近列表中移除仓库
    /// - Parameter repository: 要移除的仓库
    func removeRepository(_ repository: GitRepository) {
        recentRepositories.removeAll { $0.path == repository.path }
        saveRecentRepositories()
        
        // 如果移除的是当前仓库，清除当前仓库
        if currentRepository?.path == repository.path {
            setCurrentRepository(nil)
        }
        
        print("✅ 仓库已从最近列表移除: \(repository.displayName)")
    }
    
    /// 清除所有最近仓库
    func clearRecentRepositories() {
        recentRepositories.removeAll()
        saveRecentRepositories()
        
        // 清除当前仓库状态（关键修复）
        setCurrentRepository(nil)
        
        print("✅ 已清除所有最近仓库和当前仓库状态")
    }
    
    /// 获取仓库的安全访问URL
    /// - Parameter repository: 仓库信息
    /// - Returns: 可安全访问的URL，失败返回nil
    func getSecurityScopedURL(for repository: GitRepository) -> URL? {
        return securityManager.getSecurityScopedURL(for: repository.path)
    }
    
    /// 为新仓库创建安全访问权限
    /// - Parameter url: 仓库URL
    /// - Returns: 是否成功创建权限
    @discardableResult
    func createSecurityScopedAccess(for url: URL) -> Bool {
        return securityManager.createBookmark(for: url)
    }
    
    /// 清理不存在的仓库
    func cleanupInvalidRepositories() {
        let validRepositories = recentRepositories.filter { repositoryExists(at: $0.path) }
        let removedCount = recentRepositories.count - validRepositories.count
        
        if removedCount > 0 {
            recentRepositories = validRepositories
            saveRecentRepositories()
            print("✅ 已清理 \(removedCount) 个无效仓库")
        }
        
        // 检查当前仓库是否有效
        if let current = currentRepository, !repositoryExists(at: current.path) {
            setCurrentRepository(nil)
            print("⚠️ 当前仓库路径无效，已清除")
        }
    }
    
    /// 检查仓库是否有有效的安全访问权限
    /// - Parameter repository: 仓库信息
    /// - Returns: 是否有有效权限
    func hasValidAccess(for repository: GitRepository) -> Bool {
        return securityManager.hasValidAccess(for: repository.path)
    }
    
    /// 检查指定路径的仓库是否存在
    /// - Parameter path: 仓库路径
    /// - Returns: 仓库是否存在
    func repositoryExists(at path: String) -> Bool {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        
        // 检查路径是否存在且是目录
        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return false
        }
        
        // 检查是否包含.git文件夹或.git文件（适用于git worktree）
        let gitPath = URL(fileURLWithPath: path).appendingPathComponent(".git").path
        return fileManager.fileExists(atPath: gitPath)
    }
    
    // MARK: - 持久化
    
    /// 保存最近仓库列表
    private func saveRecentRepositories() {
        let repositoryData = recentRepositories.map { repository in
            [
                "name": repository.name,
                "path": repository.path,
                "lastOpened": repository.lastOpened.timeIntervalSince1970
            ]
        }
        userDefaults.set(repositoryData, forKey: AppConfig.UserDefaultsKeys.recentRepositories)
    }
    
    /// 加载最近仓库列表
    private func loadRecentRepositories() {
        guard let repositoryData = userDefaults.array(forKey: AppConfig.UserDefaultsKeys.recentRepositories) as? [[String: Any]] else {
            return
        }
        
        recentRepositories = repositoryData.compactMap { data in
            guard let name = data["name"] as? String,
                  let path = data["path"] as? String,
                  let timestamp = data["lastOpened"] as? TimeInterval else {
                return nil
            }
            
            let lastOpened = Date(timeIntervalSince1970: timestamp)
            return GitRepository(name: name, path: path, lastOpened: lastOpened)
        }
        
        print("✅ 已加载 \(recentRepositories.count) 个最近仓库")
    }
    
    /// 加载最后打开的仓库
    private func loadLastOpenedRepository() {
        guard let lastPath = userDefaults.string(forKey: AppConfig.UserDefaultsKeys.lastOpenedRepository) else {
            return
        }
        
        // 检查路径是否仍然有效
        if repositoryExists(at: lastPath) {
            let repositoryName = URL(fileURLWithPath: lastPath).lastPathComponent
            let repository = GitRepository(name: repositoryName, path: lastPath)
            currentRepository = repository
            print("✅ 已恢复最后打开的仓库: \(repository.displayName)")
        } else {
            // 清除无效的最后打开仓库
            userDefaults.removeObject(forKey: AppConfig.UserDefaultsKeys.lastOpenedRepository)
            print("⚠️ 最后打开的仓库路径无效，已清除")
        }
    }
}

// MARK: - 扩展：仓库统计信息
extension RepositoryManager {
    
    /// 获取仓库统计信息
    var repositoryStats: (total: Int, recent: Int) {
        return (total: recentRepositories.count, recent: recentRepositories.count)
    }
    
    /// 检查是否有最近仓库（计算属性会自动响应recentRepositories的变化）
    var hasRecentRepositories: Bool {
        return !recentRepositories.isEmpty
    }
    
    /// 调试：打印当前仓库列表顺序
    func debugPrintRepositoryOrder() {
        print("📋 当前仓库列表顺序:")
        for (index, repo) in recentRepositories.enumerated() {
            let isCurrentMark = (currentRepository?.path == repo.path) ? "✅ " : "   "
            print("  \(index + 1). \(isCurrentMark)\(repo.displayName) (\(repo.lastOpened))")
        }
        print("📋 列表顺序打印完成")
    }
}