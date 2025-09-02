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
        case advanced // 新增一个Tab用于高级设置
    }

    @StateObject private var viewModel = SettingsViewModel()

    var body: some View {
        TabView {
            GitConfigView(viewModel: viewModel)
                .tabItem {
                    Label("Git 配置", systemImage: "wrench.and.screwdriver")
                }
                .tag(Tabs.gitConfig)
            
            // 将SSH设置移到 "高级" Tab
            AdvancedSettingsView(viewModel: viewModel)
                .tabItem {
                    Label("高级", systemImage: "gearshape.2")
                }
                .tag(Tabs.advanced)
        }
        .padding(20)
        .frame(width: 550, height: 300) // 调整了窗口大小
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

/// 新增：高级设置子视图，用于SSH权限等
struct AdvancedSettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        Form {
            Section(header: Text("SSH 访问权限").font(.headline),
                    footer: Text("为了使用SSH协议（例如 git@github.com）克隆或同步仓库，FastGit需要访问您电脑上的.ssh文件夹。").font(.caption).foregroundColor(.secondary)) {
                HStack {
                    if viewModel.hasSshAccess {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("已授权访问 ~/.ssh 文件夹")
                    } else {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                        Text("未授权访问 ~/.ssh 文件夹")
                    }
                    Spacer()
                    Button(viewModel.hasSshAccess ? "重新授权" : "授权") {
                        viewModel.grantSshAccess()
                    }
                }
            }
        }
        .padding()
        .onAppear {
            viewModel.checkSshAccess()
        }
    }
}


struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
