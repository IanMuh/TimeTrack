# TimeTrack 全量架构重构

## TL;DR

> **Quick Summary**: 对 TimeTrack Flutter 应用执行全面架构重构，覆盖 SQLite 性能优化、God Object 拆分、暗色模式/i18n 实现、代码质量清理，共 24 项改进，采用 TDD 方法，分 4 个并行 Wave 执行。
>
> **Deliverables**:
> - SQLite WAL 模式 + 外键约束 + 关键索引
> - 拆分后的 TimeRepository（5 文件）+ AppState（6 文件）+ 接口抽象
> - 暗色模式 (TimeTrackTheme.dark()) + i18n (.arb 文件, 272 字符串)
> - 同步分页 + 批量上传 + 重试逻辑
> - AppResult<T> 统一错误处理替代异常
> - actionType enum、模型 ==/hashCode、安全类型转换
> - 补充测试覆盖（登录页、弹窗、设置面板、LAN 安全）
>
> **Estimated Effort**: XL（约需 24 个任务，分 4 个 Wave 执行）
> **Parallel Execution**: YES - 4 waves，每 wave 5-7 个并行任务
> **Critical Path**: Wave 1 (基础) → Wave 2 (解耦) → Wave 3 (功能) → Wave 4 (清理)

---

## Context

### Original Request
用户要求为 TimeTrack 项目制定详细的重构计划，基于完整架构评审发现的 24 项改进，覆盖全部 4 个优先级梯队，采用 TDD 方法。

### Interview Summary
**Key Discussions**:
- 范围：全部 4 梯队 24 项（含 Metis 调整），不含新功能、不引入新状态管理库
- 测试：TDD 方法，结构性重构 GREEN→GREEN，新行为 RED→GREEN→REFACTOR
- 技术决策：保持 ChangeNotifier + 手动 DI，AppResult<T> 用于 Repository 接口替代异常
- 排序调整：i18n 放最后避免冲突，暗色模式在常量提取后，同步拆为 3 子项

**Research Findings**:
- 代码库 ~5000 行 Dart，3 个 God Object（TimeRepository 1723L, AppState 1091L, TimelinePage 2743L）
- 现有测试：15 文件，内存 SQLite + WidgetTester，覆盖核心路径
- SQLite 缺 key pragma（WAL, foreign_keys）+ 2 个关键索引
- 272 处硬编码中文字符串，有 intl 依赖但未使用
- `_readBool` 在 5 个文件中重复，魔法数字分散在 4+ 文件中

### Metis Review
**Identified Gaps** (addressed):
- Item 21 (StatsPeriod.month) → 误报，移除
- Item 22 (sqfliteFfiInit) → 已有惰性初始化，降为验证任务
- Item 10 暗色模式依赖 Item 13 常量 → 重排序
- Item 11 同步是 3 个独立子项 → 拆分
- Item 5+7 合并为原子操作 → 合并
- Item 17 AppResult 二元决策 → 决定使用，作为 Repository 接口的返回类型
- TDD 双轨 → GREEN→GREEN 用于结构重构，RED→GREEN 用于新行为

### Momus High-Accuracy Review
**Verdict**: **OKAY** — All 26+ file references verified. No blocking issues. Plan is executable.

---

## Work Objectives

### Core Objective
对 TimeTrack 代码库执行全面架构重构：拆分 God Object、修复 SQLite 性能瓶颈、实现暗色模式与 i18n、清理代码异味，采用 TDD 方法确保零行为退化。

### Concrete Deliverables
- SQLite: WAL + foreign_keys ON + 2 个新索引
- 拆分后代码: TimeRepository → 5 文件, AppState → 6 文件
- 新功能: 暗色模式, i18n (.arb), 同步分页/批量/重试
- 代码清理: enum actionType, 模型 ==/hashCode, 安全 fromMap, AppResult, 消除重复
- 测试: 新增登录页/弹窗/设置测试, LAN 安全测试

### Definition of Done
- [ ] `flutter analyze` 零错误零警告
- [ ] `flutter test` 全部通过（原有 15 + 新增测试）
- [ ] 所有 God Object 拆分为 ≤500 行文件
- [ ] 暗色模式下所有页面视觉正确
- [ ] i18n 支持中英文切换
- [ ] 同步分页 + 批量上传 + 重试生效

### Must Have
- 零行为退化（所有原有功能保持不变）
- SQLite WAL + foreign_keys 开启
- AppState + TimeRepository 拆分完成
- AppResult<T> 替代异常处理
- 暗色模式可用
- 补充测试覆盖

### Must NOT Have (Guardrails)
- 不引入新的状态管理库（get_it/riverpod/provider）
- 不更改数据库 schema 版本号或表结构
- 不修改 pubspec.yaml 中的功能性依赖（只 pin 版本 + 添加测试依赖）
- 不在重构中引入新功能特性
- 不删除任何现有测试
- 不使用 AI slop：无过度抽象、无无用文档、无过度注释

---

## Verification Strategy (MANDATORY)

> **ZERO HUMAN INTERVENTION** - ALL verification is agent-executed. No exceptions.

### Test Decision
- **Infrastructure exists**: YES
- **Automated tests**: TDD
- **Framework**: `flutter test` (WidgetTester + 内存 SQLite)
- **TDD approach**: GREEN→GREEN for structural refactors, RED→GREEN→REFACTOR for new behavior

### QA Policy
Every task MUST include agent-executed QA scenarios.
Evidence saved to `.omo/evidence/task-{N}-{scenario-slug}.{ext}`.

- **Frontend/UI**: Use Playwright (playwright skill) - Navigate, interact, assert DOM, screenshot
- **TUI/CLI**: Use Bash (flutter test, flutter analyze) - Run commands, validate output
- **API/Backend**: Use Bash (curl) - For sync-related verification
- **Library/Module**: Use Bash (dart/flutter REPL) - Import, call functions, compare output

---

## Execution Strategy

### Parallel Execution Waves

```
Wave 1 (Start Immediately - SQLite + 性能基础):
├── Task 1: PRAGMA foreign_keys=ON + WAL mode [quick]
├── Task 2: 添加数据库索引 + ensureSeedData 优化 [quick]
├── Task 3: 1秒定时器优化 → 单独 ValueNotifier [quick]
├── Task 4: app_shell IndexedStack 页面保活 [quick]
├── Task 5: 验证 sqfliteFfiInit + 提取公共代码 [quick]
└── Task 6: 提取魔法数字常量 + AppResult 激活 [quick]

Wave 2 (After Wave 1 - God Object 拆分):
├── Task 7: 拆分 TimeRepository → ActivityRepository [deep]
├── Task 8: 拆分 TimeRepository → TimeEntryRepository [deep]
├── Task 9: 拆分 TimeRepository → SettingsRepository + DeviceIdStore [deep]
├── Task 10: 拆分 AppState → ActivityState + EntryState [deep]
├── Task 11: 拆分 AppState → SyncState + LanState + ReminderState [deep]
├── Task 12: activityById Map 查找 + undo 快照优化 [deep]

Wave 3 (After Wave 2 - 暗色模式 + 同步修复):
├── Task 13: 暗色模式 TimeTrackTheme.dark() [visual-engineering]
├── Task 14: 同步分页 + 批量上传 + 重试 [unspecified-high]
├── Task 15: 登录页错误反馈 + LAN 配对频率限制 [quick]
├── Task 16: 补充测试: 登录页 + 提醒弹窗 + 设置面板 [quick]
├── Task 17: fromMap 安全类型转换 [quick]
└── Task 18: actionType → enum [quick]

Wave 4 (After Wave 3 - i18n + 收尾):
├── Task 19: i18n 基础设施 (.arb 文件 + AppLocalizations) [writing]
├── Task 20: i18n 迁移所有 UI 字符串 (272 strings) [writing]
├── Task 21: 领域模型 ==/hashCode + intl 版本固定 [quick]
├── Task 22: 最终集成验证 + 清理 [deep]
└── Task 23: removed

Wave FINAL (After ALL tasks):
├── Task F1: Plan Compliance Audit (oracle)
├── Task F2: Code Quality Review (unspecified-high)
├── Task F3: Real Manual QA (unspecified-high + playwright)
└── Task F4: Scope Fidelity Check (deep)
-> 呈现结果 → 等待用户明确"okay"
```

