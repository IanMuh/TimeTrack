# Repository Guidelines

## Project Summary

TimeTrack 是一个面向 Windows 和 Android 的离线优先时间记录应用。它以本地 SQLite 为主，支持可选 Supabase 云同步、Windows 或 Android 作为局域网主机的设备互通，以及文件导入/导出。

## Code Layout

- `lib/main.dart`: 应用入口，初始化本地数据库、同步服务、局域网同步和界面壳。
- `lib/app`: 应用状态编排、提醒逻辑和同步触发。
- `lib/data`: SQLite、Supabase、局域网同步、文件互通与持久化访问。
- `lib/domain`: 事项、时间条目、设置和操作日志模型。
- `lib/ui`: 自适应导航壳、首页、时间线、统计、登录和设置页面。
- `test`: 领域、仓储、同步和布局测试。
- `supabase/schema.sql`: Supabase 数据库结构定义。

## Common Commands

- `flutter pub get`: 安装依赖。
- `flutter analyze`: 运行静态检查。
- `flutter test`: 运行测试。
- `flutter run -d windows`: 启动 Windows 端。
- `flutter run -d android`: 启动 Android 端。
- `flutter build windows --release`: 打包 Windows 发布版。

Supabase 可选配置：

```powershell
flutter run -d windows `
  --dart-define=SUPABASE_URL=https://your-project.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=your-anon-key
```

未提供这些定义时，应用必须继续以本地模式运行。

## Working Rules

- 保持离线优先行为，不要把 Supabase 当作必需依赖。
- Windows 和 Android 都可以作为局域网主机，也都可以作为客户端连接。
- 修改数据、同步、布局或领域规则时，补充或更新测试。
- 不要提交 Supabase 地址、anon key、服务密钥或本地数据库文件。
- Dart 代码保持两空格缩进，并遵循 `prefer_single_quotes`。
