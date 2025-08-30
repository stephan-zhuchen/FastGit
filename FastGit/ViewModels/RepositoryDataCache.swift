//
//  RepositoryDataCache.swift
//  FastGit
//
//  Created by 朱晨 on 2025/8/30.
//

import Foundation

/// A data structure to cache the loaded data for a single repository.
/// 一个用于缓存单个仓库已加载数据的数据结构。
struct RepositoryDataCache {
    let branches: [GitBranch]
    let tags: [GitTag]
    let commits: [GitCommit]
    let submodules: [String]
    
    // You can add a timestamp to implement time-based cache invalidation in the future.
    // 未来可以增加时间戳，用于实现基于时间的缓存失效策略。
    let lastUpdated: Date = Date()
}