### Dependency Matrix

- **1-6**: - - 7-12, 1
- **7**: 5,6 - 10-12, 2
- **10**: 7,8,9 - 13,2
- **13**: 6 - 19,3
- **14**: 7,8 - 3
- **19**: 18 - 22,4
- **22**: all - F1-F4, FINAL

### Agent Dispatch Summary

- **Wave 1**: 6 tasks → `quick`
- **Wave 2**: 6 tasks → `deep`
- **Wave 3**: 6 tasks → mixed (`visual-engineering`, `unspecified-high`, `quick`)
- **Wave 4**: 5 tasks → mixed (`writing`, `quick`, `deep`)
- **FINAL**: 4 tasks → `oracle`, `unspecified-high`, `deep`

---

## TODOs

- [ ] 1. PRAGMA foreign_keys=ON + WAL mode + 数据库初始化安全化

  **What to do**:
  - 在 `local_database.dart` 的 `_create()` 和每次连接时执行 `PRAGMA foreign_keys = ON`
  - 执行 `PRAGMA journal_mode=WAL` 启用 WAL 模式，解决并发写入冲突
  - 修复 `_database` 赋值时序：先 `await openDatabase` 再赋值，避免部分初始化对象
  - 编写测试验证 foreign_keys 约束生效（插入无效 activity_id 应报错）
  - 编写测试验证 WAL 模式下并发读写不冲突

  **Must NOT do**:
  - 不修改任何现有查询或迁移逻辑
  - 不改变数据库文件路径

  **TDD Approach**: GREEN→GREEN（结构性改动，现有测试必须持续通过）

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: 集中修改 `local_database.dart`，改动量小但影响面广
  - **Skills**: [`data-sql-optimization`]
    - `data-sql-optimization`: SQLite pragma 配置和 WAL 模式最佳实践

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 2, 3, 4, 5, 6)
  - **Blocks**: 7, 8, 9
  - **Blocked By**: None

  **References**:
  - `lib/data/local_database.dart:22-31` - 当前数据库打开逻辑（需修复赋值时序）
  - `lib/data/local_database.dart:58-114` - `createSchema()` 中表定义（含 foreign key 声明）
  - `test/time_repository_test.dart` - 仓储测试模式（内存数据库 + 事务）

  **Acceptance Criteria**:
  - [ ] `PRAGMA foreign_keys` 在连接后返回 1（ON）
  - [ ] `PRAGMA journal_mode` 返回 `wal`
  - [ ] `_database` 赋值不会留下部分初始化对象
  - [ ] 插入无效 activity_id 的 time_entry 被拒绝

  **QA Scenarios**:

  ```
  Scenario: foreign_keys 约束强制执行
    Tool: Bash (flutter test)
    Preconditions: 新数据库连接
    Steps:
      1. 打开数据库，执行 PRAGMA foreign_keys = ON
      2. 尝试插入 activity_id='nonexistent' 的 time_entry
      3. 捕获异常
    Expected Result: 抛出 SQLite constraint violation 异常
    Evidence: .omo/evidence/task-1-fk-constraint.txt

  Scenario: WAL 模式并发写入
    Tool: Bash (flutter test)
    Preconditions: WAL 模式已启用
    Steps:
      1. 第一个连接开始写入事务（不提交）
      2. 第二个连接尝试写入
    Expected Result: 第二个连接不阻塞（WAL 允许并发读写）
    Failure Indicators: "database is locked" 错误
    Evidence: .omo/evidence/task-1-wal-concurrent.txt
  ```

  **Commit**: YES
  - Message: `refactor(wave1): enable SQLite foreign_keys and WAL mode`
  - Files: `lib/data/local_database.dart`
  - Pre-commit: `flutter analyze && flutter test`

- [ ] 2. 添加数据库关键索引 + ensureSeedData 优化

  **What to do**:
  - 在 `local_database.dart` 添加索引: `idx_activities_updated_at`、`idx_time_entries_activity_id`
  - 在 `time_repository.dart` 的 `ensureSeedData()` 中：添加 `app_metadata` 标记 `seeded=1`，跳过已完成的初始化
  - 编写迁移测试验证索引存在
  - 编写测试验证 seed 跳过逻辑正确

  **Must NOT do**:
  - 不删除已有索引
  - 不修改 seed 数据的业务逻辑

  **TDD Approach**: GREEN→GREEN（现有测试必须通过）

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: [`data-sql-optimization`]

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 1, 3, 4, 5, 6)
  - **Blocks**: 7, 8, 9
  - **Blocked By**: None

  **References**:
  - `lib/data/local_database.dart:104-114` - 现有索引定义模式
  - `lib/data/time_repository.dart:55-116` - ensureSeedData 完整逻辑
  - `lib/data/local_database.dart:157-164` - app_metadata 表结构

  **Acceptance Criteria**:
  - [ ] `idx_activities_updated_at` 索引存在于 SQLite
  - [ ] `idx_time_entries_activity_id` 索引存在于 SQLite
  - [ ] `seeded=1` 标记后第二次调用 ensureSeedData 直接返回
  - [ ] 有索引后 `activitiesSince()` 查询计划使用索引

  **QA Scenarios**:

  ```
  Scenario: 第二次启动跳过种子初始化
    Tool: Bash (flutter test)
    Preconditions: 已执行过 ensureSeedData
    Steps:
      1. 创建 TimeRepository + 内存数据库
      2. 调用 ensureSeedData()
      3. 检查 app_metadata 中 seeded 标记
      4. 再次调用 ensureSeedData()
      5. 验证未重复创建活动
    Expected Result: 活动数量不变，seeded=1
    Evidence: .omo/evidence/task-2-seed-skip.txt
  ```

  **Commit**: YES
  - Message: `refactor(wave1): add sync indexes and optimize seed data check`
  - Files: `lib/data/local_database.dart`, `lib/data/time_repository.dart`
  - Pre-commit: `flutter analyze && flutter test`

- [ ] 3. 1秒定时器优化 → `ValueNotifier<DateTime>` 单独通知

  **What to do**:
  - 在 `AppState` 中新增 `ValueNotifier<DateTime> clockNotifier` 替代全局 `notifyListeners()`
  - 修改 `_ticker` 回调：仅更新 `clockNotifier.value = DateTime.now()`，不触发全量 notify
  - 修改 UI 中显示运行时长的地方（`CurrentStatusCard`），使用 `ValueListenableBuilder` 监听 `clockNotifier`
  - 编写 Widget 测试验证运行时长每秒更新但不触发全量重建

  **Must NOT do**:
  - 不改变 `_rolloverRunningEntryIfNeeded()` 的调用时机
  - 不改变提醒逻辑

  **TDD Approach**: RED→GREEN→REFACTOR（新行为：分离时钟通知）

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: 集中在 AppState + 1-2 个 UI 组件的修改

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 1, 2, 4, 5, 6)
  - **Blocks**: 10, 11
  - **Blocked By**: None

  **References**:
  - `lib/app/app_state.dart:154-158` - 当前 1 秒定时器代码
  - `lib/ui/home_page.dart:70-73` - CurrentStatusCard 使用 runningDuration
  - `lib/ui/app_shell.dart:91` - 提醒弹窗中使用 runningDuration

  **Acceptance Criteria**:
  - [ ] `clockNotifier` 每秒更新，全局 `notifyListeners()` 不再每秒触发
  - [ ] 运行时长显示仍然每秒刷新
  - [ ] `_rolloverRunningEntryIfNeeded` 仍然在定时器中调用
  - [ ] Widget 测试验证 rebuild 次数显著减少

  **QA Scenarios**:

  ```
  Scenario: 运行时长每秒更新但不触发全量重建
    Tool: Bash (flutter test)
    Preconditions: 有一个运行中的时间条目
    Steps:
      1. 启动 app，切换到某个事项
      2. 验证 CurrentStatusCard 中时长每秒变化
      3. 验证首页其他 Widget 不每秒重建（用测试中的 rebuild 计数）
    Expected Result: 时长更新，其余组件无额外重建
    Evidence: .omo/evidence/task-3-clock-notifier.txt
  ```

  **Commit**: YES
  - Message: `refactor(wave1): extract clock to ValueNotifier, reduce rebuilds`
  - Files: `lib/app/app_state.dart`, `lib/ui/home_page.dart`, `lib/ui/app_shell.dart`
  - Pre-commit: `flutter analyze && flutter test`

