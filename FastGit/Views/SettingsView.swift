//
//  SettingsView.swift
//  FastGit
//
//  Created by FastGit Team on 2025/8/31.
//

import SwiftUI

/// 应用设置视图
struct SettingsView: View {
    private enum Tabs: Hashable {
        case gitConfig
        case general
    }

    @StateObject private var viewModel = SettingsViewModel()

    var body: some View {
        TabView {
            GitConfigView(viewModel: viewModel)
                .tabItem {
                    Label("Git 配置", systemImage: "wrench.and.screwdriver")
                }
                .tag(Tabs.gitConfig)
            
            // 可以为未来的设置选项预留位置
            Text("通用设置")
                .tabItem {
                    Label("通用", systemImage: "gear")
                }
                .tag(Tabs.general)
        }
        .padding(20)
        .frame(width: 500, height: 240) // 调整了高度以适应新布局
    }
}

/// Git 配置子视图
struct GitConfigView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @State private var saveStatusMessage: String?

    var body: some View {
        Form {
            Section(header: Text("全局作者信息").font(.headline),
                    footer: Text("此信息将作为所有仓库的默认签名，除非仓库有独立的本地配置。").font(.caption).foregroundColor(.secondary)) {
                TextField("用户名", text: $viewModel.userName)
                TextField("邮箱", text: $viewModel.userEmail)
            }
            
            Spacer()
            
            HStack {
                if let statusMessage = saveStatusMessage {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundColor(.green)
                }
                Spacer()
                Button("保存更改") {
                    viewModel.saveChanges()
                    // 显示一个短暂的保存成功提示
                    saveStatusMessage = "配置已成功保存！"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        saveStatusMessage = nil
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .onAppear {
            viewModel.loadGitConfig()
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}

