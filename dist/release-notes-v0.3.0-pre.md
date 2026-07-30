# TimeTrack v0.3.0-pre

这是 TimeTrack 0.3.0 预发布版本，重点是按新的视觉参考重做应用界面，并补齐时间线、统计、设置和应用壳层在桌面、紧凑窗口与 Android 上的响应式体验。

## 更新内容

- 重做整体浅色卡片视觉、蓝色选中态、青绿色运行计时栏和更清晰的页面层级。
- 拆分应用壳层、导航、底部运行栏、快捷历史操作、主题 token 和通用 UI 组件，降低大型 Widget 的维护成本。
- 重构首页当前状态、活动切换、快速操作、时间线、统计和设置页，使桌面与移动端布局更贴近参考图。
- 优化紧凑宽度下的统计时长、范围切换、排序控件、更新卡片和导入导出提示，减少文字溢出和底部固定栏遮挡。
- 新增英文和中文界面文案，文件导入导出结果不再写死中文提示。
- 增加应用壳层、主题、排序、Snackbar、互通提示、统计紧凑布局和底部避让相关回归测试。

## 下载资产

- `TimeTrack-0.3.0-pre-windows-x64.zip`：Windows x64 便携包。
- `TimeTrack-0.3.0-pre-android.apk`：Android APK。本地环境未提供 `android/key.properties` 时，该 APK 使用 debug key 签名；正式分发前请配置 release keystore 后重新构建。

## 验证

- `git diff --check`
- `flutter analyze`
- `flutter test`
- `flutter build windows --release`
- `flutter build apk --release`
- Windows exe 版本资源：`0.3.0-pre+6`
- Android APK：`versionName=0.3.0-pre`，`versionCode=6`