- [ ] 4. app_shell 页面状态修复 → `IndexedStack` 保活

  **What to do**:
  - 将 `app_shell.dart:140-145` 的页面列表创建改为 `initState` 中一次性初始化
  - 使用 `IndexedStack` 包裹页面列表，保持所有 `StatefulWidget` 的状态
  - 修复 `TimelinePageController` 可能因页面重建而丢失的问题
  - 编写测试验证页面切换后状态保持（如: 切换到时间线，滚动位置不丢失）

  **Must NOT do**:
  - 不改变导航栏外观或交互行为
  - 不改变键盘快捷键行为

  **TDD Approach**: GREEN→GREEN（Behavior-preserving 修复）

  **Recommended Agent Profile**:
  - **Category**: `quick`

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 1, 2, 3, 5, 6)
  - **Blocks**: 10, 11
  - **Blocked By**: None

  **References**:
  - `lib/ui/app_shell.dart:140-145` - 当前页面重建逻辑
  - `lib/ui/app_shell.dart:25-30` - State 类定义（_index, _timelineController）
  - `test/app_shell_shortcuts_test.dart` - 快捷键测试（作为回归验证）

  **Acceptance Criteria**:
  - [ ] 页面切换后 `StatefulWidget` 状态保持
  - [ ] `IndexedStack` 正确包裹页面列表
  - [ ] 原有导航测试全部通过
  - [ ] `TimelinePageController` 不因页面切换丢失

  **QA Scenarios**:

  ```
  Scenario: 页面状态在切换后保持
    Tool: Bash (flutter test)
    Preconditions: 应用启动，有多个页面
    Steps:
      1. 导航到时间线页面
      2. 滚动到某个位置（或选中某天）
      3. 切换到统计页面
      4. 切换回时间线页面
      5. 验证之前的位置/选择保持不变
    Expected Result: 时间线页面状态完整保留
    Failure Indicators: 页面重置到初始状态
    Evidence: .omo/evidence/task-4-indexed-stack.txt
  ```

  **Commit**: YES
  - Message: `refactor(wave1): use IndexedStack to preserve page state`
  - Files: `lib/ui/app_shell.dart`
  - Pre-commit: `flutter analyze && flutter test`

- [ ] 5. 验证 sqfliteFfiInit 惰性初始化 + 消除 _readBool 重复 + _dialogContentWidth 统一

  **What to do**:
  - 验证 `local_database.dart:17-19` 的 `sqfliteFfiInit()` 是否已有内置惰性初始化保护
  - 如确认为 idempotent：保持不变；否则添加 `_ffiInitialized` 静态标记
  - 提取 `_readBool` 到 `lib/core/model_utils.dart`，从 Activity、TimeEntry、ActionLog、TimeRepository 中移除重复定义
  - 提取 `_dialogContentWidth` 到 `lib/ui/ui_components.dart`，从 home_page 和 timeline_page 中移除重复
  - 编写测试验证 _readBool 统一行为一致

  **Must NOT do**:
  - 不改变 _readBool 的解析逻辑
  - 不改变对话框宽度行为

  **TDD Approach**: GREEN→GREEN（纯提取重复代码）

  **Recommended Agent Profile**:
  - **Category**: `quick`

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 1, 2, 3, 4, 6)
  - **Blocks**: 6, 7
  - **Blocked By**: None

  **References**:
  - `lib/domain/activity.dart:90-98` - _readBool 定义
  - `lib/domain/time_entry.dart:149-157` - 第 2 份 _readBool
  - `lib/domain/action_log.dart:97-105` - 第 3 份 _readBool
  - `lib/data/time_repository.dart:1674-1682` - 第 4 份 _readBool
  - `lib/ui/home_page.dart:688` - _dialogContentWidth
  - `lib/ui/timeline_page.dart:2694` - 重复的 _dialogContentWidth

  **Acceptance Criteria**:
  - [ ] `lib/core/model_utils.dart` 包含单一 `readBool` 函数
  - [ ] 所有 4 个文件导入并使用 `model_utils.dart` 的 `readBool`
  - [ ] 所有现有测试通过
  - [ ] `lib/ui/ui_components.dart` 包含 `dialogContentWidth(context)` 函数
  - [ ] home_page 和 timeline_page 使用统一函数

  **QA Scenarios**:

  ```
  Scenario: _readBool 统一后行为等价
    Tool: Bash (flutter test)
    Preconditions: 所有 _readBool 替换为统一版本
    Steps:
      1. 运行全部现有测试
      2. 验证 fromMap 解析 bool/整数 行为与原来一致
    Expected Result: 全部测试通过
    Evidence: .omo/evidence/task-5-readbool-unified.txt
  ```

  **Commit**: YES
  - Message: `refactor(wave1): extract _readBool and _dialogContentWidth to shared utils`
  - Files: `lib/core/model_utils.dart` (new), `lib/domain/*.dart`, `lib/data/time_repository.dart`, `lib/ui/*.dart`
  - Pre-commit: `flutter analyze && flutter test`

- [ ] 6. 提取魔法数字常量 + AppResult<T> 激活使用

  **What to do**:
  - 创建 `lib/core/app_constants.dart`，集中定义:
    - `defaultActivityColor = 0xff64748b`（从 4 处移除重复）
    - `farFutureDate = DateTime(2100)`（替代 `DateTime(9999)` 和 `DateTime.fromMillisecondsSinceEpoch(8640000000000000)`）
    - `suspiciousEntryHours = 12`
    - `defaultReminderMinutes = 45` 等
  - 修改 `AppResult<T>`（`lib/core/result.dart`）：添加 `fold()`/`when()` 方法
  - 在 `TimeRepository` 接口草案中定义返回类型为 `AppResult<T>`
  - 编写测试验证 `AppResult` 的 fold/when 行为

  **Must NOT do**:
  - 不在本任务中全面应用 AppResult（由 Wave 2 的 Repository 拆分任务完成）
  - 不改变颜色或数值的语义

  **TDD Approach**: RED→GREEN（添加 AppResult 方法是新行为）

  **Recommended Agent Profile**:
  - **Category**: `quick`

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 1, 2, 3, 4, 5)
  - **Blocks**: 7, 8, 9, 13
  - **Blocked By**: 5

  **References**:
  - `lib/core/result.dart:1-15` - AppResult 当前定义（死代码）
  - `lib/app/app_state.dart:332` - 默认颜色 0xff64748b
  - `lib/ui/timeline_page.dart:1544` - 重复颜色值
  - `lib/ui/stats_page.dart:507` - 重复颜色值
  - `lib/data/time_repository.dart:61-62` - DateTime 哨兵值

  **Acceptance Criteria**:
  - [ ] `lib/core/app_constants.dart` 包含所有魔法数字常量
  - [ ] 4 处颜色引用统一使用 `AppConstants.defaultActivityColor`
  - [ ] `AppResult<T>` 支持 `fold(onSuccess:, onFailure:)` 模式匹配
  - [ ] 现有测试通过（常量值语义不变）

  **QA Scenarios**:

  ```
  Scenario: AppResult fold 正确分发
    Tool: Bash (dart test)
    Preconditions: AppResult 已添加 fold 方法
    Steps:
      1. 创建 AppSuccess(42)
      2. 调用 fold(onSuccess: (v) => v*2, onFailure: (_) => 0)
      3. 断言结果为 84
    Expected Result: fold 正确分发到 onSuccess 分支
    Evidence: .omo/evidence/task-6-appresult-fold.txt
  ```

  **Commit**: YES
  - Message: `refactor(wave1): extract magic numbers, activate AppResult<T> with fold`
  - Files: `lib/core/app_constants.dart` (new), `lib/core/result.dart`, `lib/app/app_state.dart`, `lib/ui/*.dart`, `lib/data/time_repository.dart`
  - Pre-commit: `flutter analyze && flutter test`

