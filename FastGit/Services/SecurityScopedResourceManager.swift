//
//  SecurityScopedResourceManager.swift
//  FastGit
//
//  Created by FastGit Team
//

import Foundation
import AppKit

/// 安全作用域资源管理器 - 处理macOS沙盒环境下的文件访问权限
@MainActor
class SecurityScopedResourceManager: ObservableObject {
    
    // MARK: - 单例
    static let shared = SecurityScopedResourceManager()
    
    // MARK: - 私有属性
    private var activeBookmarks: [String: Data] = [:]
    private var activeURLs: [String: URL] = [:]
    private let userDefaults = UserDefaults.standard
    private let bookmarksKey = "SecurityScopedBookmarks"
    
    // MARK: - 初始化
    private init() {
        loadSavedBookmarks()
    }
    
    // MARK: - 公共方法
    
    /// 为仓库路径创建或获取安全作用域访问权限
    /// - Parameter repositoryPath: 仓库路径
    /// - Returns: 可访问的URL，如果失败返回nil
    func getSecurityScopedURL(for repositoryPath: String) -> URL? {
        // 首先尝试从已保存的书签中恢复访问权限
        if let bookmark = activeBookmarks[repositoryPath] {
            if let url = restoreURL(from: bookmark, for: repositoryPath) {
                return url
            }
        }
        
        // 如果没有保存的书签，需要用户重新授权
        return requestUserAuthorization(for: repositoryPath)
    }
    
    /// 为新选择的仓库创建安全作用域书签
    /// - Parameter url: 用户选择的仓库URL
    /// - Returns: 是否成功创建书签
    @discardableResult
    func createBookmark(for url: URL) -> Bool {
        do {
            // 创建安全作用域书签
            let bookmarkData = try url.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            
            let path = url.path
            activeBookmarks[path] = bookmarkData
            activeURLs[path] = url
            
            // 保存到UserDefaults
            saveBookmarks()
            
            print("✅ 已为路径创建安全书签: \(path)")
            return true
        } catch {
            print("❌ 创建安全书签失败: \(error.localizedDescription)")
            return false
        }
    }
    
    /// 移除指定路径的书签
    /// - Parameter path: 要移除的仓库路径
    func removeBookmark(for path: String) {
        // 停止访问安全作用域资源
        if let url = activeURLs[path] {
            url.stopAccessingSecurityScopedResource()
        }
        
        activeBookmarks.removeValue(forKey: path)
        activeURLs.removeValue(forKey: path)
        saveBookmarks()
        
        print("🗑️ 已移除路径的安全书签: \(path)")
    }
    
    /// 清除所有书签
    func clearAllBookmarks() {
        // 停止所有正在访问的资源
        for url in activeURLs.values {
            url.stopAccessingSecurityScopedResource()
        }
        
        activeBookmarks.removeAll()
        activeURLs.removeAll()
        userDefaults.removeObject(forKey: bookmarksKey)
        
        print("🗑️ 已清除所有安全书签")
    }
    
    // MARK: - 私有方法
    
    /// 从书签数据恢复URL访问权限
    /// - Parameters:
    ///   - bookmarkData: 书签数据
    ///   - path: 仓库路径
    /// - Returns: 恢复的URL
    private func restoreURL(from bookmarkData: Data, for path: String) -> URL? {
        do {
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: [.withSecurityScope, .withoutUI],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            
            // 检查书签是否过期
            if isStale {
                print("⚠️ 书签已过期，需要更新: \(path)")
                // 尝试重新创建书签
                if createBookmark(for: url) {
                    return url
                }
                return nil
            }
            
            // 开始访问安全作用域资源
            if url.startAccessingSecurityScopedResource() {
                activeURLs[path] = url
                print("🔓 已恢复安全作用域访问: \(path)")
                return url
            } else {
                print("❌ 无法开始访问安全作用域资源: \(path)")
                return nil
            }
        } catch {
            print("❌ 恢复书签失败: \(error.localizedDescription)")
            // 移除无效的书签
            activeBookmarks.removeValue(forKey: path)
            saveBookmarks()
            return nil
        }
    }
    
    /// 请求用户授权访问仓库
    /// - Parameter repositoryPath: 仓库路径
    /// - Returns: 授权的URL
    private func requestUserAuthorization(for repositoryPath: String) -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.title = "授权访问仓库"
        panel.message = "FastGit需要访问此仓库的权限。请选择仓库所在文件夹以继续。"
        panel.prompt = "授权访问"
        
        // 尝试导航到目标路径
        if FileManager.default.fileExists(atPath: repositoryPath) {
            panel.directoryURL = URL(fileURLWithPath: repositoryPath)
        }
        
        let response = panel.runModal()
        guard response == .OK, let selectedURL = panel.url else {
            return nil
        }
        
        // 验证用户选择的路径
        if selectedURL.path == repositoryPath {
            // 路径匹配，创建书签
            if createBookmark(for: selectedURL) {
                return selectedURL
            }
        } else {
            print("⚠️ 用户选择的路径与目标路径不匹配")
            print("  目标路径: \(repositoryPath)")
            print("  选择路径: \(selectedURL.path)")
        }
        
        return nil
    }
    
    /// 保存书签到UserDefaults
    private func saveBookmarks() {
        userDefaults.set(activeBookmarks, forKey: bookmarksKey)
    }
    
    /// 从UserDefaults加载保存的书签
    private func loadSavedBookmarks() {
        guard let savedBookmarks = userDefaults.object(forKey: bookmarksKey) as? [String: Data] else {
            return
        }
        
        activeBookmarks = savedBookmarks
        print("📖 已加载 \(savedBookmarks.count) 个安全书签")
        
        // 尝试恢复所有书签的访问权限
        for (path, bookmarkData) in savedBookmarks {
            if let _ = restoreURL(from: bookmarkData, for: path) {
                print("✅ 已恢复书签访问权限: \(path)")
            }
        }
    }
}

// MARK: - 扩展：便利方法
extension SecurityScopedResourceManager {
    
    /// 检查是否有指定路径的有效访问权限
    /// - Parameter path: 仓库路径
    /// - Returns: 是否有有效权限
    func hasValidAccess(for path: String) -> Bool {
        return activeURLs[path] != nil
    }
    
    /// 获取所有有权限访问的路径
    var authorizedPaths: [String] {
        return Array(activeURLs.keys)
    }
    
    /// 获取权限统计信息
    var accessStats: (bookmarked: Int, active: Int) {
        return (bookmarked: activeBookmarks.count, active: activeURLs.count)
    }
}