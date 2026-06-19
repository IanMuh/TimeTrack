# TimeTrack

TimeTrack 是一个面向 Windows 和 Android 的离线优先时间记录应用。它以本地 SQLite 为核心，支持可选的 Supabase 云同步、Windows 或 Android 作为局域网主机的设备互通，以及文件导入/导出。

## 当前功能

- 维护一个"当前事项"，并在事项之间快速切换。
- 管理事项的新增、编辑、删除和颜色标识。
- 查看某一天的时间线覆盖情况和操作日志。
- 查看今日分布、本周累计和最长连续记录等统计信息。
- 配置提醒间隔，并处理长时间运行提醒和异常长记录。
- 通过 Supabase Email OTP 开启多设备云同步。
- 在 Windows 与 Android 之间通过局域网主机和配对码同步，手机之间也可以互通。
- 通过文件导入/导出在离线场景下交换数据。

## 环境要求

- [Flutter SDK](https://docs.flutter.dev/get-started/install) >= 3.4.0
- Windows: Visual Studio 2022（含"使用 C++ 的桌面开发"工作负载）或 [Build Tools for Visual Studio 2022](https://visualstudio.microsoft.com/downloads/#build-tools-for-visual-studio-2022)
- Android: [Android Studio](https://developer.android.com/studio) 并配置好 Android SDK 和模拟器/设备

验证环境：

```powershell
flutter doctor
```

确保至少一个平台（windows 或 android）状态为绿色勾。

## 运行

### 安装依赖

```powershell
flutter pub get
```

### 启动开发版本

```powershell
# Windows
flutter run -d windows

# Android（需连接设备或启动模拟器）
flutter run -d android
```

### 携带 Supabase 配置运行（可选）

仅在需要云同步时传入以下编译时定义：

```powershell
flutter run -d windows `
  --dart-define=SUPABASE_URL=https://your-project.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=your-anon-key
```

Android 下同理：

```powershell
flutter run -d android `
  --dart-define=SUPABASE_URL=https://your-project.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=your-anon-key
```

不传入这些定义时，应用以纯本地模式运行，无需任何外部依赖。

## 构建与安装

### 构建 Windows 可执行文件

```powershell
flutter build windows --release
```

构建产物位于 `build\windows\x64\runner\Release\`。将该目录整体拷贝即可分发运行，无需额外安装运行时。

若需要在构建时嵌入 Supabase 配置：

```powershell
flutter build windows --release `
  --dart-define=SUPABASE_URL=https://your-project.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=your-anon-key
```

### 构建 Android APK

```powershell
flutter build apk --release
```

产物位于 `build\app\outputs\flutter-apk\app-release.apk`。

构建 App Bundle（用于 Google Play）：

```powershell
flutter build appbundle --release
```

## 技术架构

| 目录 | 职责 |
|------|------|
| `lib/main.dart` | 应用入口，初始化数据库、同步服务和 UI 壳 |
| `lib/app` | 应用状态编排、提醒逻辑与同步触发 |
| `lib/core` | 通用工具：配置读取、日期扩展、Result 类型 |
| `lib/data` | SQLite 仓储、Supabase 同步、局域网同步、文件互通 |
| `lib/domain` | 事项、时间条目、设置和操作日志模型 |
| `lib/ui` | 自适应导航壳、首页、时间线、统计、登录和设置页面 |
| `test` | 领域、仓储、同步和布局测试 |
| `supabase/schema.sql` | Supabase 数据库结构定义 |

## 可选云同步

1. 创建 [Supabase](https://supabase.com) 项目。
2. 在 SQL Editor 中执行 `supabase/schema.sql`。
3. 在 Supabase Dashboard → Authentication → Providers 中启用 Email OTP。
4. 启动或构建应用时传入 `SUPABASE_URL` 和 `SUPABASE_ANON_KEY`。

未提供这些配置时，应用会继续以本地模式运行。

## 局域网互通

- Windows 端和 Android 端都可以开启局域网主机。
- 另一台设备可以使用主机地址和配对码连接并同步。
- 配对信息和同步目标会保存在本地。

## 静态分析与测试

```powershell
flutter analyze
flutter test
```
