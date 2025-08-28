//
//  Tag.swift
//  FastGit
//
//  Created by FastGit Team
//

import Foundation

/// Git标签模型
struct GitTag: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let targetSha: String
    let message: String?
    let taggerName: String?
    let taggerEmail: String?
    let date: Date?
    let isAnnotated: Bool
    
    init(
        name: String,
        targetSha: String,
        message: String? = nil,
        taggerName: String? = nil,
        taggerEmail: String? = nil,
        date: Date? = nil,
        isAnnotated: Bool = false
    ) {
        self.name = name
        self.targetSha = targetSha
        self.message = message
        self.taggerName = taggerName
        self.taggerEmail = taggerEmail
        self.date = date
        self.isAnnotated = isAnnotated
    }
    
    /// 标签显示名称
    var displayName: String {
        return name
    }
    
    /// 标签类型描述
    var typeDescription: String {
        return isAnnotated ? "注释标签" : "轻量标签"
    }
    
    /// 标签创建者信息
    var taggerInfo: String? {
        if let name = taggerName, let email = taggerEmail {
            return "\(name) <\(email)>"
        } else if let name = taggerName {
            return name
        }
        return nil
    }
}