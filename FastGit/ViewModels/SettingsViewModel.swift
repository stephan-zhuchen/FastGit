//
//  SettingsViewModel.swift
//  FastGit
//
//  Created by FastGit Team on 2025/8/31.
//

import SwiftUI
import Foundation
import SwiftGitX

@MainActor
class SettingsViewModel: ObservableObject {
    @Published var userName: String = ""
    @Published var userEmail: String = ""
    // 新增：跟踪SSH访问状态
    @Published var hasSshAccess: Bool = false
    
    private let gitService = GitService.shared
    // 新增：获取SecurityScopedResourceManager的单例
    private let securityManager = SecurityScopedResourceManager.shared

    init() {
        // 新增：初始化时检查SSH访问状态
        checkSshAccess()
    }
    
    func loadGitConfig() {
        // 加载用户信息
        // 优先从应用内存储 (UserDefaults) 读取
        // 如果应用内没有，则尝试从全局 .gitconfig 文件读取作为初始默认值
        self.userName = UserDefaults.standard.string(forKey: "globalUserName") ?? (Repository.config.string(forKey: "user.name") ?? "")
        self.userEmail = UserDefaults.standard.string(forKey: "globalUserEmail") ?? (Repository.config.string(forKey: "user.email") ?? "")
    }
    
    func saveChanges() {
        // 将用户的配置保存到应用专属的 UserDefaults 中，这符合沙盒规范
        UserDefaults.standard.set(userName, forKey: "globalUserName")
        UserDefaults.standard.set(userEmail, forKey: "globalUserEmail")
        
        print("✅ Git 配置已保存至应用内存储")
    }

    // MARK: - 新增 SSH 权限管理

    /// 检查SSH文件夹的访问权限
    func checkSshAccess() {
        self.hasSshAccess = securityManager.hasSshFolderAccess
    }

    /// 请求用户授权访问SSH文件夹
    func grantSshAccess() {
        securityManager.grantSshFolderAccess()
        // 更新UI状态
        checkSshAccess()
    }
}
