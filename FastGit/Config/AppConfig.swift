//
//  AppConfig.swift
//  FastGit
//
//  Created by FastGit Team
//

import Foundation

/// 应用配置管理
struct AppConfig {
    
    // MARK: - 应用信息
    static let appName = "FastGit"
    static let appVersion = "0.1.0"
    static let buildNumber = "1"
    
    // MARK: - UI配置
    struct UI {
        static let sidebarMinWidth: CGFloat = 200
        static let commitRowHeight: CGFloat = 60
        static let animationDuration: Double = 0.3
    }
    
    // MARK: - Git配置
    struct Git {
        static let maxCommitsToLoad = 500
        static let commitShaLength = 7
        static let defaultBranch = "main"
    }
    
    // MARK: - 文件路径
    struct Paths {
        static let gitDirectory = ".git"
        static let configFile = "config"
        static let headFile = "HEAD"
    }
    
    // MARK: - UserDefaults键值
    struct UserDefaultsKeys {
        static let lastOpenedRepository = "lastOpenedRepository"
        static let windowFrame = "windowFrame"
        static let recentRepositories = "recentRepositories"
    }
    
    // MARK: - 错误消息
    struct ErrorMessages {
        static let repositoryNotFound = "未找到Git仓库"
        static let invalidPath = "无效的文件路径"
        static let permissionDenied = "权限不足"
        static let networkError = "网络连接错误"
    }
}
