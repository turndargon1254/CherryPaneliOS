# CherryPanel iOS App

Minecraft 服务器管理面板 iOS 原生应用，使用 SwiftUI + WidgetKit 开发。

## 功能特性

- **仪表盘** - 服务器状态、玩家数、TPS、CPU、内存、磁盘实时监控
- **控制台** - 实时日志流、命令输入、命令历史、搜索/暂停/下载
- **文件管理** - 浏览/上传/下载/删除/编辑、拖拽上传、面包屑导航
- **性能监控** - 实时图表、历史数据、详细统计
- **崩溃报告** - 崩溃记录、类型分布、详情查看、标记分析、设置配置
- **锁屏/桌面 Widget** - 显示服务器状态、玩家数、TPS
- **设置** - 服务器配置、账户安全、崩溃检测参数

## 技术栈

- **SwiftUI** - 声明式 UI
- **WidgetKit** - 锁屏/桌面小组件
- **Swift Concurrency** - async/await 网络请求
- **Combine** - 响应式状态管理
- **Charts** - 性能图表 (iOS 16+)

## 项目结构

```
iOS/
├── Package.swift                    # Swift Package Manager 配置
├── CherryPanel.xcodeproj/           # Xcode 项目
├── CherryPanel/                     # 主 App Target
│   ├── Info.plist
│   ├── CherryPanelApp.swift         # App 入口
│   ├── SceneDelegate.swift          # Scene 委托
│   ├── Models/
│   │   └── ServerModels.swift       # 数据模型
│   ├── Services/
│   │   └── APIService.swift         # API 网络层
│   ├── ViewModels/
│   │   └── AppViewModel.swift       # 全局状态管理
│   ├── Views/
│   │   ├── MainTabView.swift        # 主标签页
│   │   ├── DashboardView.swift      # 仪表盘
│   │   ├── ConsoleView.swift        # 控制台
│   │   ├── FilesView.swift          # 文件管理
│   │   ├── MetricsView.swift        # 性能监控
│   │   ├── CrashView.swift          # 崩溃报告
│   │   └── SettingsView.swift       # 设置
│   ├── ExportOptions.plist          # 打包配置
│   └── ExportOptions.plist
├── WidgetExtension/                 # Widget Extension Target
│   ├── Info.plist
│   └── ServerStatusWidget.swift     # Widget 实现
└── CherryPanel.xcodeproj/
    └── project.pbxproj
```

## 本地开发

### 环境要求
- macOS 14+
- Xcode 15.4+
- iOS 16+ 设备/模拟器

### 运行步骤

1. 打开项目
```bash
cd iOS
open CherryPanel.xcodeproj
```

2. 配置签名
- 在 Xcode 中选择 Target → Signing & Capabilities
- 选择你的 Team
- 启用 App Groups: `group.com.cherrypanel.app` (用于 Widget 数据共享)

3. 配置服务器地址
- 运行 App 后进入设置页面
- 输入服务器地址 (如: `http://your-server:22691`)
- 输入 API Key (如果后端启用了认证)

4. 运行
- 选择目标设备/模拟器
- Cmd+R 运行

## Widget 配置

1. 添加 Widget Extension Target
2. 启用 App Groups: `group.com.cherrypanel.app`
3. 在主 App 和 Widget 共享 `UserDefaults(suiteName: "group.com.cherrypanel.app")`

## GitHub Actions 自动构建

已配置 `.github/workflows/build-ios.yml`：
- macOS Runner 自动编译
- 输出 IPA 到 Artifacts
- Tag 触发自动创建 Release

### 配置 Secrets
在 GitHub 仓库 Settings → Secrets 添加：
- `TEAM_ID`: Apple Developer Team ID
- `APP_STORE_CONNECT_API_KEY` (可选): 用于 TestFlight 上传

## API 接口

App 使用与 Web 端相同的 REST API：

| 接口 | 方法 | 说明 |
|------|------|------|
| `/api/login` | POST | 登录 |
| `/api/check_session` | GET | 检查会话 |
| `/api/status` | GET | 服务器状态 |
| `/api/start/stop/restart` | POST | 服务器控制 |
| `/api/command` | POST | 发送命令 |
| `/api/metrics` | GET | 实时指标 |
| `/api/statistics` | GET | 统计信息 |
| `/api/logs` | SSE | 实时日志流 |
| `/api/files` | GET/POST | 文件管理 |
| `/api/crash/reports` | GET | 崩溃报告列表 |
| `/api/crash/stats` | GET | 崩溃统计 |

## 部署说明

### Ad-hoc 分发
```bash
xcodebuild -exportArchive \
  -archivePath ./build/CherryPanel.xcarchive \
  -exportPath ./build/ipa \
  -exportOptionsPlist ExportOptions.plist
```

`ExportOptions.plist` 中 `method: ad-hoc` 适合内部分发。

### TestFlight 上传
```bash
xcrun altool --upload-app \
  -f build/ipa/CherryPanel.ipa \
  -t ios \
  -u YOUR_APPLE_ID \
  -p YOUR_APP_SPECIFIC_PASSWORD
```

## 许可证

MIT License