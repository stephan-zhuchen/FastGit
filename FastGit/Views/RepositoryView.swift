//
//  RepositoryView.swift
//  FastGit
//
//  Created by FastGit Team
//

import SwiftUI

/// 仓库视图 - 实现三区域布局
struct RepositoryView: View {
    let repository: GitRepository
    let onClose: ((GitRepository) -> Void)?  // 关闭Tab的回调
    @State private var selectedNavigationOption: SidebarNavigationOption? = .history
    
    // 默认初始化方法，保持向后兼容
    init(
        repository: GitRepository,
        onClose: ((GitRepository) -> Void)? = nil
    ) {
        self.repository = repository
        self.onClose = onClose
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // 左侧功能导航栏
            SidebarNavigationView(selectedOption: $selectedNavigationOption)
            
            Divider()
            
            // 右侧内容区域
            VStack(spacing: 0) {
                // 上方工具栏（不再显示关闭按钮）
                RepositoryToolbarView(onClose: nil)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                
                Divider()
                    .padding(.horizontal, 16)
                
                // 下方主体内容区域
                Group {
                    if let option = selectedNavigationOption {
                        contentView(for: option)
                    } else {
                        defaultContentView
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .navigationTitle(repository.displayName)
        .navigationSubtitle(repository.path)
    }
    
    // MARK: - 子视图
    
    /// 根据导航选项返回对应的内容视图
    /// - Parameter option: 导航选项
    /// - Returns: 对应的视图
    @ViewBuilder
    private func contentView(for option: SidebarNavigationOption) -> some View {
        switch option {
        case .history:
            HistoryView(repository: repository)
        case .changes:
            placeholderView(for: "修改", icon: "doc.text.below.ecg")
        case .branches:
            placeholderView(for: "分支", icon: "point.3.connected.trianglepath.dotted")
        case .stash:
            placeholderView(for: "Stash", icon: "tray.full")
        }
    }
    
    /// 默认内容视图（无选择时显示）
    private var defaultContentView: some View {
        VStack(spacing: 20) {
            Image(systemName: "sidebar.left")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            
            Text("请从左侧选择功能")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("选择左侧导航栏中的功能来查看相应内容")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    /// 占位符视图（用于未实现的功能）
    /// - Parameters:
    ///   - title: 功能标题
    ///   - icon: 图标名称
    /// - Returns: 占位符视图
    private func placeholderView(for title: String, icon: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(.orange)
            
            VStack(spacing: 8) {
                Text("\(title)功能")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("此功能正在开发中，敬请期待")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("返回历史") {
                selectedNavigationOption = .history
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

#Preview {
    RepositoryView(
        repository: GitRepository(
            name: "FastGit", 
            path: "/Users/user/Documents/FastGit"
        )
    )
    .frame(width: 1000, height: 700)
}