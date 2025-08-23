//
//  Repository.swift
//  FastGit
//
//  Created by FastGit Team
//

import Foundation

/// Git仓库模型
struct GitRepository: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let path: String
    let url: String?
    
    /// 初始化本地仓库
    init(name: String, path: String, url: String? = nil) {
        self.name = name
        self.path = path
        self.url = url
    }
    
    /// 获取仓库显示名称
    var displayName: String {
        return name.isEmpty ? URL(fileURLWithPath: path).lastPathComponent : name
    }
}