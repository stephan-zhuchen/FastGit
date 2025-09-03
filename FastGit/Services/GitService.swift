//
//  GitService.swift
//  FastGit
//
//  Created by FastGit Team
//

import Foundation
import SwiftGitX
import libgit2

extension Array where Element == String {
    /// 临时将字符串数组转换为 C `git_strarray` 并在闭包内使用。
    /// 自动处理内存分配和释放。
    func withGitStrArray<R>(_ body: (inout git_strarray) throws -> R) throws -> R {
        let cStrings = self.map { strdup($0) }
        defer {
            for ptr in cStrings { free(ptr) }
        }

        var strArray = git_strarray()
        return try cStrings.withUnsafeBufferPointer { buffer in
            strArray.strings = UnsafeMutablePointer(mutating: buffer.baseAddress)
            strArray.count = self.count
            return try body(&strArray)
        }
    }
}

// --- 新增: 辅助扩展以暴露一个功能更强大的 fetch 和 push 方法 ---
fileprivate extension Repository {
    
    /// 从指定的远程仓库抓取对象和引用，并提供详细的配置选项。
    func fetch(remote remoteName: String, refspecs: [String]? = nil, options: FetchOptions = .default) async throws {
        let repoPointer = self.pointer

        var remotePointer: OpaquePointer?
        defer { git_remote_free(remotePointer) }
        guard git_remote_lookup(&remotePointer, repoPointer, remoteName) == GIT_OK.rawValue, remotePointer != nil else {
            throw RepositoryError.failedToFetch("找不到名为 '\(remoteName)' 的远程仓库。")
        }

        var gitFetchOptions = options.toGitFetchOptions()

        let status: Int32
        if let refspecs = refspecs, !refspecs.isEmpty {
            status = try refspecs.withGitStrArray { gitStrArray in
                git_remote_fetch(remotePointer, &gitStrArray, &gitFetchOptions, nil)
            }
        } else {
            status = git_remote_fetch(remotePointer, nil, &gitFetchOptions, nil)
        }

        if status != GIT_OK.rawValue {
            let errorMessage = String(cString: git_error_last().pointee.message)
            throw RepositoryError.failedToFetch(errorMessage)
        }
    }
    
    /// 推送引用到指定的远程仓库，并提供详细的配置选项。
    func push(remote remoteName: String, refspecs: [String], options: PushOptions = .default) async throws {
        let repoPointer = self.pointer
        
        var remotePointer: OpaquePointer?
        // --- 修复点: 在函数退出时，先断开连接，再释放对象 ---
        defer {
            if remotePointer != nil {
                git_remote_disconnect(remotePointer)
                git_remote_free(remotePointer)
            }
        }
        
        guard git_remote_lookup(&remotePointer, repoPointer, remoteName) == GIT_OK.rawValue, remotePointer != nil else {
            throw RepositoryError.failedToPush("找不到名为 '\(remoteName)' 的远程仓库。")
        }
        
        var gitPushOptions = options.toGitPushOptions()
        
        // 使用一个简单的异步任务来包装同步的 C 调用
        try await Task {
            try refspecs.withGitStrArray { gitStrArray in
                let status = git_remote_push(remotePointer, &gitStrArray, &gitPushOptions)
                
                guard status == GIT_OK.rawValue else {
                    let errorMessage = String(cString: git_error_last().pointee.message)
                    throw RepositoryError.failedToPush(errorMessage)
                }
            }
        }.value
    }
    
    /// 确保仓库有可用的签名，如果没有，则从应用设置中注入
    func ensureRepositorySignature() throws {
        // 1. 检查仓库的本地配置是否已经有签名
        if self.config.string(forKey: "user.name") != nil, self.config.string(forKey: "user.email") != nil {
            return // 本地配置已存在，无需操作
        }
        
        // 2. 如果本地没有，从 UserDefaults (应用内“全局”设置) 获取
        guard let name = UserDefaults.standard.string(forKey: "globalUserName"), !name.isEmpty,
              let email = UserDefaults.standard.string(forKey: "globalUserEmail"), !email.isEmpty else {
            // 3. 如果应用内设置也没有，则抛出错误，提示用户去设置
            throw GitServiceError.signatureNotFound
        }
        
        // 4. 将应用内设置的签名写入到仓库的本地 .git/config 文件中
        self.config.set(name, forKey: "user.name")
        self.config.set(email, forKey: "user.email")
        print("✍️ 已将应用内配置的签名注入到仓库本地配置中。")
    }
}


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
    
    /// 获取仓库的所有子模块
    /// - Parameter repository: 目标仓库
    /// - Returns: 子模块相对路径的数组
    func fetchSubmodules(for repository: GitRepository) async -> [String] {
        print("📦 开始获取子模块...")
        var submodulePaths: [String] = []

        let callback: git_submodule_cb = { submodule, name, payload in
            guard let submodule = submodule,
                  let payload = payload else { return -1 }
            
            let submodulePathsPointer = payload.assumingMemoryBound(to: [String].self)
            
            if let pathPointer = git_submodule_path(submodule) {
                let path = String(cString: pathPointer)
                submodulePathsPointer.pointee.append(path)
            }
            
            return 0
        }

        do {
            let repoURL = URL(fileURLWithPath: repository.path)
            let swiftGitXRepo = try Repository.open(at: repoURL)
            
            let mirror = Mirror(reflecting: swiftGitXRepo)
            if let repoPointer = mirror.descendant("pointer") as? OpaquePointer {
                
                let status = withUnsafeMutablePointer(to: &submodulePaths) { payloadPointer in
                    git_submodule_foreach(repoPointer, callback, payloadPointer)
                }

                if status == GIT_OK.rawValue {
                    print("✅ 成功获取到 \(submodulePaths.count) 个子模块。")
                } else {
                    let errorMessage = String(cString: git_error_last().pointee.message)
                    print("❌ 调用 git_submodule_foreach 失败: \(errorMessage)")
                }
            } else {
                 print("❌ 无法通过反射获取 repository pointer。")
            }

        } catch {
            print("❌ 打开仓库以获取子模块时失败: \(error.localizedDescription)")
        }
        
        return submodulePaths
    }
    
    /// 获取仓库的所有分支
    /// - Parameter repo: SwiftGitX 仓库对象
    /// - Returns: 分支数组
    private func fetchBranches(from repo: Repository) async throws -> [GitBranch] {
        var branches: [GitBranch] = []

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

        let currentBranchName: String?
        do {
            let currentBranch = try repo.branch.current
            currentBranchName = currentBranch.name
            print("🌿 当前分支是: \(currentBranchName ?? "无")")
        } catch {
            print("⚠️ 获取当前分支失败: \(error)")
            currentBranchName = nil
        }
        
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
            let remotes = try repo.remote.list()
            var remoteBranchCount = 0

            for remote in remotes {
                for remoteBranch in remote.branches {
                    let fastGitBranch = GitBranch(
                        name: remoteBranch.name,
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
                let isAnnotated = swiftGitXTag.tagger != nil
                
                var message: String?
                var taggerName: String?
                var taggerEmail: String?
                var date: Date?
                
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
    private func createCommitReferencesMap(branches: [GitBranch]) -> [String: [String]] {
        var map: [String: [String]] = [:]
        for branch in branches {
            if let sha = branch.targetSha {
                map[sha, default: []].append(branch.name)
            }
        }
        return map
    }
    
    /// 创建提交SHA到标签名称的映射
    private func createCommitReferencesMap(tags: [GitTag]) -> [String: [String]] {
        var map: [String: [String]] = [:]
        for tag in tags {
            map[tag.targetSha, default: []].append(tag.name)
        }
        return map
    }

    /// 获取指定提交的变更文件列表
    func fetchChanges(for commit: GitCommit, in repository: GitRepository) async -> [GitFileStatus] {
        print("🔍 Fetching changes for commit: \(commit.shortSha)")
        var changes: [GitFileStatus] = []
        
        do {
            let repoURL = URL(fileURLWithPath: repository.path)
            let swiftGitXRepo = try Repository.open(at: repoURL)
            
            let oid = try OID(hex: commit.sha)
            let swiftGitXCommit: Commit = try swiftGitXRepo.show(id: oid)
            
            let diff = try swiftGitXRepo.diff(commit: swiftGitXCommit)
            
            for delta in diff.changes {
                let path = delta.newFile.path
                let statusType = convertStatus(from: delta.type)
                
                // We don't have line changes here, so default to 0
                let fileStatus = GitFileStatus(path: path, status: statusType, linesAdded: 0, linesDeleted: 0)
                changes.append(fileStatus)
            }
            
            print("✅ Found \(changes.count) changes for commit \(commit.shortSha)")
            
        } catch {
            print("❌ Failed to fetch changes for commit \(commit.shortSha): \(error.localizedDescription)")
        }
        
        return changes
    }
    
    /// 获取当前仓库的文件状态
    func fetchStatus(for repository: GitRepository) async -> [FileStatusItem] {
        var fileItems: [String: FileStatusItem] = [:]

        do {
            let repoURL = URL(fileURLWithPath: repository.path)
            let swiftGitXRepo = try Repository.open(at: repoURL)

            let statusOptions: StatusOption = [.includeUntracked, .includeIgnored]
            let statusEntries = try swiftGitXRepo.status(options: statusOptions)
            
            let stagedDiff = try swiftGitXRepo.diff(to: .index)
            let stagedPatchMap = Dictionary(uniqueKeysWithValues: stagedDiff.patches.map { ($0.delta.newFile.path, $0) })
            
            let workingTreeDiff = try swiftGitXRepo.diff(to: .workingTree)
            let workingTreePatchMap = Dictionary(uniqueKeysWithValues: workingTreeDiff.patches.map { ($0.delta.newFile.path, $0) })

            for entry in statusEntries {
                var path: String?
                var stagedChange: FileChange?
                var unstagedChange: FileChange?

                if let indexDelta = entry.index {
                    path = indexDelta.newFile.path
                    let (added, deleted) = calculateLineChanges(for: path, in: stagedPatchMap)
                    stagedChange = FileChange(
                        path: path!,
                        status: convertStatus(from: indexDelta.type),
                        linesAdded: added,
                        linesDeleted: deleted
                    )
                }
                
                if let workdirDelta = entry.workingTree {
                    path = workdirDelta.newFile.path
                    let (added, deleted) = calculateLineChanges(for: path, in: workingTreePatchMap)
                    unstagedChange = FileChange(
                        path: path!,
                        status: convertStatus(from: workdirDelta.type),
                        linesAdded: added,
                        linesDeleted: deleted
                    )
                }

                if let finalPath = entry.workingTree?.newFile.path ?? entry.index?.newFile.path {
                    if fileItems[finalPath] == nil {
                        fileItems[finalPath] = FileStatusItem(path: finalPath, stagedChange: nil, unstagedChange: nil)
                    }
                    if let sc = stagedChange {
                        fileItems[finalPath] = FileStatusItem(path: finalPath, stagedChange: sc, unstagedChange: fileItems[finalPath]?.unstagedChange)
                    }
                    if let uc = unstagedChange {
                        fileItems[finalPath] = FileStatusItem(path: finalPath, stagedChange: fileItems[finalPath]?.stagedChange, unstagedChange: uc)
                    }
                }
            }
        } catch {
            print("❌ Failed to fetch status: \(error.localizedDescription)")
        }
        
        return Array(fileItems.values).sorted { $0.path < $1.path }
    }
    
    // MARK: - 全局 Git 配置
    
    /// 获取 Git 版本信息
    func getGitVersion() -> String {
        return SwiftGitX.libgit2Version
    }

    /// 执行 fetch 操作
    func fetch(remote: String, with options: FetchOptions, in repository: GitRepository) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let repoURL = URL(fileURLWithPath: repository.path)
            let swiftGitXRepo = try Repository.open(at: repoURL)
            
            print("Fetching from \(remote)...")
            try await swiftGitXRepo.fetch(remote: remote, options: options)
            print("✅ Fetch successful for remote '\(remote)' in \(repository.displayName)")
        } catch {
            let errorMsg = "Fetch failed: \(error.localizedDescription)"
            errorMessage = errorMsg
            print("❌ \(errorMsg)")
        }
        
        isLoading = false
    }

    /// 执行 pull 操作
    func pull(with options: PullOptions, in repository: GitRepository) async {
        isLoading = true
        errorMessage = nil
        
        // Pull implementation is not part of this request.
        
        isLoading = false
    }

    /// 创建新分支
    func createBranch(name: String, options: NewBranchOptions, in repository: GitRepository) async -> Bool {
        isLoading = true
        errorMessage = nil
        
        do {
            let repoURL = URL(fileURLWithPath: repository.path)
            let swiftGitXRepo = try Repository.open(at: repoURL)
            
            try swiftGitXRepo.ensureRepositorySignature()

            let statusItems = try swiftGitXRepo.status()
            if !statusItems.isEmpty {
                switch options.uncommittedChangesOption {
                case .stash:
                    _ = try swiftGitXRepo.stash.save(message: "Stash for creating branch \(name)")
                    print("✅ Stashed uncommitted changes.")
                case .discard:
                    guard let headCommit = try swiftGitXRepo.HEAD.target as? Commit else {
                        throw GitServiceError.operationFailed("Could not get HEAD commit to discard changes.")
                    }
                    try swiftGitXRepo.reset(to: headCommit, mode: .hard)
                    print("✅ Discarded uncommitted changes.")
                }
            }
            
            guard let baseBranchSha = options.baseBranch.targetSha,
                  let baseCommitOid = try? OID(hex: baseBranchSha) else {
                throw GitServiceError.operationFailed("Base branch has no valid target SHA.")
            }
            let baseCommit: Commit = try swiftGitXRepo.show(id: baseCommitOid)

            let newBranch = try swiftGitXRepo.branch.create(
                named: name,
                target: baseCommit,
                force: options.allowOverwrite
            )
            print("✅ Successfully created branch '\(name)'")
            
            if options.checkoutAfterCreation {
                try swiftGitXRepo.switch(to: newBranch)
                print("✅ Switched to new branch '\(name)'")
            }

            isLoading = false
            return true
            
        } catch {
            let errorMsg = "Failed to create branch: \(error.localizedDescription)"
            errorMessage = errorMsg
            print("❌ \(errorMsg)")
            isLoading = false
            return false
        }
    }
    
    /// 执行 Stash 操作
    func stash(with options: StashOptions, in repository: GitRepository) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let repoURL = URL(fileURLWithPath: repository.path)
            let swiftGitXRepo = try Repository.open(at: repoURL)
            
            try swiftGitXRepo.ensureRepositorySignature()
            
            var stashFlags: StashOption = .default
            if options.includeUntracked {
                stashFlags.insert(.includeUntracked)
            }
            
            _ = try swiftGitXRepo.stash.save(message: options.message, options: stashFlags)
            print("✅ Stash successful")
            
        } catch {
            let errorMsg = "Stash failed: \(error.localizedDescription)"
            errorMessage = errorMsg
            print("❌ \(errorMsg)")
        }
        
        isLoading = false
    }
    
    /// 执行 Push 操作
    func push(with uiOptions: UIPushOptions, in repository: GitRepository) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let repoURL = URL(fileURLWithPath: repository.path)
            let swiftGitXRepo = try Repository.open(at: repoURL)
            
            try swiftGitXRepo.ensureRepositorySignature()
            
            // --- 构造 Refspec ---
            let remoteBranchName = uiOptions.remoteBranch?.shortName ?? uiOptions.localBranch.shortName
            let localBranchRef = "refs/heads/\(uiOptions.localBranch.shortName)"
            let remoteBranchRef = "refs/heads/\(remoteBranchName)"
            
            var refspec = "\(localBranchRef):\(remoteBranchRef)"
            if uiOptions.forcePush {
                refspec = "+\(refspec)"
            }
            
            var refspecsToPush = [refspec]
            
            // --- 处理推送标签 ---
            if uiOptions.pushTags {
                refspecsToPush.append("refs/tags/*:refs/tags/*")
            }

            // --- 构造 Library PushOptions ---
            // Note: Currently only pb_parallelism is implemented, but this is extensible.
            let libraryOptions = PushOptions()
            
            // --- 调用新的带选项的 push 方法 ---
            try await swiftGitXRepo.push(
                remote: uiOptions.remote,
                refspecs: refspecsToPush,
                options: libraryOptions
            )
            
            print("✅ Push successful to \(uiOptions.remote)/\(remoteBranchName)")

        } catch {
            let errorMsg = "Push failed: \(error.localizedDescription)"
            errorMessage = errorMsg
            print("❌ \(errorMsg)")
        }
        
        isLoading = false
    }
    
    /// 获取远程仓库列表
    func listRemotes(for repository: GitRepository) async -> [String] {
        do {
            let repoURL = URL(fileURLWithPath: repository.path)
            let swiftGitXRepo = try Repository.open(at: repoURL)
            return try swiftGitXRepo.remote.list().compactMap { $0.name }
        } catch {
            print("❌ Failed to list remotes: \(error.localizedDescription)")
            return []
        }
    }

    private func calculateLineChanges(for path: String?, in patchMap: [String: Patch]) -> (added: Int, deleted: Int) {
        guard let path = path, let patch = patchMap[path] else {
            return (0, 0)
        }
        
        var linesAdded = 0
        var linesDeleted = 0
        
        for hunk in patch.hunks {
            for line in hunk.lines {
                if line.type == .addition {
                    linesAdded += 1
                } else if line.type == .deletion {
                    linesDeleted += 1
                }
            }
        }
        return (linesAdded, linesDeleted)
    }
    
    private func convertStatus(from deltaType: Diff.DeltaType) -> GitFileStatusType {
        switch deltaType {
        case .added: return .added
        case .deleted: return .deleted
        case .modified: return .modified
        case .renamed: return .renamed
        case .copied: return .copied
        case .untracked: return .untracked
        case .typeChange: return .typeChanged
        case .ignored: return .ignored
        case .conflicted: return .conflicted
        default: return .modified
        }
    }
}


// MARK: - 错误类型定义
enum GitServiceError: LocalizedError {
    case repositoryNotFound(path: String)
    case notAGitRepository(path: String)
    case permissionDenied(path: String)
    case initializationFailed(String)
    case operationFailed(String)
    case signatureNotFound
    
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
        case .signatureNotFound:
            return "Git签名未找到。请在应用的设置页面中配置您的'用户名'和'邮箱'。"
        }
    }
}
