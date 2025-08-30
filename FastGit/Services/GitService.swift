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
            let _ = try Repository.open(at: repoURL)
            
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
    /// - Parameter startingFromSha: 可选的起始提交SHA，用于从特定点开始加载历史
    /// - Returns: 包含提交、分支和标签的元组
    func fetchCommitHistory(for repository: GitRepository, startingFromSha: String? = nil) async -> (commits: [GitCommit], branches: [GitBranch], tags: [GitTag]) {
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
                return ([], [], [])
            }
            
            if swiftGitXRepo.isHEADUnborn {
                print("⚠️ 仓库HEAD未生成，可能是刚创建的空仓库")
                isLoading = false
                return ([], [], [])
            }
            
            // 获取所有分支和标签信息
            let branches = try await fetchBranches(from: swiftGitXRepo)
            let tags = try await fetchTags(from: swiftGitXRepo)
            
            // 创建 SHA -> 分支名和 SHA -> 标签名的映射
            let branchMap = createCommitReferencesMap(branches: branches)
            let tagMap = createCommitReferencesMap(tags: tags)
            
            print("🚀 开始获取提交历史... (起点: \(startingFromSha ?? "HEAD"))")
            let commitSequence: CommitSequence
            if let startSha = startingFromSha {
                let oid = try OID(hex: startSha)
                let startCommit: Commit = try swiftGitXRepo.show(id: oid)
                commitSequence = swiftGitXRepo.log(from: startCommit)
            } else {
                commitSequence = try swiftGitXRepo.log()
            }
            
            var commits: [GitCommit] = []
            
            // 使用CommitSequence迭代器获取提交历史
            for swiftGitXCommit in commitSequence {
                let author = GitAuthor(name: swiftGitXCommit.author.name, email: swiftGitXCommit.author.email)
                let parentShas: [String]
                do {
                    parentShas = try swiftGitXCommit.parents.map { $0.id.hex }
                } catch {
                    print("⚠️ 获取父提交失败: \(error)")
                    parentShas = []
                }
                
                let commitSha = swiftGitXCommit.id.hex
                let commitBranches = branchMap[commitSha] ?? []
                let commitTags = tagMap[commitSha] ?? []
                
                let fastGitCommit = GitCommit(
                    sha: commitSha,
                    message: swiftGitXCommit.message,
                    author: author,
                    date: swiftGitXCommit.date,
                    parents: parentShas,
                    branches: commitBranches,
                    tags: commitTags
                )
                commits.append(fastGitCommit)
                
                // 限制获取数量防止卡死
                if commits.count >= AppConfig.Git.maxCommitsToLoad { break }
            }
            
            isLoading = false
            
