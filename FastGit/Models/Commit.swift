//
//  Commit.swift
//  FastGit
//
//  Created by FastGit Team
//

import Foundation

/// Git提交模型
struct Commit: Identifiable, Equatable {
    let id = UUID()
    let sha: String
    let shortSha: String
    let message: String
    let author: Author
    let date: Date
    let parents: [String]
    
    init(sha: String, message: String, author: Author, date: Date, parents: [String] = []) {
        self.sha = sha
        self.shortSha = String(sha.prefix(7))
        self.message = message
        self.author = author
        self.date = date
        self.parents = parents
    }
}

/// Git提交作者信息
struct Author: Equatable {
    let name: String
    let email: String
    
    var displayName: String {
        return "\(name) <\(email)>"
    }
}