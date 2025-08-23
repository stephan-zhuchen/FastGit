# FastGit 测试配置说明

## 问题说明

编译错误是由于测试文件(`GitServiceTests.swift`)放置在主应用target中导致的XCTest链接错误。

## 解决方案

### 当前状态
- 测试文件已移动到 `FastGitTests/` 目录
- 主应用编译正常
- 所有核心功能完整

### 如需添加单元测试，请按以下步骤操作：

#### 1. 在Xcode中添加测试Target
1. 选择项目导航器中的 `FastGit.xcodeproj`
2. 点击左下角的 `+` 按钮
3. 选择 `macOS` → `Unit Testing Bundle`
4. 命名为 `FastGitTests`
5. 确保 `Target to be Tested` 选择 `FastGit`

#### 2. 移动测试文件
1. 将 `FastGitTests/GitServiceTests.swift` 拖拽到新创建的测试target中
2. 确保文件的 Target Membership 只勾选 `FastGitTests`

#### 3. 配置测试依赖
在测试target的 `Build Phases` → `Link Binary With Libraries` 中添加：
- `XCTest.framework`
- 确保能访问 `FastGit` 模块

#### 4. 验证配置
运行测试：`Cmd+U`

## 当前项目结构
```
FastGit/
├── FastGit/                 # 主应用target
│   ├── Services/
│   ├── Models/
│   ├── ViewModels/
│   └── ...
├── FastGitTests/           # 测试文件(临时存放)
│   └── GitServiceTests.swift
└── External/
    └── SwiftGitX/
```

## 注意事项
- 测试文件不应该放在主应用target中
- XCTest框架只能在测试target中使用
- 当前版本为了避免编译错误已暂时移除测试文件
- 后续可按需要重新配置测试target