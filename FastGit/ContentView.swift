//
//  ContentView.swift
//  FastGit
//
//  Created by 朱晨 on 2025/8/23.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = MainViewModel()
    
    var body: some View {
        NavigationSplitView {
            // 侧边栏 - 暂时显示仓库信息
            VStack(alignment: .leading, spacing: 16) {
                Text("FastGit")
                    .font(.title2)
                    .fontWeight(.bold)
                
                if let repository = viewModel.currentRepository {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("当前仓库")
                            .font(.headline)
                        Text(repository.displayName)
                            .font(.body)
                            .foregroundColor(.secondary)
                        Text(repository.path)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .lineLimit(2)
                    }
                } else {
                    Text("未打开仓库")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding()
            .frame(minWidth: 200)
            
        } detail: {
            // 主内容区域
            VStack(spacing: 20) {
                if viewModel.currentRepository == nil {
                    // 欢迎界面
                    welcomeView
                } else {
                    // 仓库内容
                    repositoryContentView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(NSColor.controlBackgroundColor))
        }
        .fileImporter(
            isPresented: $viewModel.showingFilePicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    Task {
                        await viewModel.openRepository(at: url)
                    }
                }
            case .failure(let error):
                viewModel.errorMessage = "选择文件夹失败: \(error.localizedDescription)"
            }
        }
        .alert("错误", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("确定") {
                viewModel.clearError()
            }
        } message: {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - 子视图
    
    /// 欢迎界面
    private var welcomeView: some View {
        VStack(spacing: 30) {
            // Logo和标题
            VStack(spacing: 16) {
                // 使用代表Git分支的SF Symbol作为临时Logo
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: "point.3.connected.trianglepath.dotted")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundStyle(.white)
                }
                
                Text("欢迎使用 FastGit")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("一款现代化的 macOS Git 客户端")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            
            // 操作按钮
            VStack(spacing: 16) {
                Button(action: {
                    viewModel.showFilePicker()
                }) {
                    HStack {
                        Image(systemName: "folder")
                        Text("打开仓库")
                    }
                    .frame(minWidth: 120)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                
                Button(action: {
                    // TODO: 实现克隆仓库功能
                    print("克隆仓库功能待实现")
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.down")
                        Text("克隆仓库")
                    }
                    .frame(minWidth: 120)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            
            Spacer()
        }
        .padding(40)
    }
    
    /// 仓库内容视图
    private var repositoryContentView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 仓库信息头部
            if let repository = viewModel.currentRepository {
                HStack {
                    VStack(alignment: .leading) {
                        Text(repository.displayName)
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text(repository.path)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button("刷新") {
                        Task {
                            await viewModel.loadCommitHistory()
                        }
                    }
                    .disabled(viewModel.isLoading)
                }
                .padding(.horizontal)
            }
            
            Divider()
            
            // 提交历史列表
            if viewModel.isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("正在加载提交历史...")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.commits.isEmpty {
                Text("暂无提交记录")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(viewModel.commits) { commit in
                    CommitRowView(commit: commit)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

#Preview {
    ContentView()
}
