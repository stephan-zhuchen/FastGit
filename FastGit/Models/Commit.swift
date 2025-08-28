//
//  Commit.swift
//  FastGit
//
//  Created by FastGit Team
//

import Foundation

/// Git提交模型
struct GitCommit: Identifiable, Equatable {
    let id = UUID()
    let sha: String
    let shortSha: String
    let message: String
    let author: GitAuthor
    let date: Date
    let parents: [String]
    let branches: [String] // 指向此提交的分支名称
    let tags: [String] // 指向此提交的标签名称
    
    init(
        sha: String, 
        message: String, 
        author: GitAuthor,
        date: Date, 
        parents: [String] = [],
        branches: [String] = [],
        tags: [String] = []
    ) {
        self.sha = sha
        self.shortSha = String(sha.prefix(7))
        self.message = message
        self.author = author
        self.date = date
        self.parents = parents
        self.branches = branches
        self.tags = tags
    }
    
    /// 是否有分支或标签引用
    var hasReferences: Bool {
        return !branches.isEmpty || !tags.isEmpty
    }
}

/// Git提交作者信息
struct GitAuthor: Equatable {
    let name: String
    let email: String
    
    var displayName: String {
        return "\(name) <\(email)>"
    }
}