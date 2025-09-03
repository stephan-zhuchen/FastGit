//
//  FetchOptions.swift
//  SwiftGitX
//
//  Created by FastGit Team on 2024/9/2.
//

import libgit2

/// 定义在 fetch 操作期间如何处理标签。
public enum TagFetchMode: Equatable {
    /// 遵循远程仓库的默认行为。
    case auto
    /// 从不下载标签。
    case none
    /// 下载所有标签。
    case all

    /// 将 Swift 枚举值转换为 libgit2 的原生 C 枚举值。
    var rawValue: git_remote_autotag_option_t {
        switch self {
        case .auto:
            return GIT_REMOTE_DOWNLOAD_TAGS_AUTO
        case .none:
            return GIT_REMOTE_DOWNLOAD_TAGS_NONE
        case .all:
            return GIT_REMOTE_DOWNLOAD_TAGS_ALL
        }
    }
}

/// 为 'git fetch' 操作提供详细配置选项。
public struct FetchOptions {
    /// 定义在 fetch 之后是否清理（prune）远程仓库上已不存在的引用。
    public var prune: Bool
    
    /// 定义如何处理标签的下载。
    public var downloadTags: TagFetchMode

    /// 一个计算属性，用于简化对“是否获取所有标签”的检查和设置。
    /// 读取时：如果 `downloadTags` 设置为 `.all`，则返回 `true`。
    /// 设置时：如果设为 `true`，则将 `downloadTags` 更改为 `.all`；如果设为 `false`，则恢复为 `.auto`。
    public var fetchAllTags: Bool {
        get {
            return downloadTags == .all
        }
        set {
            downloadTags = newValue ? .all : .auto
        }
    }

    // 在这里可以为将来添加更多选项，例如回调（callbacks）等。

    /// 创建一个新的 FetchOptions 实例。
    /// - Parameters:
    ///   - prune: 如果为 `true`，则删除远程仓库上不存在的远程跟踪分支。默认为 `false`。
    ///   - downloadTags: 指定如何获取标签。默认为 `.auto`。
    public init(prune: Bool = false, downloadTags: TagFetchMode = .auto) {
        self.prune = prune
        self.downloadTags = downloadTags
    }
    
    /// 使用布尔值 `fetchAllTags` 创建一个新的 FetchOptions 实例的便利初始化方法。
    /// - Parameters:
    ///   - prune: 如果为 `true`，则删除远程仓库上不存在的远程跟踪分支。默认为 `false`。
    ///   - fetchAllTags: 如果为 `true`，则下载所有标签；否则，使用自动模式。
    public init(prune: Bool = false, fetchAllTags: Bool) {
        self.prune = prune
        self.downloadTags = fetchAllTags ? .all : .auto
    }

    /// 提供一个默认的配置实例。
    public static let `default` = FetchOptions()

    /// 将 Swift 的 FetchOptions 转换为 libgit2 使用的 C 结构体 `git_fetch_options`。
    /// 这个方法确保了与底层 C 库的正确交互。
    /// - Returns: 一个配置好的 `git_fetch_options` 实例。
    internal func toGitFetchOptions() -> git_fetch_options {
        var gitOptions = git_fetch_options()
        git_fetch_options_init(&gitOptions, UInt32(GIT_FETCH_OPTIONS_VERSION))

        // 设置 prune 选项
        // GIT_FETCH_PRUNE_UNSPECIFIED 表示遵循仓库配置，这里我们明确控制
        gitOptions.prune = self.prune ? GIT_FETCH_PRUNE : GIT_FETCH_NO_PRUNE
        
        // 设置下载标签的模式
        gitOptions.download_tags = self.downloadTags.rawValue

        return gitOptions
    }
}

