//
//  Branch.swift
//  FastGit
//
//  Created by FastGit Team
//

import Foundation

/// Git分支模型
struct GitBranch: Identifiable, Equatable {
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
}

/// 分支类型枚举
enum BranchType: String, CaseIterable {
    case current = "当前分支"
    case local = "本地分支"
    case remote = "远程分支"
}