//            print("✅ 获取到 \(commits.count) 个提交记录")
//            for commit in commits.prefix(3) {
//                let refsInfo = commit.hasReferences ? " [分支: \(commit.branches.joined(separator: ", ")), 标签: \(commit.tags.joined(separator: ", "))]" : ""
//                print("   - \(commit.shortSha): \(commit.message)\(refsInfo)")
//            }
//            if commits.count > 3 {
//                print("   ... 及其他 \(commits.count - 3) 个提交")
//            }
            
            return (commits, branches, tags)
            
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
            return ([], [], [])
        }
    }
    
    /// 获取仓库的所有分支
    /// - Parameter repo: SwiftGitX 仓库对象
    /// - Returns: 分支数组
    private func fetchBranches(from repo: Repository) async throws -> [GitBranch] {
        var branches: [GitBranch] = []

        // --- 开始诊断 ---
        print("🔍 [诊断] 开始执行 fetchBranches...")
        do {
            let remotes = try repo.remote.list()
            if remotes.isEmpty {
                print("⚠️ [诊断] 在仓库配置中未找到任何远程仓库。这很可能是问题的根源。")
            } else {
                let remoteNames = remotes.compactMap { $0.name }
                print("✅ [诊断] 找到 \(remotes.count) 个远程仓库: \(remoteNames)")
            }
        } catch {
            print("❌ [诊断] 列出远程仓库失败: \(error)")
        }
        // --- 结束诊断 ---

        // 获取当前分支
        let currentBranchName: String?
        do {
            let currentBranch = try repo.branch.current
            currentBranchName = currentBranch.name
            print("🌿 当前分支是: \(currentBranchName ?? "无")")
        } catch {
            print("⚠️ 获取当前分支失败: \(error)")
            currentBranchName = nil
        }
        
        // 获取所有本地分支
        do {
            let localBranches = try repo.branch.list(.local)
            print("🌿 找到 \(localBranches.count) 个本地分支。")
            for branch in localBranches {
                let isCurrent = branch.name == currentBranchName
                let fastGitBranch = GitBranch(
                    name: branch.name,
                    isCurrent: isCurrent,
                    isRemote: false,
                    targetSha: branch.target.id.hex
                )
                branches.append(fastGitBranch)
            }
        } catch {
            print("⚠️ 获取本地分支失败: \(error)")
        }
        
        do {
            // 1. 先获取所有 Remote 对象。
            let remotes = try repo.remote.list()
            var remoteBranchCount = 0

            // 2. 遍历每一个 Remote 对象
            for remote in remotes {
                // 3. 访问其 'branches' 属性来获取该远程下的所有分支
                for remoteBranch in remote.branches {
                    let fastGitBranch = GitBranch(
                        name: remoteBranch.name, // 'name' 已经是 shorthand, e.g., "origin/develop"
                        isCurrent: false,
                        isRemote: true,
                        targetSha: remoteBranch.target.id.hex
                    )
                    branches.append(fastGitBranch)
                    remoteBranchCount += 1
                }
            }
            print("✅ 通过遍历 Remote 对象，成功找到 \(remoteBranchCount) 个远程分支。")
        } catch {
            print("❌ 获取远程分支列表失败: \(error)")
        }
        
        print("🌿 总共获取到 \(branches.count) 个分支。")
        return branches
    }
    
    /// 获取仓库的所有标签
    /// - Parameter repo: SwiftGitX 仓库对象
    /// - Returns: 标签数组
    private func fetchTags(from repo: Repository) async throws -> [GitTag] {
        var tags: [GitTag] = []
        
        do {
            let swiftGitXTags = try repo.tag.list()
            for swiftGitXTag in swiftGitXTags {
                // 检查是否为注释标签（通过tagger是否为nil来判断）
                let isAnnotated = swiftGitXTag.tagger != nil
                
                var message: String?
                var taggerName: String?
                var taggerEmail: String?
                var date: Date?
                
                // 如果是注释标签，获取额外信息
                if isAnnotated {
                    message = swiftGitXTag.message
                    taggerName = swiftGitXTag.tagger?.name
                    taggerEmail = swiftGitXTag.tagger?.email
                    date = swiftGitXTag.tagger?.date
                }
                
                let tag = GitTag(
                    name: swiftGitXTag.name,
                    targetSha: swiftGitXTag.target.id.hex,
                    message: message,
                    taggerName: taggerName,
                    taggerEmail: taggerEmail,
                    date: date,
                    isAnnotated: isAnnotated
                )
                tags.append(tag)
            }
        } catch {
            print("⚠️ 获取标签失败: \(error)")
        }
        
        print("🏷️ 获取到 \(tags.count) 个标签")
        return tags
    }
    
    /// 创建提交SHA到引用名称的映射
    /// - Parameter branches: 分支数组
    /// - Returns: SHA -> [引用名称] 的映射
    private func createCommitReferencesMap(branches: [GitBranch]) -> [String: [String]] {
        var map: [String: [String]] = [:]
        for branch in branches {
            if let sha = branch.targetSha {
                if map[sha] == nil {
                    map[sha] = []
                }
                map[sha]?.append(branch.name)
            }
        }
        return map
    }
    
    /// 创建提交SHA到标签名称的映射
    /// - Parameter tags: 标签数组
    /// - Returns: SHA -> [标签名称] 的映射
    private func createCommitReferencesMap(tags: [GitTag]) -> [String: [String]] {
        var map: [String: [String]] = [:]
        for tag in tags {
            if map[tag.targetSha] == nil {
                map[tag.targetSha] = []
            }
            map[tag.targetSha]?.append(tag.name)
        }
        return map
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
