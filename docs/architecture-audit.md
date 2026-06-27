# TimeTrack 架构审查报告

日期：2026-06-23

分支：`codex/architecture-audit`

## 审查范围

本报告只记录当前项目架构、重复代码和功能冗余问题，不修改生产 Dart 代码，不调整数据库 schema，也不改变 Supabase、LAN 或文件互通协议。

重点检查范围：

- `lib/app` 应用状态编排
- `lib/data` 本地仓储、同步和互通服务
- `lib/ui` 主要页面与共享 UI 组件
- `test` 中的重复测试夹具

## 总体结论

当前代码已经完成了一轮大规模重构，但仍处在“拆分到一半”的状态：部分新状态类和接口已经出现，旧门面和旧职责仍保留在核心类里。最值得优先处理的是 `AppState` 未完成拆分、`TimeRepository` 兼容门面过厚、`timeline_page.dart` 继续承担过多 UI 与交互职责，以及测试/依赖注入样板重复。

这些问题暂时不一定造成运行错误，但会让后续功能修改成本变高，也容易出现同一行为在两个位置被修补、测试只覆盖其中一条路径的情况。

## 高风险维护问题

### 1. `AppState` 拆分未完成，存在未接入的重复状态类

现象：

- `ActivityState` 和 `EntryState` 已被 `AppState` 持有和转发。
- `ReminderState`、`SyncState`、`LanState` 已经实现，但没有被生产代码实例化或接入。
- 对应提醒、同步、LAN 状态逻辑仍保留在 `AppState` 内部。

证据：

- `lib/app/app_state.dart:38` 到 `lib/app/app_state.dart:53` 只创建了 `ActivityState` 和 `EntryState`。
- `lib/app/reminder_state.dart:7`、`lib/app/sync_state.dart:6`、`lib/app/lan_state.dart:8` 定义了三个独立状态类。
- `rg "ReminderState|SyncState|LanState" lib test` 显示这三个类除自身声明外没有生产使用点。
- `lib/app/app_state.dart:176` 到 `lib/app/app_state.dart:211` 仍内联提醒判断。
- `lib/app/app_state.dart:795` 到 `lib/app/app_state.dart:838` 仍内联同步流程。
- `lib/app/app_state.dart:844` 到 `lib/app/app_state.dart:886` 仍内联 LAN 主机/配对流程。

影响：

- 同一职责存在两个实现位置，后续修 bug 容易漏改。
- `AppState` 仍是跨 activity、entry、stats、undo、sync、LAN、file interop 的中心对象。
- 测试可能继续绑定 `AppState` 大对象，而不是验证更小状态单元。

建议：

- 优先二选一：要么把 `ReminderState`、`SyncState`、`LanState` 正式接入 `AppState`，要么删除这三个未使用类。
- 如果接入，先为当前 `AppState` 提醒、同步、LAN 行为补充 characterization tests，再做 GREEN-to-GREEN 迁移。
- 接入后让 `AppState` 只负责组合、转发和全局刷新，不再承载具体状态算法。

### 2. `TimeRepository` 仍是过厚兼容门面

现象：

- `TimeRepository` 已经拆出 `ActivityRepository`、`TimeEntryRepository`、`SettingsRepository`、`ActionLogRepository`。
- 但 `TimeRepository` 仍暴露大量同名业务方法，并把 `AppResult` unwrap 成异常。
- `AppState` 和服务层同时依赖 `TimeRepository` 与细分仓储，边界不够清晰。

证据：

- `lib/data/time_repository.dart:17` 到 `lib/data/time_repository.dart:20` 明确保留了旧类型 re-export。
- `lib/data/time_repository.dart:171` 到 `lib/data/time_repository.dart:604` 是大量 delegation / unwrap 逻辑。
- `lib/main.dart:40` 到 `lib/main.dart:79` 同时构造并传入 `TimeRepository`、`ActivityRepository`、`TimeEntryRepository` 等对象。
- `lib/data/sync_service.dart:161` 到 `lib/data/sync_service.dart:182` 中 `SupabaseSyncBackend` 同时接收门面和细分仓储。

影响：

- 调用方很难判断应该依赖门面还是接口仓储。
- 错误处理策略变成两套：仓储接口返回 `AppResult`，门面和 app 层继续抛 `StateError`。
- 后续删除或调整仓储方法时，需要维护兼容 re-export 和 unwrap 层。

建议：

