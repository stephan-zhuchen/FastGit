//
//  FetchView.swift
//  FastGit
//
//  Created by FastGit Team on 2025/8/30.
//

import SwiftUI

/// Fetch 操作的配置选项
struct FetchOptions {
    var remote: String = "origin"
    var prune: Bool = true // Prune is a good default
    var fetchAllTags: Bool = true
}

/// Fetch 操作的视图，以 sheet 形式弹出
struct FetchView: View {
    @Binding var options: FetchOptions
    let allRemotes: [String]
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            Text("抓取远程仓库")
                .font(.title2)
                .fontWeight(.semibold)

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 16) {
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
                
                GridRow {
                    Text("") // Placeholder for alignment
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("Prune (清理远程不再存在的分支)", isOn: $options.prune)
                        Toggle("Fetch all tags (拉取所有标签)", isOn: $options.fetchAllTags)
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
        .frame(width: 480, height: 240)
    }
}


#if DEBUG
struct FetchView_Previews: PreviewProvider {
    struct PreviewWrapper: View {
        @State var options = FetchOptions()
        var body: some View {
            FetchView(
                options: $options,
                allRemotes: ["origin", "upstream"],
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
