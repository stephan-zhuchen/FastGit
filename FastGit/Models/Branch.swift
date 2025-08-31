//
//  Branch.swift
//  FastGit
//
//  Created by FastGit Team
//

import Foundation

/// Git分支模型
// --- 修改点: 遵循 Hashable ---
struct GitBranch: Identifiable, Equatable, Hashable {
    let id = UUID()
    let name: String
    let shortName: String
    let isCurrent: Bool
    let isRemote: Bool
    let targetSha: String?
    
    init(name: String, isCurrent: Bool = false, isRemote: Bool = false, targetSha: String? = nil) {
        self.name = name
        self.isCurrent = isCurrent
        self.isRemote = isRemote
        self.targetSha = targetSha
        
        // 处理分支短名称 (去掉refs/heads/或origin/等前缀)
        if isRemote {
            self.shortName = name.components(separatedBy: "/").dropFirst().joined(separator: "/")
        } else {
            self.shortName = name.replacingOccurrences(of: "refs/heads/", with: "")
        }
    }
    
    /// 分支类型
    var branchType: BranchType {
        if isCurrent {
            return .current
        } else if isRemote {
            return .remote
        } else {
            return .local
        }
    }
    
    // --- 新增: 实现 Hashable 协议 ---
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }

    // --- 新增: 实现 Equatable 协议 (确保 tag 工作正常) ---
    static func == (lhs: GitBranch, rhs: GitBranch) -> Bool {
        return lhs.name == rhs.name
    }
}

/// 分支类型枚举
enum BranchType: String, CaseIterable {
    case current = "当前分支"
    case local = "本地分支"
    case remote = "远程分支"
}
