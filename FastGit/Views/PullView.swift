//
//  PullView.swift
//  FastGit
//
//  Created by FastGit Team on 2025/8/30.
//

import SwiftUI

/// Pull 操作的配置选项
struct PullOptions {
    // TODO: 将 'String' 替换为实际的 Remote 模型
    var selectedRemote: String = "origin"
    var remoteBranch: GitBranch
    var localBranch: GitBranch
    var uncommittedChangesOption: UncommittedChangesOption = .stash
    var useRebase: Bool = true
    var updateSubmodules: Bool = true
}

/// Pull 操作的视图，以 sheet 形式弹出
struct PullView: View {
    @Binding var options: PullOptions
    let allRemotes: [String] // TODO: 替换为 Remote 模型数组
    let allBranches: [GitBranch]
    let hasUncommittedChanges: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    private var remoteBranches: [GitBranch] {
        allBranches.filter { $0.isRemote && $0.name.hasPrefix("\(options.selectedRemote)/") }
    }
    
    private var localBranches: [GitBranch] {
        allBranches.filter { !$0.isRemote }
    }

    var body: some View {
        VStack(spacing: 24) {
            Text("拉回 (拉取并合并)")
                .font(.title2)
                .fontWeight(.semibold)

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 16) {
                GridRow(alignment: .center) {
                    Text("远程:")
                        .gridColumnAlignment(.trailing)
                    Picker("", selection: $options.selectedRemote) {
                        ForEach(allRemotes, id: \.self) { remote in
                            Text(remote).tag(remote)
                        }
                    }
                    .pickerStyle(.menu)
                }

                GridRow(alignment: .center) {
                    Text("拉取分支:")
                        .gridColumnAlignment(.trailing)
                    Picker("", selection: $options.remoteBranch) {
                        ForEach(remoteBranches) { branch in
                            Text(branch.shortName).tag(branch)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                GridRow(alignment: .center) {
                    Text("本地分支:")
                        .gridColumnAlignment(.trailing)
                    // 通常本地分支是固定的，所以我们只显示它
                    Text(options.localBranch.name)
                        .padding(.leading, 4)
                }
                
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

                GridRow {
                    Text("")
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("使用变基方式合并分支", isOn: $options.useRebase)
                        Toggle("同时更新所有子模块", isOn: $options.updateSubmodules)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            
            Spacer()

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
            }
        }
        .padding(30)
        .frame(width: 480, height: hasUncommittedChanges ? 380 : 320)
        .animation(.default, value: hasUncommittedChanges)
    }
}


#if DEBUG
struct PullView_Previews: PreviewProvider {
    static let mockBranches: [GitBranch] = [
        GitBranch(name: "main", isCurrent: true, isRemote: false, targetSha: "abc"),
        GitBranch(name: "develop", isCurrent: false, isRemote: false, targetSha: "def"),
        GitBranch(name: "origin/main", isCurrent: false, isRemote: true, targetSha: "abc"),
        GitBranch(name: "origin/develop", isCurrent: false, isRemote: true, targetSha: "def"),
        GitBranch(name: "upstream/main", isCurrent: false, isRemote: true, targetSha: "xyz"),
    ]
    
    struct PreviewWrapper: View {
        @State var options = PullOptions(
            remoteBranch: mockBranches[2],
            localBranch: mockBranches[0]
        )
        var body: some View {
            PullView(
                options: $options,
                allRemotes: ["origin", "upstream"],
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