- [ ] 7. 定义 Repository 接口 + 拆分 ActivityRepository

  **What to do**:
  - 创建 `lib/data/repository_interfaces.dart`：定义 `IActivityRepository` 抽象接口（方法签名 + `AppResult<T>` 返回类型）
  - 从 `time_repository.dart` 提取 Activity 相关方法到新文件 `lib/data/activity_repository.dart`
  - 实现 `IActivityRepository`，所有返回类型改为 `AppResult<T>`
  - 修改所有调用方（AppState, SyncService, LanSync）使用接口类型
  - 运行全部测试确保零回归

  **Must NOT do**:
  - 不修改 Activity 方法的业务逻辑
  - 不移动 Entry/Settings/DeviceId 相关方法

  **TDD Approach**: GREEN→GREEN（行为保持，仅重组）

  **Recommended Agent Profile**:
  - **Category**: `deep`
    - Reason: 需理解所有调用方，确保接口设计正确，影响面广

  **Parallelization**:
  - **Can Run In Parallel**: NO（与 Task 8 有文件冲突，先完成 7 再并行 8+9）
  - **Parallel Group**: Wave 2 (after Task 7, parallel 8+9)
  - **Blocks**: 8, 9, 10, 12
  - **Blocked By**: 1, 2, 5, 6

  **References**:
  - `lib/data/time_repository.dart:54-116` - ensureSeedData / seed activities
  - `lib/data/time_repository.dart:118-126, 128-140` - activities/oneOffActivities 查询
  - `lib/data/time_repository.dart:237-316` - CRUD (upsert/create/update/delete/restore)
  - `lib/data/time_repository.dart:762-771, 897-911` - sync 相关
  - `lib/data/time_repository.dart:1507-1583` - _ensureUnassigned / _startUnassigned
  - `lib/app/app_state.dart:458-551` - AppState 调用点
  - `lib/data/sync_service.dart` - SyncService 调用点

  **Acceptance Criteria**:
  - [ ] `IActivityRepository` 接口包含完整方法签名，返回 `AppResult<T>`
  - [ ] `ActivityRepository` 实现接口
  - [ ] AppState/SyncService/LanSync 通过接口调用
  - [ ] 全部现有测试通过

  **QA Scenarios**:
  ```
  Scenario: Repository 拆分后 CRUD 完整
    Tool: Bash (flutter test)
    Preconditions: ActivityRepository 已提取
    Steps:
      1. 运行 test/time_repository_test.dart 中 Activity 相关测试
      2. 运行 test/undo_redo_test.dart 中 Activity 撤销测试
      3. 验证所有测试通过
    Expected Result: 全部 Activity 相关测试通过
    Evidence: .omo/evidence/task-7-activity-repo.txt
  ```

  **Commit**: YES
  - Message: `refactor(wave2): extract IActivityRepository and ActivityRepository`
  - Files: `lib/data/repository_interfaces.dart` (new), `lib/data/activity_repository.dart` (new), `lib/data/time_repository.dart`, `lib/app/app_state.dart`, `lib/data/sync_service.dart`, `lib/data/lan_sync.dart`
  - Pre-commit: `flutter analyze && flutter test`

- [ ] 8. 拆分 TimeEntryRepository + ActionLogRepository

  **What to do**:
  - 提取 TimeEntry 方法到 `lib/data/time_entry_repository.dart`（CRUD, 查询, 合并, 切割, 重叠, 跨日, rollover）
  - 提取 ActionLog 方法到 `lib/data/action_log_repository.dart`
  - 在接口文件中定义 `ITimeEntryRepository`、`IActionLogRepository`
  - 事务内跨方法调用正确传递 `DatabaseExecutor`
  - 修改所有调用方使用接口类型

  **Must NOT do**:
  - 不改变 Entry 合并/切割/重叠的业务逻辑
  - 不更改事务边界

  **TDD Approach**: GREEN→GREEN

  **Recommended Agent Profile**:
  - **Category**: `deep`
    - Reason: TimeEntryRepository 是最复杂的拆分（~800 行 + 复杂事务逻辑）

  **Parallelization**:
  - **Can Run In Parallel**: YES（与 Task 9 并行）
  - **Parallel Group**: Wave 2 (after Task 7, parallel with Task 9)
  - **Blocks**: 10, 12, 14, 15
  - **Blocked By**: 7

  **References**:
  - `lib/data/time_repository.dart:318-558` - TimeEntry CRUD + switchTo + split + merge
  - `lib/data/time_repository.dart:720-760` - addActionLog / replaceActionLogIfRemoteNewer
  - `lib/data/time_repository.dart:860-868, 988-1079` - overlaps, normalize/rollover
  - `lib/data/time_repository.dart:1281-1722` - 内部辅助方法

  **Acceptance Criteria**:
  - [ ] `ITimeEntryRepository` 和 `IActionLogRepository` 接口完整
  - [ ] 所有方法通过 `AppResult` 返回
  - [ ] 事务内跨方法调用正确（`DatabaseExecutor` 传递）
  - [ ] 全部测试通过

  **QA Scenarios**:
  ```
  Scenario: Entry 拆分/合并/重叠逻辑正确
    Tool: Bash (flutter test)
    Preconditions: TimeEntryRepository 已提取
    Steps:
      1. 运行 test/time_repository_test.dart 全部
      2. 运行 test/timeline_page_test.dart 全部
      3. 运行 test/undo_redo_test.dart 全部
    Expected Result: 全部通过
    Evidence: .omo/evidence/task-8-entry-repo.txt
  ```

  **Commit**: YES
  - Message: `refactor(wave2): extract TimeEntryRepository and ActionLogRepository`
  - Files: `lib/data/time_entry_repository.dart` (new), `lib/data/action_log_repository.dart` (new), `lib/data/repository_interfaces.dart`, `lib/data/time_repository.dart`, 所有调用方
  - Pre-commit: `flutter analyze && flutter test`

