//
//  FileStatusItem.swift
//  FastGit
//
//  Created by FastGit Team on 2025/8/30.
//

import Foundation
import SwiftUI

struct GitFileStatus: Identifiable, Equatable {
    let id = UUID()
    let path: String
    let status: GitFileStatusType
    let isStaged: Bool
    
    // --- 新增: 行数变更信息 ---
    let linesAdded: Int
    let linesDeleted: Int

    init(
        path: String,
        status: GitFileStatusType,
        isStaged: Bool = false,
        linesAdded: Int = 0,
        linesDeleted: Int = 0
    ) {
        self.path = path
        self.status = status
        self.isStaged = isStaged
        self.linesAdded = linesAdded
        self.linesDeleted = linesDeleted
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

// --- 主要修改点 ---
/// Git文件状态枚举
enum GitFileStatusType: String, CaseIterable {
    case modified = "M"
    case added = "A"
    case deleted = "D"
    case renamed = "R"
    case copied = "C"
    case untracked = "??"
    case ignored = "!"
    case typeChanged = "T"
    case conflicted = "U"

    /// 状态显示名称
    var displayName: String {
        switch self {
        case .modified: return "修改"
        case .added: return "新增"
        case .deleted: return "删除"
        case .renamed: return "重命名"
        case .copied: return "复制"
        case .untracked: return "未跟踪"
        case .ignored: return "已忽略"
        case .typeChanged: return "类型变更"
        case .conflicted: return "冲突"
        }
    }
    
    /// 状态颜色 (用于UI显示)
    var displayColor: Color {
        switch self {
        case .added, .untracked:
            return .green
        case .modified:
            return .orange
        case .deleted:
            return .red
        case .renamed, .copied, .typeChanged:
            return .blue
        case .conflicted:
            return .pink
        case .ignored:
            return .gray
        }
    }
}


/// 定义勾选框的三种状态
enum CheckboxState {
    case unchecked // 未勾选
    case checked   // 完全勾选
    case mixed     // 部分勾选（例如，部分修改已暂存）
}

/// 描述一次具体的文件变更（暂存区或工作区）
// --- 修复点: 遵循 Equatable 和 Hashable ---
struct FileChange: Identifiable, Equatable, Hashable {
    var id: String { path }
    let path: String
    let status: GitFileStatusType
    let linesAdded: Int
    let linesDeleted: Int
}

/// 用于UI显示的文件状态项，整合了暂存和未暂存的变更
struct FileStatusItem: Identifiable {
    var id: String { path }
    let path: String
    
    /// 暂存区的变更 (Staged)
    let stagedChange: FileChange?
    
    /// 工作区的变更 (Unstaged)
    let unstagedChange: FileChange?

    /// 根据暂存和未暂存状态，计算勾选框应显示的状态
    var checkboxState: CheckboxState {
        if stagedChange != nil && unstagedChange == nil {
            return .checked
        } else if stagedChange != nil && unstagedChange != nil {
            return .mixed
        } else {
            return .unchecked
        }
    }
    
    /// 在UI上最终显示的组合状态
    var displayStatus: GitFileStatusType {
        return unstagedChange?.status ?? stagedChange?.status ?? .untracked
    }
    
    /// 合并计算的总增加行数
    var totalLinesAdded: Int {
        (stagedChange?.linesAdded ?? 0) + (unstagedChange?.linesAdded ?? 0)
    }
    
    /// 合并计算的总删除行数
    var totalLinesDeleted: Int {
        (stagedChange?.linesDeleted ?? 0) + (unstagedChange?.linesDeleted ?? 0)
    }
}

