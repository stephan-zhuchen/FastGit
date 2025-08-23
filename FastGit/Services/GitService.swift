//
//  GitService.swift
//  FastGit
//
//  Created by FastGit Team
//

import Foundation
import SwiftGitX

/// Git服务类 - 与SwiftGitX交互的唯一入口
@MainActor
class GitService: ObservableObject {
    
    // MARK: - 单例
    static let shared = GitService()
    
    // MARK: - 属性
    @Published var currentRepository: GitRepository?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // SwiftGitX初始化状态
    private var isSwiftGitXInitialized = false
    
    private init() {
        // 初始化SwiftGitX
        initializeSwiftGitX()
    }
    
    deinit {
        // 清理SwiftGitX资源
        if isSwiftGitXInitialized {
            do {
                try SwiftGitX.shutdown()
                print("✅ SwiftGitX 已在deinit中关闭")
            } catch {
                print("⚠️ SwiftGitX 关闭失败: \(error)")
            }
            isSwiftGitXInitialized = false
        }
    }
    
    // MARK: - SwiftGitX 管理
    
    /// 初始化SwiftGitX
    private func initializeSwiftGitX() {
        guard !isSwiftGitXInitialized else { return }
        
        do {
            try SwiftGitX.initialize()
            isSwiftGitXInitialized = true
            print("✅ SwiftGitX 初始化成功")
        } catch {
            print("❌ SwiftGitX 初始化失败: \(error)")
        }
    }
    
    /// 关闭SwiftGitX
    private func shutdownSwiftGitX() {
        guard isSwiftGitXInitialized else { return }
        
        do {
            try SwiftGitX.shutdown()
            isSwiftGitXInitialized = false
            print("✅ SwiftGitX 已关闭")
        } catch {
            print("⚠️ SwiftGitX 关闭失败: \(error)")
            isSwiftGitXInitialized = false
        }
    }
    
    // MARK: - 仓库操作
    
    /// 打开本地仓库
    /// - Parameter path: 仓库路径
    /// - Returns: 打开的仓库对象，如果失败返回nil
    func openRepository(at path: String) async -> GitRepository? {
        isLoading = true
        errorMessage = nil
        
        do {
            // 检查路径是否存在
            let repoURL = URL(fileURLWithPath: path)
            guard FileManager.default.fileExists(atPath: path) else {
                throw GitServiceError.repositoryNotFound(path: path)
            }
            
            // 检查是否是Git仓库
            let gitPath = repoURL.appendingPathComponent(".git").path
            guard FileManager.default.fileExists(atPath: gitPath) else {
                throw GitServiceError.notAGitRepository(path: path)
            }
            
            // 使用SwiftGitX打开仓库
            let swiftGitXRepo = try Repository.open(at: repoURL)
            
            // 创建我们的GitRepository对象
            let repoName = repoURL.lastPathComponent
            let repository = GitRepository(name: repoName, path: path)
            
            currentRepository = repository
            isLoading = false
            
            print("✅ 成功打开仓库: \(repository.displayName) at \(path)")
            return repository
            
        } catch {
            let errorMsg = "打开仓库失败: \(error.localizedDescription)"
            errorMessage = errorMsg
            isLoading = false
            print("❌ \(errorMsg)")
            return nil
        }
    }
    
    /// 获取提交历史
    /// - Parameter repository: 目标仓库
    /// - Returns: 提交历史数组
    func fetchCommitHistory(for repository: GitRepository) async -> [Commit] {
        isLoading = true
        errorMessage = nil
        
        do {
            // 使用SwiftGitX获取真实的提交历史
            let repoURL = URL(fileURLWithPath: repository.path)
            let swiftGitXRepo = try Repository.open(at: repoURL)
            
            print("🔍 仓库调试信息:")
            print("   - 仓库路径: \(repository.path)")
            print("   - 是否为空: \(swiftGitXRepo.isEmpty)")
            print("   - HEAD是否未生成: \(swiftGitXRepo.isHEADUnborn)")
            print("   - HEAD是否分离: \(swiftGitXRepo.isHEADDetached)")
            print("   - 是否为bare仓库: \(swiftGitXRepo.isBare)")
            
            // 检查仓库是否为空或HEAD未生成
            if swiftGitXRepo.isEmpty {
                print("⚠️ 仓库为空，没有提交历史")
                isLoading = false
                return []
            }
            
            if swiftGitXRepo.isHEADUnborn {
                print("⚠️ 仓库HEAD未生成，可能是刚创建的空仓库")
                isLoading = false
                return []
            }
            
            print("🚀 开始获取提交历史...")
            let commitSequence = try swiftGitXRepo.log()
            
            var commits: [Commit] = []
            
            // 使用CommitSequence迭代器获取提交历史
            for swiftGitXCommit in commitSequence {
                let author = Author(name: swiftGitXCommit.author.name, email: swiftGitXCommit.author.email)
                let parentShas: [String]
                do {
                    parentShas = try swiftGitXCommit.parents.map { $0.id.hex }
                } catch {
                    print("⚠️ 获取父提交失败: \(error)")
                    parentShas = []
                }
                
                let fastGitCommit = Commit(
                    sha: swiftGitXCommit.id.hex,
                    message: swiftGitXCommit.message,
                    author: author,
                    date: swiftGitXCommit.date,
                    parents: parentShas
                )
                commits.append(fastGitCommit)
                
                // 限制获取数量防止卡死
                if commits.count >= AppConfig.Git.maxCommitsToLoad { break }
            }
            
            isLoading = false
            
            print("✅ 获取到 \(commits.count) 个提交记录")
            for commit in commits.prefix(3) {
                print("   - \(commit.shortSha): \(commit.message)")
            }
            if commits.count > 3 {
                print("   ... 及其他 \(commits.count - 3) 个提交")
            }
            
            return commits
            
        } catch {
            // 为不同类型的错误提供更友好的错误信息
            let errorMsg: String
            
            if let repoError = error as? RepositoryError {
                switch repoError {
                case .unbornHEAD:
                    errorMsg = "仓库HEAD未初始化：这可能是一个新创建的空仓库或仓库损坏。"
                case .failedToGetHEAD(let message):
                    errorMsg = "无法读取Git仓库HEAD: \(message)"
                default:
                    errorMsg = "仓库操作失败: \(error.localizedDescription)"
                }
            } else if error.localizedDescription.contains("Operation not permitted") {
                errorMsg = "权限不足：无法访问Git仓库文件。请确保应用有足够的文件访问权限。"
            } else {
                errorMsg = "获取提交历史失败: \(error.localizedDescription)"
            }
            
            errorMessage = errorMsg
            isLoading = false
            print("❌ \(errorMsg)")
            print("❌ 详细错误: \(error)")
            return []
        }
    }

}

// MARK: - 错误类型定义

/// GitService错误类型
enum GitServiceError: LocalizedError {
    case repositoryNotFound(path: String)
    case notAGitRepository(path: String)
    case permissionDenied(path: String)
    case initializationFailed(String)
    case operationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .repositoryNotFound(let path):
            return "仓库路径不存在: \(path)"
        case .notAGitRepository(let path):
            return "不是有效的Git仓库: \(path)"
        case .permissionDenied(let path):
            return "权限不足：无法访问 \(path)。请检查应用权限设置或选择其他仓库。"
        case .initializationFailed(let message):
            return "初始化失败: \(message)"
        case .operationFailed(let message):
            return "操作失败: \(message)"
        }
    }
}