- [ ] 9. 拆分 SettingsRepository + DeviceIdStore + 收尾 TimeRepository

  **What to do**:
  - 提取 Settings 方法到 `lib/data/settings_repository.dart`（`ISettingsRepository`）
  - 提取 DeviceId 管理到 `lib/data/device_id_store.dart`（`IDeviceIdStore`）
  - 提取同步包合并逻辑到 `lib/data/sync_bundle_merger.dart`
  - 原 `time_repository.dart` 缩减为薄协调层（<50 行）或完全删除
  - 更新 `main.dart` 依赖注入，创建各 repository 实例并注入接口
  - 更新 `AppState` 构造函数接收拆分后的接口

  **Must NOT do**:
  - 不改变任何方法实现逻辑
  - 不改变 main.dart 初始化顺序

  **TDD Approach**: GREEN→GREEN

  **Recommended Agent Profile**:
  - **Category**: `deep`

  **Parallelization**:
  - **Can Run In Parallel**: YES（与 Task 8 并行）
  - **Parallel Group**: Wave 2 (after Task 7, parallel with Task 8)
  - **Blocks**: 10, 11
  - **Blocked By**: 7

  **References**:
  - `lib/data/time_repository.dart:870-895` - settings/saveSettings/replaceSettings
  - `lib/data/time_repository.dart:929-962` - currentDeviceId
  - `lib/data/time_repository.dart:160-235` - mergeBundle + _shouldReplace
  - `lib/main.dart:28-47` - 当前依赖组装

  **Acceptance Criteria**:
  - [ ] Settings/DeviceId/SyncBundleMerger 已拆分到独立文件
  - [ ] 原 `time_repository.dart` 已删除或仅剩协调层
  - [ ] `main.dart` 依赖组装更新
  - [ ] 全部测试通过

  **QA Scenarios**:
  ```
  Scenario: 拆分后完整初始化流程正常
    Tool: Bash (flutter test)
    Preconditions: 所有 Repository 已拆分
    Steps:
      1. 运行全部现有测试
      2. 验证 AppState 正确接收拆分后的接口
      3. 验证同步和导入/导出功能正常
    Expected Result: 全部测试通过，功能完整
    Evidence: .omo/evidence/task-9-settings-deviceid.txt
  ```

  **Commit**: YES
  - Message: `refactor(wave2): extract SettingsRepository, DeviceIdStore, finalize Repository split`
  - Files: `lib/data/settings_repository.dart` (new), `lib/data/device_id_store.dart` (new), `lib/data/sync_bundle_merger.dart` (new), `lib/main.dart`, `lib/app/app_state.dart`
  - Pre-commit: `flutter analyze && flutter test`

- [ ] 10. 拆分 AppState → ActivityState + EntryState

  **What to do**:
  - 创建 `lib/app/activity_state.dart`：提取 `activities`、`runningActivity`、`activityById`、`switchTo`、`stopCurrent`、`createActivity`、`updateActivity`、`deleteActivity` 等
  - 创建 `lib/app/entry_state.dart`：提取 `dayEntries`、`runningEntry`、`saveEntry`、`splitEntry`、`deleteEntry`、`extendEntryToNow`、`createManualEntry` 等
  - ActivityState 和 EntryState 各自继承 `ChangeNotifier`
  - 修改 AppState 使其组合（composition）而非继承上述逻辑
  - 编写测试验证拆分后的行为等价

  **Must NOT do**:
  - 不改变方法的业务逻辑
  - 不改变 UI 调用方式（通过 AppState 的属性代理访问）

  **TDD Approach**: GREEN→GREEN

  **Recommended Agent Profile**:
  - **Category**: `deep`
    - Reason: AppState 拆分涉及 ~500 行代码迁移，需保持 ChangeNotifier 通知链正确

  **Parallelization**:
  - **Can Run In Parallel**: YES（与 Task 11 配合）
  - **Parallel Group**: Wave 2 (after Task 9, parallel with Tasks 11, 12)
  - **Blocks**: 13
  - **Blocked By**: 7, 8, 9

  **References**:
  - `lib/app/app_state.dart:44-98` - Activity/Entry 相关属性
  - `lib/app/app_state.dart:100-143` - runningActivity/runningDuration/reminder getters
  - `lib/app/app_state.dart:311-553` - Activity 相关方法（activityById→deleteActivity）
  - `lib/app/app_state.dart:380-465` - Entry 相关方法（correctSuspicious→createManualEntry）
  - `lib/app/app_state.dart:553-577` - overlaps/mergeCandidate/mergeEntry

  **Acceptance Criteria**:
  - [ ] `ActivityState` 和 `EntryState` 各 ≤300 行
  - [ ] AppState 通过组合方式暴露 ActivityState 和 EntryState
  - [ ] `notifyListeners()` 链正确传播
  - [ ] 全部现有测试通过

  **QA Scenarios**:
  ```
  Scenario: 拆分后事项切换功能正常
    Tool: Bash (flutter test)
    Preconditions: ActivityState 已提取
    Steps:
      1. 运行 test/activity_switch_button_test.dart
      2. 运行 test/app_state_reminder_test.dart
      3. 验证切换逻辑、提醒逻辑保持不变
    Expected Result: 全部测试通过
    Evidence: .omo/evidence/task-10-activity-state.txt
  ```

  **Commit**: YES
  - Message: `refactor(wave2): extract ActivityState and EntryState from AppState`
  - Files: `lib/app/activity_state.dart` (new), `lib/app/entry_state.dart` (new), `lib/app/app_state.dart`
  - Pre-commit: `flutter analyze && flutter test`

- [ ] 11. 拆分 AppState → SyncState + LanState + ReminderState

  **What to do**:
  - 创建 `lib/app/sync_state.dart`：提取 `isSyncing`、`canSync`、`sync()`、`sendMagicLink()`、`verifyEmailOtp()`、`signOut()`
  - 创建 `lib/app/lan_state.dart`：提取 `lanPeer`、`startLanServer()`、`stopLanServer()`、`pairLanPeer()`、`clearLanPeer()`
  - 创建 `lib/app/reminder_state.dart`：提取 `shouldShowReminder`、`lastReminderAt`、提醒定时器管理
  - AppState 组合上述 State 对象
  - 确保 sync() 中的云+LAM+回传编排逻辑正确保留

  **Must NOT do**:
  - 不改变同步编排顺序（云→LAN→云回传）
  - 不改变 LAN 配对流程

  **TDD Approach**: GREEN→GREEN

  **Recommended Agent Profile**:
  - **Category**: `deep`

  **Parallelization**:
  - **Can Run In Parallel**: YES（与 Task 10, 12 并行）
  - **Parallel Group**: Wave 2 (after Task 9, parallel with Tasks 10, 12)
  - **Blocks**: 13
  - **Blocked By**: 9

  **References**:
  - `lib/app/app_state.dart:42-68` - sync/cloud/lan 属性
  - `lib/app/app_state.dart:108-135` - 提醒 getters
  - `lib/app/app_state.dart:631-692` - sync() 完整编排
  - `lib/app/app_state.dart:694-736` - LAN 管理方法
  - `lib/app/app_state.dart:375-378` - continueCurrent/snoozeReminder

  **Acceptance Criteria**:
  - [ ] `SyncState`、`LanState`、`ReminderState` 各 ≤200 行
  - [ ] sync() 编排逻辑正确（云→LAN→云回传）
  - [ ] LAN 服务器启动/停止/配对完整
  - [ ] 提醒弹窗/banner 逻辑正确
  - [ ] 全部测试通过

  **QA Scenarios**:
  ```
  Scenario: 拆分后同步流程正常
    Tool: Bash (flutter test)
    Preconditions: SyncState 已提取
    Steps:
      1. 运行 test/sync_interop_test.dart
      2. 运行 test/app_state_reminder_test.dart
      3. 验证同步和提醒功能完整
    Expected Result: 全部测试通过
    Evidence: .omo/evidence/task-11-sync-state.txt
  ```

  **Commit**: YES
  - Message: `refactor(wave2): extract SyncState, LanState, ReminderState from AppState`
  - Files: `lib/app/sync_state.dart` (new), `lib/app/lan_state.dart` (new), `lib/app/reminder_state.dart` (new), `lib/app/app_state.dart`
  - Pre-commit: `flutter analyze && flutter test`