- 把 `TimeRepository` 定义为明确的 orchestration facade，只保留跨仓储事务、同步 bundle、undo snapshot 等确实需要协调多仓储的行为。
- 单一仓储 CRUD/read 方法逐步从调用方迁移到 `IActivityRepository`、`ITimeEntryRepository`、`ISettingsRepository`、`IActionLogRepository`。
- 迁移完成后删除兼容 re-export，减少“旧入口”和“新入口”并存。

### 3. `timeline_page.dart` 是 UI God File

现象：

- `lib/ui/timeline_page.dart` 约 2746 行。
- 同一文件混合页面状态、范围加载、时间轴绘制、条目列表、日志列表、条目编辑弹窗、拆分/合并弹窗、活动选择器、默认时间计算和格式化函数。

证据：

- 文件行数：`wc -l lib/ui/timeline_page.dart` 显示约 2746 行。
- `TimelinePage` 页面状态在 `lib/ui/timeline_page.dart:104` 到 `lib/ui/timeline_page.dart:265`。
- 时间轴画布和布局在 `lib/ui/timeline_page.dart:762` 到 `lib/ui/timeline_page.dart:1258`。
- 条目/日志列表在 `lib/ui/timeline_page.dart:1260` 到 `lib/ui/timeline_page.dart:1609`。
- 条目编辑器在 `lib/ui/timeline_page.dart:1612` 到 `lib/ui/timeline_page.dart:2054`。
- 拆分/合并/扩展流程在 `lib/ui/timeline_page.dart:2057` 到 `lib/ui/timeline_page.dart:2368`。
- 活动选择器在 `lib/ui/timeline_page.dart:2417` 到 `lib/ui/timeline_page.dart:2704`。

影响：

- 任何 timeline 小改动都需要读一个超大文件，回归风险高。
- Widget 测试容易变成端到端大测试，而不是组件级测试。
- 与 `home_page.dart` 的活动创建/颜色选择弹窗存在共享机会但还未抽出。

建议：

- 先按职责拆成 timeline shell、timeline canvas、entry list、entry editor、activity selector、entry actions。
- 迁移前保留现有 `showEntryEditor` 等公开入口，避免一次性改动所有测试。
- 拆完后再评估 `ActivityColorPicker`、活动创建弹窗是否上移到共享组件。

## 中风险重复代码

### 4. 依赖注入参数重复，且存在未使用字段

现象：

多个服务构造函数接收门面和细分仓储，但实际只使用其中一部分，于是出现 `// ignore: unused_field`。

证据：

- `lib/data/file_interop_service.dart:31` 到 `lib/data/file_interop_service.dart:59` 接收 `IActivityRepository`、`ITimeEntryRepository`，但字段被 unused ignore。
- `lib/data/lan_sync.dart:23` 到 `lib/data/lan_sync.dart:45` 和 `lib/data/lan_sync.dart:258` 到 `lib/data/lan_sync.dart:277` 同样传入未使用仓储字段。
- `lib/data/sync_service.dart:161` 到 `lib/data/sync_service.dart:177` 中 `_repository` 被 unused ignore。

影响：

- 构造函数签名比实际需求更大，测试和 main 装配都被迫传入无用对象。
- 对后续维护者来说，依赖关系看起来比真实情况复杂。

建议：

- 先删除确认为未使用的构造参数和字段。
- 如果这些参数是为未来迁移保留，应改为接入实际逻辑，而不是用 ignore 隐藏。
- 清理后同步收敛 `main.dart` 和测试夹具构造代码。

### 5. 测试夹具重复搭建完整依赖图

现象：

多个测试文件重复创建内存数据库、各 Repository、`SyncService`、LAN 服务和 `AppState`。

证据：

- `test/time_repository_test.dart` 有 `buildRepositoryFixture()`。
- `test/app_state_reminder_test.dart`、`test/stats_page_test.dart`、`test/undo_redo_test.dart` 都有类似 `_buildState()` 或 fixture 构造。
- `test/timeline_page_test.dart` 同时存在 `_buildFixture()`、`_buildDelayedOverlapFixture()` 和 `_createAppState()` 等辅助构造。
- `test/file_interop_service_test.dart` 有 `buildFileInteropRepository()`。

影响：

- 构造签名一变，会引发多处测试机械更新。
- 不同测试 fixture 可能隐含不同默认配置，导致回归难定位。

建议：

