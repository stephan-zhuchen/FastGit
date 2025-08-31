//
//  NewBranchView.swift
//  FastGit
//
//  Created by FastGit Team on 2025/8/30.
//

import SwiftUI

/// 新建分支的配置选项
struct NewBranchOptions {
    var branchName: String = ""
    var baseBranch: GitBranch
    var uncommittedChangesOption: UncommittedChangesOption = .stash
    var allowOverwrite: Bool = false
    var checkoutAfterCreation: Bool = true
    var updateSubmodules: Bool = true
}

/// 定义处理未提交变更的策略
enum UncommittedChangesOption {
    case stash
    case discard
}

/// 新建分支的视图，以 sheet 形式弹出
struct NewBranchView: View {
    @Binding var options: NewBranchOptions
    let allBranches: [GitBranch]
    let hasUncommittedChanges: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            // 标题
            Text("创建本地分支")
                .font(.title2)
                .fontWeight(.semibold)

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 16) {
                // 基于分支
                GridRow(alignment: .center) {
                    Text("新分支基于:")
                        .gridColumnAlignment(.trailing)
                    
                    Picker("", selection: $options.baseBranch) {
                        ForEach(allBranches.filter { !$0.isRemote }) { branch in
                            Text(branch.name).tag(branch)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }

                // 分支名称
                GridRow(alignment: .center) {
                    Text("新分支名:")
                        .gridColumnAlignment(.trailing)
                    TextField("填写分支名称", text: $options.branchName)
                        .textFieldStyle(.roundedBorder)
                }
                
                // 未提交变更的选项
                if hasUncommittedChanges {
                    GridRow(alignment: .top) {
                        Text("未提交更改:")
                            .gridColumnAlignment(.trailing)
                            .padding(.top, 5)
                        Picker("", selection: $options.uncommittedChangesOption) {
                            Text("隐藏并自动恢复").tag(UncommittedChangesOption.stash)
                            Text("丢弃更改").tag(UncommittedChangesOption.discard)
                        }
                        .pickerStyle(.radioGroup)
                        .labelsHidden()
                    }
                }

                // 其他选项
                GridRow {
                    Text("") // 使用空Text作为占位符
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("允许重置已存在的分支", isOn: $options.allowOverwrite)
                        Toggle("完成后切换到新分支", isOn: $options.checkoutAfterCreation)
                    }
                }
            }
            // --- 修复点: 让 Grid 充满可用宽度 ---
            .frame(maxWidth: .infinity)
            
            Spacer()

            // 底部按钮
            HStack {
                Spacer()
                Button("取消") {
                    onCancel()
                    dismiss()
                }
                Button("确定") {
                    onConfirm()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(options.branchName.isEmpty)
            }
        }
        .padding(30)
        .frame(width: 420, height: hasUncommittedChanges ? 320 : 260)
        .animation(.default, value: hasUncommittedChanges)
    }
}

#if DEBUG
struct NewBranchView_Previews: PreviewProvider {
    static let mockBranches: [GitBranch] = [
        GitBranch(name: "main", isCurrent: true, isRemote: false, targetSha: "abc"),
        GitBranch(name: "develop", isCurrent: false, isRemote: false, targetSha: "def")
    ]
    
    struct PreviewWrapper: View {
        @State var options = NewBranchOptions(baseBranch: mockBranches[0])
        var body: some View {
            NewBranchView(
                options: $options,
                allBranches: mockBranches,
                hasUncommittedChanges: true,
                onConfirm: { print("Confirmed: \(options)") },
                onCancel: { print("Cancelled") }
            )
        }
    }
    
    static var previews: some View {
        PreviewWrapper()
    }
}
#endif

