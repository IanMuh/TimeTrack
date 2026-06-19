# Repository Guidelines

## Project Summary

TimeTrack 是一个面向 Windows 和 Android 的离线优先时间记录应用。它以本地 SQLite 为主，支持可选 Supabase 云同步、Windows 或 Android 作为局域网主机的设备互通，以及文件导入/导出。

## Architecture Overview

应用采用分层架构，自下而上为：

1. **Domain** — 纯 Dart 模型（Activity、TimeEntry、Setting、SyncLog），不依赖 Flutter。
2. **Data** — 数据访问层，封装 SQLite（本地仓储）、Supabase（云同步）、局域网 Socket 通信和文件序列化。
3. **App** — 应用状态管理层（`AppState`），横跨数据层和 UI 层，持有所有 Repository 和 Service 实例，暴露 `ChangeNotifier` 供 UI 响应。
4. **UI** — Flutter Widget 层，通过 `AnimatedBuilder` 监听 `AppState`，不直接访问数据层。

入口 `lib/main.dart` 负责依赖组装：根据是否有 Supabase 配置决定是否初始化 Supabase 客户端，然后将所有服务注入 `AppState`，最后 `runApp`。

## Code Layout

- `lib/main.dart`: 应用入口，初始化本地数据库、同步服务、局域网同步和界面壳。
- `lib/app`: 应用状态编排（`AppState`）、提醒逻辑和同步触发。
- `lib/core`: 通用工具 — 编译时配置读取（`AppConfig`）、日期时间扩展（`DateTimeExt`）、`Result` 类型。
- `lib/data`: SQLite（`LocalDatabase`、`TimeRepository`）、Supabase（`SyncService`）、局域网同步（`LanSyncServer`、`LanSyncClient`）、文件互通（`FileInteropService`）与持久化访问（`SyncPeerStore`）。
- `lib/domain`: 事项、时间条目、设置和操作日志模型。
- `lib/ui`: 自适应导航壳、首页、时间线、统计、登录和设置页面。
- `test`: 领域、仓储、同步和布局测试。
- `supabase/schema.sql`: Supabase 数据库结构定义。

## Key Patterns

- **离线优先**: 所有读写先落本地 SQLite。云同步和局域网同步是异步的、可选的，从不阻塞本地操作。
- **ChangeNotifier 驱动 UI**: `AppState` 继承 `ChangeNotifier`，数据变更时调用 `notifyListeners()`，UI 层通过 `AnimatedBuilder` 自动重建。
- **编译时配置**: Supabase 连接信息通过 `--dart-define` 传入，由 `AppConfig` 在运行时读取。未提供时，`AppConfig.hasSupabase` 为 `false`，应用完全离线运行。
- **局域网同步**: 基于原始 Socket 通信，使用 JSON 协议。主机端启动 `LanSyncServer` 监听端口，客户端通过 `LanSyncClient` 连接。配对码用于首次认证，后续由持久化的配对 ID 识别。
- **文件互通**: 支持 JSON 格式的导入/导出，作为无网络环境下的数据交换手段。

## Common Commands

- `flutter pub get`: 安装依赖。
- `flutter analyze`: 运行静态检查。
- `flutter test`: 运行测试。
- `flutter run -d windows`: 启动 Windows 端。
- `flutter run -d android`: 启动 Android 端。
- `flutter build windows --release`: 打包 Windows 发布版。
- `flutter build apk --release`: 打包 Android APK。

Supabase 可选配置：

```powershell
flutter run -d windows `
  --dart-define=SUPABASE_URL=https://your-project.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=your-anon-key
```

未提供这些定义时，应用必须继续以本地模式运行。

## Development Workflow

1. 在分支上开发，main 分支保持可发布状态。
2. 修改数据模型或仓储时，同步更新对应测试。
3. 提交前运行 `flutter analyze` 和 `flutter test`，确保通过。
4. 涉及 UI 变更时，在 Windows 和 Android 两个平台上验证布局（项目含自适应布局测试 `test/adaptive_layout_test.dart`）。

## Testing Guidelines

- 单元测试：领域模型和业务逻辑，位于 `test/`，命名以被测模块结尾（如 `time_entry_test.dart`）。
- 仓储测试：使用内存 SQLite 或临时文件数据库，不依赖 Supabase 连接。
- Widget 测试：关键 UI 组件（如 `activity_switch_button_test.dart`）。
- 同步测试：局域网和文件互通场景。

运行全部测试：

```powershell
flutter test
```

运行单个测试文件：

```powershell
flutter test test/time_entry_test.dart
```

## Platform-Specific Notes

### Windows

- 使用 `winsqlite3` 作为 SQLite 引擎（来自系统自带），详见 `pubspec.yaml` 中 `hooks.user_defines.sqlite3`。
- 发布构建需要在 `windows\runner\` 下配置版本号和图标。
- 局域网同步默认监听 `0.0.0.0`，Windows 防火墙可能需要放行对应端口。

### Android

- 使用 `sqlite3_flutter_libs` 内置的 SQLite。
- 局域网同步需要 `INTERNET` 权限（已在 AndroidManifest 中声明）。
- 最低 API 级别和 target SDK 在 `android\app\build.gradle.kts` 中配置。

## Working Rules

- 保持离线优先行为，不要把 Supabase 当作必需依赖。
- Windows 和 Android 都可以作为局域网主机，也都可以作为客户端连接。
- 修改数据、同步、布局或领域规则时，补充或更新测试。
- 不要提交 Supabase 地址、anon key、服务密钥或本地数据库文件。
- Dart 代码保持两空格缩进，并遵循 `prefer_single_quotes`。
