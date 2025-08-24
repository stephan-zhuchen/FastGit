//
//  ContentView.swift
//  FastGit
//
//  Created by 朱晨 on 2025/8/23.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = MainViewModel.shared
    @StateObject private var repositoryManager = RepositoryManager.shared
    @State private var selectedRepository: GitRepository?
    
    var body: some View {
        NavigationSplitView {
            // 侧边栏
            SidebarView(
                selectedRepository: $selectedRepository,
                onOpenRepository: {
                    viewModel.showFilePicker()
                }
            )
        } detail: {
            // 主内容区域（基于侧边栏选择状态决定显示内容）
            if selectedRepository == nil {
                // 欢迎界面（应用启动或取消选择时显示）
                WelcomeView(
                    onOpenRepository: {
                        viewModel.showFilePicker()
                    },
                    onCloneRepository: {
                        // TODO: 实现克隆仓库功能
                        print("克隆仓库功能待实现")
                    }
                )
            } else {
                // 仓库内容（选中仓库时显示）
                repositoryContentView
            }
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
                        // 同步更新侧边栏选择状态（关键修复）
                        if let currentRepo = viewModel.currentRepository {
                            selectedRepository = currentRepo
                        }
                    }
                }
            case .failure(let error):
                viewModel.errorMessage = "选择文件夹失败: \(error.localizedDescription)"
            }
        }
        .alert("错误", isPresented: .constant(viewModel.errorMessage != nil && viewModel.errorMessage!.contains("选择文件夹失败"))) {
            Button("确定") {
                viewModel.clearError()
            }
        } message: {
            if let errorMessage = viewModel.errorMessage, errorMessage.contains("选择文件夹失败") {
                Text(errorMessage)
            }
        }
        .onAppear {
            // 在应用启动时清理无效仓库
            repositoryManager.cleanupInvalidRepositories()
            // 确保应用启动时显示欢迎界面
            selectedRepository = nil
            repositoryManager.setCurrentRepository(nil)
        }
        .onChange(of: viewModel.currentRepository) { _, newRepository in
            // 当MainViewModel的currentRepository变化时，同步更新selectedRepository
            selectedRepository = newRepository
            print("🔄 同步selectedRepository状态: \(newRepository?.displayName ?? "nil")")
        }
    }
    
    // MARK: - 子视图
    
    /// 仓库内容视图
    private var repositoryContentView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 仓库信息头部
            if let repository = viewModel.currentRepository {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(repository.displayName)
                                .font(.title2)
                                .fontWeight(.semibold)
                            Text(repository.path)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            Task {
                                await viewModel.loadCommitHistory()
                            }
                        }) {
                            Label("刷新", systemImage: "arrow.clockwise")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        .disabled(viewModel.isLoading)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            
            // 提交历史区域
            if viewModel.isLoading {
                // 加载状态
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("正在加载提交历史...")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            } else if let errorMessage = viewModel.errorMessage, !errorMessage.isEmpty {
                // 错误状态
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundStyle(.orange)
                    
                    VStack(spacing: 8) {
                        Text("加载失败")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(errorMessage)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    HStack(spacing: 12) {
                        Button("重试") {
                            Task {
                                viewModel.clearError()
                                await viewModel.loadCommitHistory()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button("关闭") {
                            viewModel.clearError()
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            } else if viewModel.commits.isEmpty {
                // 空状态
                VStack(spacing: 16) {
                    Image(systemName: "clock.badge.questionmark")
                        .font(.system(size: 48))
                        .foregroundStyle(.tertiary)
                    Text("暂无提交记录")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("这个仓库可能是空的或者没有提交历史")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                // 提交历史表格
                VStack(alignment: .leading, spacing: 0) {
                    // 表格标题栏
                    HStack {
                        Text("提交历史")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        Text("\(viewModel.commits.count) 个提交")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.quaternary)
                            .clipShape(Capsule())
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(.regularMaterial)
                    
                    Divider()
                    
                    // 表格头部
                    HStack(spacing: 0) {
                        // 提交信息列头
                        Text("路线图与主题")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                        
                        // 作者列头
                        Text("作者")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .frame(width: 120, alignment: .leading)
                            .padding(.horizontal, 8)
                        
                        // SHA列头
                        Text("提交指纹")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .frame(width: 100, alignment: .center)
                            .padding(.horizontal, 8)
                        
                        // 时间列头
                        Text("提交时间")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .frame(width: 140, alignment: .trailing)
                            .padding(.horizontal, 12)
                    }
                    .padding(.vertical, 8)
                    .background(.quaternary.opacity(0.3))
                    
                    Divider()
                    
                    // 提交数据表格
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(viewModel.commits.enumerated()), id: \.element.id) { index, commit in
                                CommitTableRowView(commit: commit, isEven: index % 2 == 0)
                                    .onTapGesture {
                                        // TODO: 选择提交处理
                                        print("选择提交: \(commit.shortSha)")
                                    }
                                
                                if index < viewModel.commits.count - 1 {
                                    Divider()
                                        .padding(.leading, 12)
                                }
                            }
                        }
                    }
                }
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

#Preview {
    ContentView()
}
