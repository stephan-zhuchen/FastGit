//
//  FileStatus.swift
//  FastGit
//
//  Created by FastGit Team
//

import Foundation

/// Git文件状态模型
struct GitFileStatus: Identifiable, Equatable {
    let id = UUID()
    let path: String
    let status: GitFileStatusType
    let isStaged: Bool
    
    init(path: String, status: GitFileStatusType, isStaged: Bool = false) {
        self.path = path
        self.status = status
        self.isStaged = isStaged
    }
    
    /// 文件名
    var fileName: String {
        return URL(fileURLWithPath: path).lastPathComponent
    }
    
    /// 文件目录
    var directory: String {
        let dir = URL(fileURLWithPath: path).deletingLastPathComponent().relativePath
        return dir == "." ? "" : dir
    }
}

/// Git文件状态枚举
enum GitFileStatusType: String, CaseIterable {
    case added = "A"       // 新增文件
    case modified = "M"    // 修改文件
    case deleted = "D"     // 删除文件
    case renamed = "R"     // 重命名文件
    case copied = "C"      // 复制文件
    case untracked = "??"  // 未跟踪文件
    case ignored = "!"     // 忽略文件
    case typeChanged = "T" // 文件类型改变
    
    /// 状态显示名称
    var displayName: String {
        switch self {
        case .added: return "新增"
        case .modified: return "修改"
        case .deleted: return "删除"
        case .renamed: return "重命名"
        case .copied: return "复制"
        case .untracked: return "未跟踪"
        case .ignored: return "忽略"
        case .typeChanged: return "类型变更"
        }
    }
    
    /// 状态颜色 (用于UI显示)
    var colorName: String {
        switch self {
        case .added, .untracked: return "green"
        case .modified: return "orange"
        case .deleted: return "red"
        case .renamed, .copied: return "blue"
        case .ignored: return "gray"
        case .typeChanged: return "purple"
        }
    }
}