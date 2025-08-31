//
//  LocalChangesView.swift
//  FastGit
//
//  Created by FastGit Team on 2025/8/30.
//

import SwiftUI

/// 本地修改视图
struct LocalChangesView: View {
    let repository: GitRepository
    
    @State private var allFileItems: [FileStatusItem] = []
    @State private var isLoading = true
    
    // --- 状态管理 ---
    @State private var checkedFilePaths: Set<String> = []
    @State private var rowSelection: Set<String> = []
    @State private var showUntrackedFiles = true
    @State private var showIgnoredFiles = false
    
    // --- Commit message state ---
    @State private var commitSubject = ""
    @State private var commitDescription = ""
    @State private var isAmending = false
    @State private var isSigningOff = false
    
    private let gitService = GitService.shared
    
    // MARK: - 计算属性
    
    /// 已跟踪的文件列表 (暂存和未暂存)
    private var trackedItems: [FileStatusItem] {
        allFileItems.filter { $0.displayStatus != .untracked && $0.displayStatus != .ignored }
    }
    
    /// 未跟踪和被忽略的文件列表 (根据复选框状态过滤)
    private var otherItems: [FileStatusItem] {
        allFileItems.filter { item in
            (item.displayStatus == .untracked && showUntrackedFiles) ||
            (item.displayStatus == .ignored && showIgnoredFiles)
        }
    }
    
    private var canCommit: Bool {
        !commitSubject.isEmpty && !checkedFilePaths.isEmpty
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                ProgressView("正在加载本地修改...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 0) {
                    commitMessageSection
                    
                    fileListSection
                        .layoutPriority(1)
                    
                    Divider()
                    
                    commitActionsSection
                }
            }
        }
        .task {
            await loadStatus()
        }
    }
    
    // MARK: - 子视图
    
    /// 提交信息输入区
    private var commitMessageSection: some View {
        VStack(spacing: 0) {
            // 输入框部分
            VStack(spacing: 0) {
                TextField("填写提交信息主题", text: $commitSubject)
                    .textFieldStyle(.plain)
                    .padding(12)
                
                Divider()
                
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $commitDescription)
                        .font(.body)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .frame(height: 120)
                    
                    if commitDescription.isEmpty {
                        Text("详细描述")
                            .font(.body)
                            .foregroundColor(Color(nsColor: .placeholderTextColor))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .allowsHitTesting(false)
                    }
                }
            }
            
            Divider()
            
            // --- 修改: 将选项移到这里 ---
            HStack {
                Toggle(isOn: $isSigningOff) {
                    Text("署名 (-s)")
                }.toggleStyle(.checkbox)
                
                Toggle(isOn: $isAmending) {
                    Text("修补 (--amend)")
                }.toggleStyle(.checkbox)
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(nsColor: .textBackgroundColor))

        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        )
        .padding(16)
    }
    
    private var fileListSection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if trackedItems.isEmpty && otherItems.isEmpty {
                    emptyStateView
                } else {
                    if !trackedItems.isEmpty {
                        FileStatusSection(
                            title: "已跟踪的变更 (\(trackedItems.count))",
                            items: trackedItems,
                            checkedPaths: $checkedFilePaths,
                            selection: $rowSelection
                        )
                    }
                    
                    if !otherItems.isEmpty {
                        FileStatusSection(
                            title: "其他文件 (\(otherItems.count))",
                            items: otherItems,
                            checkedPaths: $checkedFilePaths,
                            selection: $rowSelection
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }
    
    private var emptyStateView: some View {
        VStack {
            Spacer()
            Text("没有本地修改")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("您的工作区是干净的。")
                .font(.subheadline)
                .foregroundColor(Color.secondary.opacity(0.7))
            Spacer()
        }
        .frame(height: 200)
    }

    /// 提交操作区
    private var commitActionsSection: some View {
        HStack {
            // --- 修改: 移除 "署名" 和 "修补" ---
            Toggle(isOn: $showUntrackedFiles) {
                Text("显示未跟踪的文件")
            }.toggleStyle(.checkbox)
            
            Toggle(isOn: $showIgnoredFiles) {
                Text("显示忽略的文件")
            }.toggleStyle(.checkbox)
            
            Spacer()
            
            Button("提交") {
                // TODO: 实现提交逻辑
            }.disabled(!canCommit)
            
            Button("提交并推送") {
                // TODO: 实现提交并推送逻辑
            }.buttonStyle(.borderedProminent).disabled(!canCommit)
        }
        .padding(16)
        .background(.regularMaterial)
    }
    
    // MARK: - 数据加载
    
    private func loadStatus() async {
        isLoading = true
        let items = await gitService.fetchStatus(for: repository)
        self.allFileItems = items
        
        self.checkedFilePaths = Set(
            items.filter { $0.stagedChange != nil }.map { $0.path }
        )
        isLoading = false
    }
}


// MARK: - 可重用组件

private struct FileStatusSection: View {
    let title: String
    let items: [FileStatusItem]
    @Binding var checkedPaths: Set<String>
    @Binding var selection: Set<String>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .padding(.top, 16)
            
            Table(items, selection: $selection) {
                TableColumn("") { item in
                    CheckboxView(state: item.checkboxState)
                        .onTapGesture {
                            toggleCheck(for: item)
                        }
                }
                .width(35)
                
                TableColumn("文件", value: \.path)
                    .width(min: 200)
                
                TableColumn("状态") { item in
                    Text(item.displayStatus.displayName)
                        .foregroundStyle(item.displayStatus.displayColor)
                }
                .width(60)
                
                TableColumn("增删行数") { item in
                    LineCountView(added: item.totalLinesAdded, deleted: item.totalLinesDeleted)
                }
                .width(100)
            }
            .tableStyle(.inset(alternatesRowBackgrounds: true))
            .frame(height: CGFloat(items.count) * 28 + 28)
        }
    }
    
    private func toggleCheck(for item: FileStatusItem) {
        let itemsToToggle = selection.contains(item.id) ? items.filter { selection.contains($0.id) } : [item]
        let pathsToToggle = itemsToToggle.map { $0.path }
        
        let shouldCheck = itemsToToggle.contains { $0.checkboxState != .checked }
        
        if shouldCheck {
            checkedPaths.formUnion(pathsToToggle)
        } else {
            checkedPaths.subtract(pathsToToggle)
        }
    }
}

private struct CheckboxView: View {
    let state: CheckboxState
    
    var body: some View {
        Image(systemName: imageName)
            .font(.body)
            .foregroundStyle(state == .unchecked ? Color.secondary : Color.accentColor)
    }
    
    private var imageName: String {
        switch state {
        case .unchecked: return "square"
        case .checked: return "checkmark.square.fill"
        case .mixed: return "minus.square.fill"
        }
    }
}

private struct LineCountView: View {
    let added: Int
    let deleted: Int
    
    var body: some View {
        HStack(spacing: 8) {
            if added > 0 {
                Text("+\(added)")
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.green)
            }
            if deleted > 0 {
                Text("-\(deleted)")
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.red)
            }
        }
    }
}


#Preview {
    LocalChangesView(
        repository: GitRepository(name: "FastGit", path: "/Users/user/FastGit")
    )
}