- [ ] 12. activityById Map 查找优化 + undo 快照优化

  **What to do**:
  - 在 `ActivityState.refresh()` 中维护 `Map<String, Activity> _activityMap`
  - 修改 `activityById` 为 O(1) Map 查找
  - 修改 `unassignedActivity` getter 使用 Map 而非线性搜索
  - 在 undo 快照中复用 Map 结构减少内存拷贝
  - 编写性能对比测试验证优化效果

  **Must NOT do**:
  - 不改变 activityById 的返回值语义（仍可为 null）
  - 不改变 undo 快照的正确性

  **TDD Approach**: GREEN→GREEN（行为保持）

  **Recommended Agent Profile**:
  - **Category**: `quick`

  **Parallelization**:
  - **Can Run In Parallel**: YES（与 Task 11 并行，依赖 Task 10 完成）
  - **Parallel Group**: Wave 2 (after Task 10, parallel with Task 11)
  - **Blocks**: 13
  - **Blocked By**: 7, 8, 10

  **References**:
  - `lib/app/app_state.dart:311-318` - activityById 线性搜索
  - `lib/app/app_state.dart:335-343` - unassignedActivity / _entryIsUnassigned
  - `lib/data/repository_undo.dart:55-57` - undo 快照中的 activities Map

  **Acceptance Criteria**:
  - [ ] `activityById` 从 O(n) 降为 O(1)
  - [ ] `refresh()` 时同步更新 Map
  - [ ] undo 快照正确使用 Map 结构
  - [ ] 全部测试通过

  **QA Scenarios**:
  ```
  Scenario: 大量 Activity 时查找性能提升
    Tool: Bash (flutter test)
    Preconditions: 创建 100 个 Activity
    Steps:
      1. 测量 activityById 查找 100 次的时间
      2. 验证所有查找结果正确
      3. 对比优化前后的效率
    Expected Result: 查找时间为 O(1)，不随 Activity 数量线性增长
    Evidence: .omo/evidence/task-12-map-lookup.txt
  ```

  **Commit**: YES
  - Message: `refactor(wave2): optimize activityById with Map lookup`
  - Files: `lib/app/activity_state.dart`, `lib/app/app_state.dart`, `lib/data/repository_undo.dart`
  - Pre-commit: `flutter analyze && flutter test`

- [ ] 15. 登录页错误反馈 + LAN 配对频率限制

  **What to do**:
  - 在 `login_page.dart` 添加错误状态显示（SnackBar 或内联错误文本），捕获 `sendMagicLink` 和 `verifyEmailOtp` 的失败
  - 在 `lan_sync.dart` 的 `/pair` 端点添加频率限制：使用 `Map<String, List<DateTime>>` 记录每个 IP 的尝试时间，5 次/分钟上限
  - 添加配对码 TTL：5 分钟过期
  - 编写测试验证错误反馈显示和频率限制生效

  **Must NOT do**:
  - 不改变登录流程或 LAN 配对流程的核心逻辑
  - 不改变 `lan_sync.dart` 的协议格式

  **TDD Approach**: RED→GREEN（新增行为）

  **Recommended Agent Profile**:
  - **Category**: `quick`

  **Parallelization**:
  - **Can Run In Parallel**: YES（与 Tasks 13, 14, 16-18 并行）
  - **Parallel Group**: Wave 3
  - **Blocks**: None
  - **Blocked By**: None

  **References**:
  - `lib/ui/login_page.dart:48-105` - 当前静默失败
  - `lib/data/lan_sync.dart:197-215` - 配对码生成和验证

  **Acceptance Criteria**:
  - [ ] 登录失败时用户看到错误提示
  - [ ] LAN 配对频率限制 5 次/分钟
  - [ ] 配对码 5 分钟过期
  - [ ] 测试验证错误提示和频率限制

  **QA Scenarios**:
  ```
  Scenario: 登录失败显示错误提示
    Tool: Bash (flutter test)
    Preconditions: 输入无效 email
    Steps:
      1. 输入 "invalid" 并点击发送
      2. 验证 SnackBar 或错误文本出现
    Expected Result: 显示明确错误信息
    Evidence: .omo/evidence/task-15-login-error.txt
  ```

  **Commit**: YES
  - Message: `refactor(wave3): add login error feedback and LAN rate limiting`
  - Files: `lib/ui/login_page.dart`, `lib/data/lan_sync.dart`
  - Pre-commit: `flutter analyze && flutter test`

- [ ] 16. 补充测试: 登录页 + 提醒弹窗 + 设置面板

  **What to do**:
  - 创建 `test/login_page_test.dart`：渲染测试、email 输入、发送按钮、token 验证
  - 创建 `test/reminder_dialog_test.dart`：弹窗显示、提醒方法切换、继续/延后操作
  - 扩展 `test/ui_controls_test.dart`：CloudSyncSettingsCard、LanSyncSettings 面板
  - 所有测试使用 WidgetTester + 内存 AppState

  **Must NOT do**:
  - 不删除现有测试文件
  - 不改变被测 Widget 的行为

  **TDD Approach**: RED→GREEN

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: [`flutter-add-widget-test`]

  **Parallelization**:
  - **Can Run In Parallel**: YES（与 Tasks 13-15, 17-18 并行）
  - **Parallel Group**: Wave 3
  - **Blocks**: None
  - **Blocked By**: None

  **References**:
  - `test/ui_controls_test.dart` - 现有 Widget 测试模式
  - `test/app_shell_shortcuts_test.dart` - AppShell 测试模式（创建 AppState 的方式）
  - `lib/ui/login_page.dart` - 被测组件
  - `lib/ui/app_shell.dart:459-519` - 提醒弹窗

  **Acceptance Criteria**:
  - [ ] `login_page_test.dart` 覆盖渲染 + 输入 + button 状态
  - [ ] `reminder_dialog_test.dart` 覆盖弹窗逻辑
  - [ ] 设置面板测试覆盖 CloudSync + LAN 面板
  - [ ] `flutter test` 全部通过

  **QA Scenarios**:
  ```
  Scenario: 新测试文件全部通过
    Tool: Bash (flutter test)
    Preconditions: 测试文件已创建
    Steps:
      1. 运行 flutter test test/login_page_test.dart
      2. 运行 flutter test test/reminder_dialog_test.dart
    Expected Result: 全部通过
    Evidence: .omo/evidence/task-16-new-tests.txt
  ```

  **Commit**: YES
  - Message: `refactor(wave3): add tests for login, reminder, settings panels`
  - Files: `test/login_page_test.dart` (new), `test/reminder_dialog_test.dart` (new), `test/ui_controls_test.dart`
  - Pre-commit: `flutter analyze && flutter test`

- [ ] 17. fromMap 安全类型转换

  **What to do**:
  - 修改所有领域模型的 `fromMap`：将 `as String`/`as int` 改为安全的 null-aware cast + 默认值
  - 对每个 `fromMap` 添加 try-catch 包装，失败时返回明确的 `FormatException`
  - 使用 `model_utils.dart` 中统一的 `readBool`
  - 编写测试验证 malformed 数据不会导致崩溃

  **Must NOT do**:
  - 不改变 `toLocalMap`/`toRemoteMap` 的输出格式
  - 不改变 `fromMap` 正常输入时的行为

  **TDD Approach**: RED→GREEN（新增安全行为）

  **Recommended Agent Profile**:
  - **Category**: `quick`

  **Parallelization**:
  - **Can Run In Parallel**: YES（与 Tasks 13-16, 18 并行）
  - **Parallel Group**: Wave 3
  - **Blocks**: None
  - **Blocked By**: 5

  **References**:
  - `lib/domain/activity.dart:76-88` - 当前不安全 fromMap
  - `lib/domain/time_entry.dart:131-147` - 当前不安全 fromMap
  - `lib/domain/action_log.dart:82-94` - 当前不安全 fromMap
  - `lib/domain/profile_settings.dart:105-119` - 已有回退值（较安全）

  **Acceptance Criteria**:
  - [ ] 所有 `fromMap` 使用安全模式：`(map['x'] as num?)?.toInt() ?? default`
  - [ ] malformed 数据抛 `FormatException` 而非 `TypeError`
  - [ ] 测试覆盖 null/missing/wrong-type 输入

  **QA Scenarios**:
  ```
  Scenario: malformed 数据安全处理
    Tool: Bash (flutter test)
    Preconditions: fromMap 已安全化
    Steps:
      1. 传入 map['color'] = null
      2. 调用 Activity.fromMap
      3. 验证抛出 FormatException 而非 TypeError
    Expected Result: 明确的 FormatException，不崩溃
    Evidence: .omo/evidence/task-17-safe-frommap.txt
  ```

  **Commit**: YES
  - Message: `refactor(wave3): add safe type casting to all fromMap methods`
  - Files: `lib/domain/activity.dart`, `lib/domain/time_entry.dart`, `lib/domain/action_log.dart`, `lib/domain/profile_settings.dart`
  - Pre-commit: `flutter analyze && flutter test`

