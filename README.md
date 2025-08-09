# Launchpad - macOS 应用启动器

一个仿照 macOS 系统 Launchpad 的替代应用，专为 macOS 26+ 设计，因为苹果将在新版本中移除系统自带的 Launchpad 应用。

## 功能特性

### 🎯 核心功能
- **应用网格显示**: 美观的网格布局显示所有已安装的应用
- **智能搜索**: 实时搜索应用，支持模糊匹配
- **分类管理**: 按类别组织应用（系统、生产力、娱乐、开发、实用工具等）
- **拖拽重排**: 支持拖拽重新排列应用图标
- **一键启动**: 点击即可启动应用

### 🎨 界面设计
- **现代化UI**: 深色主题设计，符合 macOS 设计规范
- **流畅动画**: 平滑的悬停和点击动画效果
- **响应式布局**: 自适应不同屏幕尺寸
- **自定义网格**: 可调整网格列数（6-10列）

### ⚙️ 设置选项
- **网格配置**: 自定义网格列数
- **显示选项**: 显示/隐藏应用名称
- **动画控制**: 启用/禁用动画效果
- **自动刷新**: 自动检测新安装的应用
- **主题切换**: 深色/浅色模式

## 系统要求

- macOS 13.0 或更高版本
- Xcode 15.0 或更高版本（用于编译）
- Swift 5.9 或更高版本

## 安装方法

### 方法一：从源码编译

1. 克隆仓库：
```bash
git clone https://github.com/yourusername/launchpad.git
cd launchpad
```

2. 使用 Xcode 打开项目：
```bash
open Launchpad.xcodeproj
```

3. 选择目标设备（Mac）并点击运行按钮

### 方法二：下载预编译版本

从 [Releases](https://github.com/yourusername/launchpad/releases) 页面下载最新的 `.dmg` 文件。

## 使用方法

### 基本操作
1. **启动应用**: 双击 Launchpad 应用图标
2. **搜索应用**: 在顶部搜索栏输入应用名称
3. **分类浏览**: 点击顶部分类标签筛选应用
4. **启动应用**: 点击应用图标即可启动
5. **重新排列**: 拖拽应用图标到新位置

### 设置配置
1. 点击右上角的设置齿轮图标
2. 在设置面板中调整各种选项：
   - 网格列数
   - 显示选项
   - 动画设置
   - 自动刷新

## 技术架构

### 主要组件
- **ContentView**: 主界面视图
- **AppManager**: 应用管理和启动逻辑
- **DraggableAppGrid**: 支持拖拽的网格视图
- **SettingsView**: 设置界面
- **AppIconView**: 应用图标组件

### 核心技术
- **SwiftUI**: 现代化 UI 框架
- **AppKit**: macOS 系统集成
- **FileManager**: 文件系统访问
- **Bundle**: 应用信息读取
- **Process**: 应用启动

## 应用分类

系统会自动将应用分类到以下类别：

### 🖥️ 系统应用
- Safari, Mail, Messages, FaceTime
- Photos, Music, Calendar, Notes
- Maps, Weather, Calculator
- System Preferences, Finder

### 💼 生产力工具
- Microsoft Office 套件
- Google Chrome, Firefox
- Slack, Zoom, Teams
- Notion, Evernote, Trello

### 🎮 娱乐应用
- Spotify, Netflix, YouTube
- Steam, Discord, Twitch
- Instagram, Facebook, Twitter

### 💻 开发工具
- Xcode, Terminal
- Visual Studio, Android Studio
- IntelliJ, Sublime Text
- VS Code, Atom, Vim

### 🛠️ 实用工具
- 其他未分类的应用

## 权限说明

应用需要以下权限才能正常工作：

- **文件系统访问**: 扫描已安装的应用
- **应用启动权限**: 启动其他应用

## 故障排除

### 常见问题

**Q: 应用列表为空**
A: 检查是否有文件系统访问权限，尝试在设置中点击"刷新应用列表"

**Q: 无法启动某些应用**
A: 某些应用可能需要特殊权限，尝试手动启动一次

**Q: 搜索功能不工作**
A: 确保应用已完全加载，检查网络连接

**Q: 拖拽功能异常**
A: 尝试重启应用，确保 macOS 版本支持

### 日志查看
应用日志会输出到控制台，可以通过 Console.app 查看详细错误信息。

## 开发计划

### 即将推出
- [ ] 应用分组功能
- [ ] 自定义主题
- [ ] 快捷键支持
- [ ] 应用评分和评论
- [ ] 云端同步设置

### 长期计划
- [ ] 插件系统
- [ ] 应用更新检测
- [ ] 智能推荐
- [ ] 多语言支持

## 贡献指南

欢迎提交 Issue 和 Pull Request！

### 开发环境设置
1. Fork 项目
2. 创建功能分支
3. 提交更改
4. 推送到分支
5. 创建 Pull Request

### 代码规范
- 使用 Swift 官方代码规范
- 添加适当的注释
- 确保代码通过所有测试

## 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情。

## 致谢

- 感谢 Apple 提供的优秀开发工具
- 感谢 SwiftUI 社区的支持
- 感谢所有贡献者的帮助

## 联系方式

- GitHub: [@yourusername](https://github.com/yourusername)
- Email: your.email@example.com
- Twitter: [@yourusername](https://twitter.com/yourusername)

---

**注意**: 这是一个开源项目，不隶属于 Apple Inc.。Launchpad 是 Apple 的注册商标。 