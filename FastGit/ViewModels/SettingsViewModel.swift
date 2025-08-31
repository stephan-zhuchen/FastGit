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
    
    private let gitService = GitService.shared

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
}