- [ ] 18. actionType 字符串 → enum

  **What to do**:
  - 在 `lib/domain/action_log.dart` 定义 `enum ActionType`（switch/stop/edit/delete/undo/redo/merge/manual/split/activityDelete）
  - 添加 `storageValue` 和 `fromStorageValue` 方法
  - 修改 `ActionLog` 模型使用 `ActionType` 替代 `String`
  - 修改 `TimeRepository` 中所有 `'switch'` 等字符串字面量为 `ActionType.switch_`
  - 修改 `sync_bundle.dart` 的序列化/反序列化适配 enum

  **Must NOT do**:
  - 不改变数据库列的存储值（仍为字符串）
  - 不改变 ActionLog 的外部接口语义

  **TDD Approach**: GREEN→GREEN（保持行为）

  **Recommended Agent Profile**:
  - **Category**: `quick`

  **Parallelization**:
  - **Can Run In Parallel**: YES（与 Tasks 13-17 并行）
  - **Parallel Group**: Wave 3
  - **Blocks**: 19, 22
  - **Blocked By**: 5

  **References**:
  - `lib/domain/action_log.dart:17` - actionType String 字段
  - `lib/domain/profile_settings.dart:1-17` - ReminderMethod enum 模式（参考）
  - `lib/data/time_repository.dart` - 散布的字符串字面量（search for 'switch', 'stop', 'edit', etc）

  **Acceptance Criteria**:
  - [ ] `ActionType` enum 包含所有 10 种操作类型
  - [ ] ActionLog 使用 `ActionType` 类型
  - [ ] 数据库存储值不变（仍为字符串）
  - [ ] 全部测试通过

  **QA Scenarios**:
  ```
  Scenario: ActionType enum 序列化兼容
    Tool: Bash (flutter test)
    Preconditions: ActionType enum 已定义
    Steps:
      1. 创建 ActionLog with actionType=ActionType.switch_
      2. 序列化 toLocalMap
      3. 从 map 反序列化
      4. 验证 actionType 恢复为 ActionType.switch_
    Expected Result: 完整的序列化/反序列化循环
    Evidence: .omo/evidence/task-18-actiontype-enum.txt
  ```

  **Commit**: YES
  - Message: `refactor(wave3): convert actionType to enum`
  - Files: `lib/domain/action_log.dart`, `lib/data/time_repository.dart`, `lib/data/sync_bundle.dart`, `lib/data/time_entry_repository.dart`
  - Pre-commit: `flutter analyze && flutter test`

---

- [ ] 13. 暗色模式 `TimeTrackTheme.dark()`

  **What to do**:
  - 在 `app_theme.dart` 添加 `TimeTrackTheme.dark()` 方法
  - 基于 `ColorScheme.fromSeed` 生成暗色主题，使用 `Brightness.dark`
  - 确保 `AppConstants` 中的颜色常量在暗色模式下有对应值
  - 在 `main.dart` 中使用 `MediaQuery.platformBrightnessOf(context)` 自动切换
  - 编写 Widget 测试验证各页面在暗色模式下渲染正确

  **Must NOT do**:
  - 不修改 light() 主题的任何颜色值
  - 不新增第三方主题包

  **TDD Approach**: RED→GREEN（新功能）

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
    - Reason: 视觉主题设计，需要 UI/UX 敏感度

  **Parallelization**:
  - **Can Run In Parallel**: YES（与 Tasks 14-18 并行）
  - **Parallel Group**: Wave 3 (after Wave 2)
  - **Blocks**: 22
  - **Blocked By**: 6, 10, 11, 12

  **References**:
  - `lib/ui/app_theme.dart:1-181` - 当前 light() 实现
  - `lib/core/app_constants.dart` - 魔法数字常量（在 Task 6 中创建）
  - `lib/main.dart:69` - 当前 `theme: TimeTrackTheme.light()`

  **Acceptance Criteria**:
  - [ ] `TimeTrackTheme.dark()` 返回完整暗色 `ThemeData`
  - [ ] 系统暗色模式时自动切换
  - [ ] 所有页面的背景、文字、卡片颜色在暗色模式下可读
  - [ ] Widget 测试验证暗色模式渲染

  **QA Scenarios**:
  ```
  Scenario: 暗色模式下所有页面可读
    Tool: Bash (flutter test with dark theme)
    Preconditions: 暗色主题已定义
    Steps:
      1. 以暗色主题启动 MaterialApp
      2. 逐个渲染首页/时间线/统计/设置页面
      3. 验证文字与背景对比度 ≥ 4.5:1
    Expected Result: 所有页面文字清晰可读
    Evidence: .omo/evidence/task-13-dark-mode.txt
  ```

  **Commit**: YES
  - Message: `refactor(wave3): add dark mode theme`
  - Files: `lib/ui/app_theme.dart`, `lib/main.dart`
  - Pre-commit: `flutter analyze && flutter test`

- [ ] 14. 同步分页 + 批量上传 + 重试逻辑

  **What to do**:
  - **分页**: 修改 `sync_service.dart` 的 `sync()` 方法，对 Supabase 查询添加分页（`.range(offset, offset+pageSize-1)`，循环直到无更多行）
  - **批量上传**: 将逐条 `insert/update` 改为 `upsert` 批量操作（每次最多 100 条）
  - **重试**: 添加 3 次指数退避重试（`1s→2s→4s`），仅对 transient 错误（网络超时、503）
  - 编写测试验证分页、批量、重试行为

  **Must NOT do**:
  - 不改变数据同步的正确性（最后写入胜出）
  - 不修改 LAN 同步逻辑

  **TDD Approach**: RED→GREEN（新行为：分页/批量/重试都是新增）

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: 网络层改动，涉及 Supabase API 分页和错误重试

  **Parallelization**:
  - **Can Run In Parallel**: YES（与 Tasks 13, 15-18 并行，不冲突）
  - **Parallel Group**: Wave 3
  - **Blocks**: 22
  - **Blocked By**: 8

  **References**:
  - `lib/data/sync_service.dart:99-183` - 当前 sync() 无分页
  - `lib/data/sync_service.dart:139-172` - 当前逐条上传
  - `lib/data/sync_service.dart:198-231` - _uploadIfNotStale（含 23505 冲突处理）

  **Acceptance Criteria**:
  - [ ] 超过 1000 条记录时正确分页拉取
  - [ ] 批量上传减少 HTTP 请求数（100 条/次）
  - [ ] 网络失败后最多重试 3 次
  - [ ] `flutter test test/sync_interop_test.dart` 通过

  **QA Scenarios**:
  ```
  Scenario: 分页同步超过 1000 条记录
    Tool: Bash (flutter test)
    Preconditions: Supabase 中有 1500 条远程记录
    Steps:
      1. 触发 sync()
      2. 验证分 2 页拉取（1000 + 500）
      3. 验证本地数据完整
    Expected Result: 1500 条全部同步，无截断
    Evidence: .omo/evidence/task-14-pagination.txt
  ```

  **Commit**: YES
  - Message: `refactor(wave3): add sync pagination, batch upload, and retry`
  - Files: `lib/data/sync_service.dart`
  - Pre-commit: `flutter analyze && flutter test`

