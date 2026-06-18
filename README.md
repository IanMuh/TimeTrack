# TimeTrack

TimeTrack 是一个面向 Windows 和 Android 的离线优先时间记录应用。它以本地 SQLite 为核心，支持可选的 Supabase 云同步、Windows 或 Android 作为局域网主机的设备互通，以及文件导入/导出。

## 当前功能

- 维护一个“当前事项”，并在事项之间快速切换。
- 管理事项的新增、编辑、删除和颜色标识。
- 查看某一天的时间线覆盖情况和操作日志。
- 查看今日分布、本周累计和最长连续记录等统计信息。
- 配置提醒间隔，并处理长时间运行提醒和异常长记录。
- 通过 Supabase Email OTP 开启多设备云同步。
- 在 Windows 与 Android 之间通过局域网主机和配对码同步，手机之间也可以互通。
- 通过文件导入/导出在离线场景下交换数据。

## 技术与目录

- `lib/app`: 应用状态编排与同步协调。
- `lib/data`: SQLite、Supabase、局域网同步和文件互通。
- `lib/domain`: 事项、时间条目、设置和操作日志模型。
- `lib/ui`: 自适应壳、首页、时间线、统计、登录和设置页面。
- `test`: 领域、仓储、同步和布局测试。
- `supabase/schema.sql`: Supabase 数据库结构定义。

## 运行

```powershell
flutter pub get
flutter test
flutter run -d windows
flutter run -d android
```

## 可选云同步

1. 创建 Supabase 项目。
2. 执行 `supabase/schema.sql`。
3. 在 Supabase Auth 中启用 email OTP。
4. 启动应用时传入 `SUPABASE_URL` 和 `SUPABASE_ANON_KEY`。

未提供这些配置时，应用会继续以本地模式运行。

## 局域网互通

- Windows 端和 Android 端都可以开启局域网主机。
- 另一台设备可以使用主机地址和配对码连接并同步。
- 配对信息和同步目标会保存在本地。
