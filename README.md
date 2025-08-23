# GitVista - 现代化 macOS Git 客户端

## 项目概述

GitVista 是一款基于 SwiftUI 和 `libgit2` 的原生 macOS Git 客户端，旨在提供闪电般的速度、直观的用户体验和强大的功能。

## 当前状态

🚧 **开发阶段**: 阶段 0 - 基础架构与原型验证

### 已完成的任务 0.1 ✅
- ✅ 创建 macOS SwiftUI 应用项目
- ✅ 建立基本的项目文件结构
- ✅ 实现 MVVM 架构基础
- ✅ 设计并实现应用 Logo

### 已完成的任务 0.2 ✅
- ✅ 选择并集成 SwiftGitX 作为 libgit2 封装库
- ✅ 创建 GitService 类作为 Git 交互唯一入口
- ✅ 实现 openRepository(at path: String) 方法
- ✅ 实现 fetchCommitHistory() 方法
- ✅ 启用真实的 Git 操作功能
- ✅ 实现完整的错误处理机制

### 待完成的任务 0.3 🔄
- ⏳ 设计并创建核心的 Model 对象
- ⏳ 创建主 MainViewModel，管理当前打开的仓库状态
- ⏳ 完善 ViewModel 数据流
- ⏳ 添加错误处理和用户反馈

## 项目结构

```
FastGit/
├── FastGitApp.swift          # 应用入口
├── ContentView.swift         # 主视图
├── Models/                   # 数据模型
│   ├── Repository.swift      # 仓库模型
│   ├── Commit.swift         # 提交模型
│   ├── Branch.swift         # 分支模型
│   └── FileStatus.swift     # 文件状态模型
├── ViewModels/              # 视图模型
│   └── MainViewModel.swift   # 主视图模型
├── Services/                # 服务层
│   └── GitService.swift     # Git服务 (libgit2封装)
├── Config/                  # 配置文件
│   └── AppConfig.swift      # 应用配置
└── Assets.xcassets/         # 资源文件
```

## 技术栈

- **UI框架**: SwiftUI
- **架构模式**: MVVM
- **异步处理**: Swift Concurrency (async/await)
- **包管理**: Swift Package Manager
- **Git引擎**: SwiftGitX (libgit2 Swift封装)

## 开发环境要求

- macOS 13.0+
- Xcode 15.0+
- Swift 5.9+

## 下一步计划

### 任务 0.2: Git 后端服务层集成
- [ ] 研究并选择 libgit2 Swift 封装库
- [ ] 集成 libgit2 依赖
- [ ] 实现真实的 Git 操作替换模拟数据

### 任务 0.3: 架构与 UI 原型完善
- [ ] 完善 ViewModel 数据流
- [ ] 实现真实的仓库打开和提交历史获取
- [ ] 添加错误处理和用户反馈

## 运行项目

1. 使用 Xcode 打开 `FastGit.xcodeproj`
2. 选择目标设备为 "My Mac"
3. 点击 Run 按钮或按 `Cmd+R`

## 功能预览

### 当前功能 (阶段0)
- 📁 打开本地 Git 仓库
- 📋 显示提交历史 (模拟数据)
- 🎨 现代化 SwiftUI 界面
- 🏗️ 完整的 MVVM 架构

### 计划功能
- 🔍 差异查看 (Diff)
- 📝 提交和暂存
- 🌿 分支管理
- 🔄 远程同步
- ⚡ 高性能操作

## 贡献指南

项目目前处于早期开发阶段，欢迎贡献想法和代码。请遵循以下原则：
- 使用 SwiftUI 和现代 Swift 语法
- 遵循 MVVM 架构模式
- 编写清晰的注释和文档
- 保持代码简洁和可测试

## 许可证

待定