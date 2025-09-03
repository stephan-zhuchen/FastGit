//
//  PushView.swift
//  FastGit
//
//  Created by FastGit Team on 2025/8/30.
//

import SwiftUI

/// Push 操作的配置选项
struct UIPushOptions {
    var localBranch: GitBranch
    var remoteBranch: GitBranch?
    var remote: String = "origin"
    var ensureSubmodulesPushed: Bool = false // 默认不勾选
    var pushTags: Bool = false               // 默认不勾选
    var forcePush: Bool = false              // 默认不勾选
}

/// Push 操作的视图，以 sheet 形式弹出
struct PushView: View {
    @Binding var options: UIPushOptions
    let allRemotes: [String]
    let allLocalBranches: [GitBranch]
    let allRemoteBranches: [GitBranch]
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    /// 根据所选远程过滤远程分支
    private var filteredRemoteBranches: [GitBranch] {
        allRemoteBranches.filter { $0.name.hasPrefix("\(options.remote)/") }
    }

    var body: some View {
        VStack(spacing: 24) {
            Text("推送到远程仓库")
                .font(.title2)
                .fontWeight(.semibold)

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 16) {
                GridRow(alignment: .center) {
                    Text("本地分支:")
                        .gridColumnAlignment(.trailing)
                    // 本地分支通常是固定的，所以我们只显示它
                    Text(options.localBranch.name)
                        .padding(.leading, 4)
                }
                
                GridRow(alignment: .center) {
                    Text("远程仓库:")
                        .gridColumnAlignment(.trailing)
                    Picker("", selection: $options.remote) {
                        ForEach(allRemotes, id: \.self) { remote in
                            Text(remote).tag(remote)
                        }
                    }
                    .pickerStyle(.menu)
                }

                GridRow(alignment: .center) {
                    Text("远程分支:")
                        .gridColumnAlignment(.trailing)
                    // 显示远程分支，允许用户选择
                    Picker("", selection: $options.remoteBranch) {
                        // 添加一个 "无" 或 "与本地分支同名" 的选项
                        Text(options.localBranch.shortName).tag(nil as GitBranch?)
                        Divider()
                        ForEach(filteredRemoteBranches) { branch in
                            Text(branch.shortName).tag(branch as GitBranch?)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                GridRow {
                    Text("")
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("确保子模块已推送", isOn: $options.ensureSubmodulesPushed)
                        Toggle("同时推送标签", isOn: $options.pushTags)
                        Toggle("启用强制推送", isOn: $options.forcePush)
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
        .frame(width: 480, height: 320)
    }
}


#if DEBUG
struct PushView_Previews: PreviewProvider {
    static let mockBranches: [GitBranch] = [
        GitBranch(name: "main", isCurrent: true, isRemote: false, targetSha: "abc"),
        GitBranch(name: "develop", isCurrent: false, isRemote: false, targetSha: "def"),
        GitBranch(name: "origin/main", isCurrent: false, isRemote: true, targetSha: "abc"),
        GitBranch(name: "origin/develop", isCurrent: false, isRemote: true, targetSha: "def"),
    ]
    
    struct PreviewWrapper: View {
        @State var options = UIPushOptions(
            localBranch: mockBranches[0],
            remoteBranch: mockBranches[2]
        )
        var body: some View {
            PushView(
                options: $options,
                allRemotes: ["origin"],
                allLocalBranches: [mockBranches[0], mockBranches[1]],
                allRemoteBranches: [mockBranches[2], mockBranches[3]],
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