- 新增 `test/support/test_app_factory.dart` 或类似文件，集中提供 `buildRepositoryFixture()`、`buildAppStateFixture()`、`buildSyncRepo()`。
- 先迁移新增测试，再逐步替换旧测试，避免一次性大改。

### 6. 统计与时间展示逻辑分散

现象：

统计区间、统计聚合和展示格式分布在 domain、app 和 ui 层。

证据：

- `lib/domain/stats_period.dart:3` 到 `lib/domain/stats_period.dart:32` 仍保留中文 label/title。
- `lib/app/app_state.dart:598` 到 `lib/app/app_state.dart:729` 包含统计聚合、最长块和窗口合计。
- `lib/app/app_state.dart:1031` 到 `lib/app/app_state.dart:1117` 定义 `TimeRangeStats`。
- `lib/ui/stats_page.dart:12` 到 `lib/ui/stats_page.dart:154` 定义 UI 专用 `StatsPreset` 和 `StatsRange`。
- `lib/ui/timeline_page.dart:2732` 到 `lib/ui/timeline_page.dart:2745` 定义 timeline 本地格式化函数，`lib/ui/ui_components.dart:305` 到 `lib/ui/ui_components.dart:310` 又有日期范围格式化。

影响：

- domain 层携带 UI 文案，和现有 l10n 方向不一致。
- 统计行为测试集中在 `AppState`，不利于把统计逻辑复用给其他页面或导出功能。
- 日期/时间格式散落，国际化和格式统一成本变高。

建议：

- 把 `TimeRangeStats` 和统计聚合抽到 domain 或 app service，例如 `lib/domain/time_range_stats.dart`。
- 保留 `StatsPeriod.windowFor()` 这类纯日期逻辑，移除 domain 层中文展示文案。
- 把日期/时间格式化集中到 UI helper 或 l10n formatter。

## 低风险清理项

### 7. Analyzer 当前只有测试中的 const 信息项

现象：

`flutter analyze` 当前返回 9 个 `prefer_const_constructors` info，集中在测试文件。

影响：

- 不影响运行，但会让分析命令非零退出，降低 CI 信噪比。

建议：

- 单独做一次测试文件 const 清理。
- 清理完成后把 `flutter analyze` 作为提交前硬门禁。

### 8. 部分 public helper 仍像迁移遗留

现象：

`TimeEntryRepository` 中存在 “Public helpers (not in interface)” 区域，供 `TimeRepository` 使用。

证据：

- `lib/data/time_entry_repository.dart:663` 到 `lib/data/time_entry_repository.dart:875`。

影响：

- 接口抽象和实际协作方法不一致。
- 未来替换 repository 实现时，`TimeRepository` 仍依赖具体类。

建议：

- 将真正需要跨仓储事务调用的 helper 放入明确的 internal interface，或收拢到协调服务。
- 不建议继续扩大 “not in interface” 区域。

## 建议修复顺序

1. 处理未接入状态类：接入或删除 `ReminderState`、`SyncState`、`LanState`，先消除重复职责。
2. 收敛依赖注入：删除实际未使用的构造参数和 `// ignore: unused_field`。
3. 抽出测试夹具工厂：先服务新的测试，再逐步迁移旧测试。
4. 明确 `TimeRepository` 边界：保留跨仓储协调，迁移单仓储调用到接口。
5. 拆分 `timeline_page.dart`：按 shell、canvas、list、editor、selector、actions 分阶段拆。
6. 清理统计/时间展示边界：把纯统计逻辑从 `AppState` 抽出，把 UI 文案交给 l10n。
7. 最后清理 analyzer info，让 `flutter analyze` 成为稳定门禁。

## 不建议现在做的事

- 不建议在同一个提交里同时拆 `AppState`、`TimeRepository` 和 `TimelinePage`。
- 不建议先删除 `TimeRepository` 门面；它仍承载 bundle merge、undo、跨仓储协调等职责。
- 不建议在架构清理中改 Supabase/LAN/文件互通协议。
- 不建议把状态管理库替换作为第一步；当前问题主要是边界和重复，不是 ChangeNotifier 本身。

## 验证记录

本报告分支只新增此文档文件。

- 已执行 `flutter analyze`：命令返回 exit code 1，原因是当前基线存在 9 个 `prefer_const_constructors` info；没有 error 或 warning。
- 9 个 info 均集中在测试文件：`test/adaptive_layout_test.dart` 和 `test/ui_controls_test.dart`。
- 无生产 Dart 文件变更。
