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

若需要让内置更新检查读取其他 GitHub Releases API 地址，可额外传入 `UPDATE_RELEASES_URL`：

```powershell
flutter build windows --release `
  --dart-define=UPDATE_RELEASES_URL=https://api.github.com/repos/your-org/TimeTrack/releases
```

### 构建 Android APK

Release APK 默认可在没有签名配置时用 debug key 构建，方便本地验证；正式分发前必须配置自己的 keystore。

1. 复制 `android/key.properties.example` 为 `android/key.properties`。
2. 将 keystore 放在不会提交到仓库的位置，例如 `android/release/timetrack-release.jks`。
3. 填写 `storePassword`、`keyPassword`、`keyAlias` 和 `storeFile`。

`android/key.properties`、`*.jks` 和 `*.keystore` 已被忽略，不要提交真实密钥。

```powershell
flutter build apk --release
```

产物位于 `build\app\outputs\flutter-apk\app-release.apk`。

如需为 Android 构建嵌入同一个更新源，也可在构建命令中追加 `--dart-define=UPDATE_RELEASES_URL=...`。

构建 App Bundle（用于 Google Play）：

```powershell
flutter build appbundle --release
```

## 发布与更新检查

TimeTrack 的更新检查读取 GitHub Releases 列表。默认地址是 `https://api.github.com/repos/IanMuh/TimeTrack/releases`，可在运行或构建时通过 `--dart-define=UPDATE_RELEASES_URL=...` 覆盖。该值应指向 GitHub Releases API 的列表端点，而不是网页地址。

Release tag 使用语义化版本，预发布版建议命名为 `v0.2.0-pre`，也可使用不带 `v` 的 `0.2.0-pre`。应用会忽略 draft；稳定版构建不会提示预发布版更新，预发布版构建可以接收更新的预发布版。

Release assets 建议按平台命名，便于应用优先打开匹配平台的下载地址：

- Windows: 文件名包含 `windows`、`win` 或 `x64`，扩展名使用 `.zip`、`.msix` 或 `.exe`，例如 `TimeTrack-0.2.0-pre-windows-x64.zip`。
- Android: 文件名使用 `.apk`，建议包含 `android`，例如 `TimeTrack-0.2.0-pre-android.apk`。

如果某个 Release 没有匹配当前平台的 asset，应用会回退打开该 Release 的 GitHub 页面。更新功能只打开下载地址或 Release 页面，不会自动下载、自动安装或静默替换当前应用。

## 发布前检查

每次发布前至少确认：

```powershell
flutter analyze
flutter test
flutter build windows --release
flutter build apk --release
```

- Android 正式分发必须使用自己的 release keystore。
- Windows 产物位于 `build\windows\x64\runner\Release\`，分发时保持目录结构完整。
- 如需云同步，构建命令必须携带 `SUPABASE_URL` 和 `SUPABASE_ANON_KEY`。
- 如需自定义更新源，运行和发布构建命令必须携带正确的 `UPDATE_RELEASES_URL`。
- GitHub Release 的版本号、tag 和应用版本保持一致，例如 `0.2.0-pre` 对应 `v0.2.0-pre` 或 `0.2.0-pre`。
- 上传 Windows 与 Android 对应 assets，并确认文件名符合平台匹配规则。
- 确认更新入口只打开下载地址或 Release 页面，不承诺自动下载或自动安装。
- 不要提交 Supabase 密钥、Android keystore、本地 SQLite 数据库或 build 产物。

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
- 只在可信 Wi-Fi 下配对；不用时可在设置页移除配对并关闭主机。

## 安全与隐私

详见 `docs/security-privacy.md`。核心边界：

- 本地 SQLite 数据库不由 TimeTrack 加密，依赖系统账户、磁盘加密和设备锁屏保护。
- 导出的 `.timetrack.json` 是明文 JSON，可能包含事项、备注、时间戳和设备信息。
- 当前提醒是应用内提示，不是系统级后台通知；应用关闭、被系统挂起或后台受限时不保证触发。

## 静态分析与测试

```powershell
flutter analyze
flutter test
```
