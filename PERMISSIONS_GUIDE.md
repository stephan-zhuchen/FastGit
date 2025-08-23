# FastGit 权限问题解决方案

## 问题描述

当FastGit尝试打开Git仓库时，可能会遇到以下错误：
```
❌ 获取提交历史失败: failedToGetHEAD("could not open '/path/to/repo/.git/HEAD': Operation not permitted")
```

## 问题原因

这是macOS沙盒(App Sandbox)权限限制导致的，应用无法访问用户选择目录之外的文件。

## 解决方案

### 1. 应用权限配置 (已修复)

已更新 `FastGit.entitlements` 文件，添加了必要的权限：

```xml
<key>com.apple.security.files.user-selected.read-write</key>
<true/>
<key>com.apple.security.files.bookmarks.app-scope</key>
<true/>
<key>com.apple.security.files.bookmarks.document-scope</key>
<true/>
```

### 2. 安全作用域资源管理 (新增)

在 `MainViewModel` 中添加了安全作用域资源管理：
- 用户选择仓库时，自动开始访问安全作用域资源
- 在应用生命周期中保持访问权限
- 应用退出或切换仓库时，正确释放访问权限

这确保了SwiftGitX在整个会话期间都有足够的权限访问Git仓库文件。

### 2. 使用方法

**重要**：必须通过以下方式打开Git仓库：

1. **使用文件选择器**：
   - 点击"Open Repository"按钮
   - 在系统文件选择器中选择Git仓库根目录
   - 不要直接输入路径或拖拽文件夹

2. **选择正确的目录**：
   - 选择包含`.git`文件夹的项目根目录
   - 不要选择`.git`文件夹本身

### 3. 权限工作原理

- macOS沙盒应用只能访问用户通过系统对话框明确选择的文件/文件夹
- 一旦用户选择了文件夹，应用获得该文件夹及其所有子文件的访问权限
- 这包括`.git`目录内的所有Git相关文件

### 4. 如果仍然遇到问题

如果按照上述方法仍然遇到权限问题：

1. **重新编译应用**：确保新的entitlements生效
2. **清理并重新构建**：`Product` → `Clean Build Folder`
3. **重启应用**：完全退出FastGit后重新启动
4. **检查仓库权限**：确保Git仓库文件有正确的读取权限

### 5. 开发模式解决方案

如果在开发过程中需要临时禁用沙盒限制：

1. 在项目设置中找到 `FastGit.entitlements`
2. 临时注释掉 `<key>com.apple.security.app-sandbox</key>` 条目
3. 重新编译运行

**注意**：发布版本必须保持沙盒启用状态以符合App Store要求。

### 6. 用户提示

建议在UI中添加用户提示：
- 如果检测到权限错误，显示友好的错误信息
- 指导用户重新通过文件选择器打开仓库
- 提供"重新选择仓库"的选项