- [ ] 19. i18n 基础设施（.arb 文件 + AppLocalizations）

  **What to do**:
  - 创建 `l10n.yaml` 配置，指定 `template-arb-file: app_zh.arb`
  - 创建 `lib/l10n/app_zh.arb`（中文模板）和 `lib/l10n/app_en.arb`（英文翻译）
  - 运行 `flutter gen-l10n` 生成 `AppLocalizations` 类
  - 修改 `main.dart` 使用生成的 `localizationsDelegates`
  - 固定 `intl` 版本（`pubspec.yaml`）

  **Must NOT do**:
  - 不在本任务中迁移 UI 字符串（由 Task 20 完成）

  **TDD Approach**: GREEN→GREEN

  **Recommended Agent Profile**:
  - **Category**: `writing`

  **Parallelization**:
  - **Can Run In Parallel**: NO（Task 20 依赖本任务）
  - **Parallel Group**: Wave 4 sequential
  - **Blocks**: 20
  - **Blocked By**: 18

  **Acceptance Criteria**:
  - [ ] ARB 文件存在（zh+en），`flutter gen-l10n` 成功
  - [ ] `intl` 版本固定
  - [ ] 1 个页面验证 i18n 切换生效

  **QA Scenarios**:
  ```
  Scenario: 中英文切换生效
    Tool: Bash (flutter test)
    Steps:
      1. zh locale 启动 → 验证中文文本
      2. en locale 启动 → 验证英文文本
    Expected Result: 语言切换后文本正确
    Evidence: .omo/evidence/task-19-i18n-infra.txt
  ```

  **Commit**: YES
  - Message: `refactor(wave4): set up i18n infrastructure with ARB files`
  - Files: `lib/l10n/` (new), `l10n.yaml` (new), `lib/main.dart`, `pubspec.yaml`
  - Pre-commit: `flutter analyze && flutter test`

- [ ] 20. i18n 迁移所有 UI 字符串（~272 strings）

  **What to do**:
  - 逐个 UI 文件替换硬编码中文为 `AppLocalizations.of(context)!.xxx`
  - 覆盖：app_shell, home_page, timeline_page, stats_page, settings_page, login_page, interop_message_panel, ui_components
  - ARB 文件填充所有 key 的中英文值

  **Must NOT do**:
  - 不改变 UI 文本含义或布局

  **TDD Approach**: RED→GREEN

  **Recommended Agent Profile**:
  - **Category**: `writing`

  **Parallelization**:
  - **Can Run In Parallel**: NO（依赖 Task 19，改动范围广）
  - **Parallel Group**: Wave 4 sequential
  - **Blocks**: 22
  - **Blocked By**: 19

  **Acceptance Criteria**:
  - [ ] 所有 UI 文件零硬编码中文字符串
  - [ ] ARB 文件覆盖 ~272 key
  - [ ] `flutter test` 通过

  **QA Scenarios**:
  ```
  Scenario: 全量字符串迁移后功能完整
    Tool: Bash (flutter test)
    Steps:
      1. 运行全部测试
      2. 中英文下触发所有弹窗
    Expected Result: 文本正确，无 key 名泄露
    Evidence: .omo/evidence/task-20-i18n-migration.txt
  ```

  **Commit**: YES
  - Message: `refactor(wave4): migrate all UI strings to i18n`
  - Files: all `lib/ui/*.dart`, `lib/l10n/*.arb`
  - Pre-commit: `flutter analyze && flutter test`

- [ ] 21. 领域模型 ==/hashCode + 依赖版本同步

  **What to do**:
  - Activity/TimeEntry/ActionLog/ProfileSettings 添加 `==`/`hashCode`（基于 `id`）+ `toString()`
  - `pubspec.yaml` 所有依赖约束匹配 lockfile 实际版本

  **Must NOT do**:
  - 不改变模型序列化行为

  **TDD Approach**: GREEN→GREEN

  **Recommended Agent Profile**:
  - **Category**: `quick`

  **Parallelization**:
  - **Can Run In Parallel**: YES（与 Task 22 并行）
  - **Parallel Group**: Wave 4 (after Task 20)
  - **Blocked By**: 20

  **Acceptance Criteria**:
  - [ ] 4 个模型有 ==/hashCode/toString
  - [ ] 依赖版本不再漂移
  - [ ] `Activity('x') == Activity('x')` → true

  **QA Scenarios**:
  ```
  Scenario: 模型相等性正确
    Tool: Bash (dart test)
    Steps: 创建相同 id → 断言相等
    Expected Result: == 基于 id
    Evidence: .omo/evidence/task-21-equals.txt
  ```

  **Commit**: YES
  - Message: `refactor(wave4): add ==/hashCode to models, sync dep versions`
  - Files: `lib/domain/*.dart`, `pubspec.yaml`
  - Pre-commit: `flutter analyze && flutter test`

- [ ] 22. 最终集成验证 + 清理

  **What to do**:
  - `flutter analyze` → 修复所有警告
  - `flutter test` → 确保全部通过
  - 检查未使用的导入、死代码
  - 验证 AppResult 一致使用、暗色模式全页面、i18n 全局生效

  **Must NOT do**:
  - 不引入新功能

  **TDD Approach**: GREEN→GREEN

  **Recommended Agent Profile**:
  - **Category**: `deep`

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 4 final
  - **Blocks**: F1-F4
  - **Blocked By**: 13, 14, 18, 20

  **Acceptance Criteria**:
  - [ ] `flutter analyze` 零错误零警告
  - [ ] `flutter test` 全部通过
  - [ ] 无死代码/未使用导入

  **QA Scenarios**:
  ```
  Scenario: 全量回归验证
    Tool: Bash (flutter analyze && flutter test)
    Expected Result: 零错误，零警告，全部测试通过
    Evidence: .omo/evidence/task-22-integration.txt
  ```

  **Commit**: YES
  - Message: `refactor(wave4): final integration and cleanup`
  - Files: any remaining files

---

## Final Verification Wave

> 4 review agents run in PARALLEL. ALL must APPROVE. Present consolidated results to user and get explicit "okay" before completing.

- [ ] F1. **Plan Compliance Audit** — `oracle`
  Read the plan end-to-end. For each "Must Have": verify implementation exists. For each "Must NOT Have": search codebase for forbidden patterns. Check evidence files exist in .omo/evidence/.
  Output: `Must Have [N/N] | Must NOT Have [N/N] | Tasks [N/N] | VERDICT: APPROVE/REJECT`

- [ ] F2. **Code Quality Review** — `unspecified-high`
  Run `flutter analyze` and `flutter test`. Review all changed files for: type suppression, empty catches, debug logging, commented-out code, unused imports. Check AI slop.
  Output: `Analyze [PASS/FAIL] | Tests [N pass/N fail] | Files [N clean/N issues] | VERDICT`

- [ ] F3. **Real Manual QA** — `unspecified-high` (+ `playwright` skill)
  Start from clean state. Execute EVERY QA scenario from EVERY task. Test cross-task integration. Test edge cases: empty state, invalid input, rapid actions. Save to `.omo/evidence/final-qa/`.
  Output: `Scenarios [N/N pass] | Integration [N/N] | Edge Cases [N tested] | VERDICT`

- [ ] F4. **Scope Fidelity Check** — `deep`
  For each task: read "What to do", read actual diff. Verify 1:1 — everything in spec was built, nothing beyond spec was built. Check "Must NOT do" compliance. Flag unaccounted changes.
  Output: `Tasks [N/N compliant] | Contamination [CLEAN/N issues] | Unaccounted [CLEAN/N files] | VERDICT`

---

## Commit Strategy

按 Wave 分组提交，每个 Wave 完成后提交一次：
- `refactor(wave1): SQLite optimization and performance fixes`
- `refactor(wave2): split God objects TimeRepository and AppState`
- `refactor(wave3): dark mode, sync improvements, tests`
- `refactor(wave4): i18n, model cleanup, final integration`

---

## Success Criteria

### Verification Commands
```bash
flutter analyze                    # Expected: No issues found
flutter test                       # Expected: All tests passed
flutter test --coverage            # Expected: coverage maintained or improved
```

### Final Checklist
- [ ] All "Must Have" present
- [ ] All "Must NOT Have" absent
- [ ] All tests pass
- [ ] `flutter analyze` zero issues
- [ ] Dark mode renders all pages correctly
- [ ] i18n switches between zh and en
- [ ] No file exceeds 500 lines (except timeline_page which is deferred)
