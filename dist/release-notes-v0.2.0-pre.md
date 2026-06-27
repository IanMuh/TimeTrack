# TimeTrack v0.2.0-pre

这是 TimeTrack pre0.2 预发布版本，重点是新增应用内版本更新能力。该版本基于 `codex/pre-0.2` 分支的 `873803f` 发布。

## 新增内容

- 新增 GitHub Releases 更新检查，启动后异步检查，不阻塞本地离线加载。
- 设置页新增“版本更新”卡片，可查看当前版本、最新版本、检查状态和错误信息。
- 发现更新时只弹出一次非侵入 SnackBar，用户可跳转设置页手动打开下载页。
- 下载和安装均由用户手动完成；不会静默下载、不会自动安装。
- 新增 SemVer 版本解析和比较，支持 `v` 前缀、预发布版本和 build metadata。
- 更新服务会忽略 draft；稳定版不会提示预发布版；预发布版可接收更新的预发布版。
- Windows 优先选择 `.zip`、`.msix`、`.exe` 且文件名包含平台标识的资产；Android 优先选择 `.apk`。
- Release 页面和下载资产 URL 均要求 HTTPS，不接受自定义 scheme 或本地文件 URL。
- 不依赖 Supabase，不修改 SQLite 或 Supabase schema。

## 下载资产

- `TimeTrack-0.2.0-pre-windows-x64.zip`：Windows x64 便携包。
- `TimeTrack-0.2.0-pre-android.apk`：Android APK。本次本地环境未提供 `android/key.properties`，因此该 APK 使用 debug key 签名，适合作为预发布验证包；正式分发前请配置 release keystore 后重新构建。

## 验证

- `flutter analyze`
- `flutter test test/app_version_test.dart test/app_update_service_test.dart test/app_state_update_test.dart test/settings_update_card_test.dart test/app_shell_shortcuts_test.dart`
- `flutter build apk --release`
- `flutter build windows --release`
