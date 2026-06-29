# TimeTrack v0.2.2

这是 TimeTrack 0.2.2 稳定版本，重点优化日常记录操作的响应速度，降低切换事项、停止、编辑、补记、撤销和重做后的卡顿。

## 优化内容

- SQLite schema 升级到 v9，新增运行中记录、时间范围查询、操作日志范围查询、活动和分类查找相关索引。
- 优化时间范围查询条件，避免 `coalesce(end_at, ?)` 阻碍索引使用。
- 将 `AppState.refresh()` 拆分为全量刷新和日常操作局部刷新，高频操作后只刷新当天 entries、logs 和 running entry。
- 为 undo/redo 增加 scoped snapshot，常见操作只比较受影响的数据范围。
- 为 activities、categories 和 category links 增加内存索引，减少重复线性扫描。
- 为统计页和时间线页增加基于范围与数据版本的 future 缓存，减少普通状态通知触发的重复查询。

## 下载资产

- `TimeTrack-0.2.2-windows-x64.zip`：Windows x64 便携包。
- `TimeTrack-0.2.2-android.apk`：Android APK。本地环境未提供 `android/key.properties`，因此该 APK 使用 debug key 签名；正式分发前请配置 release keystore 后重新构建。

## 验证

- `flutter analyze`
- `flutter test`
- `flutter build windows --release`
- `flutter build apk --release`
