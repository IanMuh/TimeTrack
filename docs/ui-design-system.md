# TimeTrack UI Design System

> 全局 UI 设计方案 — 可配置配色版
> 基于代码审查与截图分析的综合改进计划

---

## 1. 概述

本文档定义 TimeTrack 应用的完整视觉设计系统，包含可自由搭配的配色方案、排版规范、组件标准与页面布局指南。所有规范基于 Material 3 设计体系，针对生产力/时间追踪类工具产品优化。

**核心改进目标：**
- 信息密度提升 50%~80%
- 支持 7 套主题色 × 2 种模式 = 14 种配色组合
- 消除卡片嵌套与冗余元素
- 建立统一的视觉层级与交互反馈

---

## 2. 设计原则

| 原则 | 说明 | 反模式 |
|------|------|--------|
| **信息优先** | 单屏展示更多有效信息，减少无意义留白 | 大标题区 + 大量空白 |
| **层级扁平** | 禁止卡片套卡片，最多一层卡片容器 | 设置页卡片内嵌套子卡片 |
| **克制用色** | 彩色仅用于状态指示和图标，背景保持中性 | 活动卡片全彩背景 |
| **紧凑呼吸** | 减少标题区高度，内容间距统一为 8dp 倍数 | 页面标题 32sp + 副标题 + 大间距 |
| **一页一意图** | 每个页面只有一个核心动作，次要操作收敛 | 时间线页多个折叠面板 |
| **自由配色** | 用户可自由选择主题色，亮/暗独立切换 | 固定 teal 主色 |

---

## 3. 可配置配色系统

### 3.1 架构设计

配色系统采用 **预设主题 + 亮度模式** 的正交设计：

```
最终主题 = ThemePreset（7 选 1） × Brightness（2 选 1）
```

- **ThemePreset**：定义主色调（seed color），通过 `ColorScheme.fromSeed` 生成完整色板
- **Brightness**：`light` 或 `dark`，独立切换，不影响主色调色相

### 3.2 预设主题（ThemePreset）

| 预设 | 标识 | Seed Color | 氛围 | 适用场景 |
|------|------|-----------|------|----------|
| **Teal** | `teal` | `#0D9488` | 专业、冷静 | 默认，生产力工具 |
| **Blue** | `blue` | `#2563EB` | 信任、科技 | 商务、数据驱动 |
| **Purple** | `purple` | `#7C3AED` | 创意、专注 | 设计、创意工作 |
| **Orange** | `orange` | `#EA580C` | 活力、温暖 | 运动、户外 |
| **Rose** | `rose` | `#E11D48` | 热情、醒目 | 番茄钟、高强度 |
| **Emerald** | `emerald` | `#059669` | 自然、平衡 | 健康、冥想 |
| **Slate** | `slate` | `#475569` | 极简、中性 | 极简主义者 |

### 3.3 色板生成规则

每套预设通过 `ColorScheme.fromSeed(seedColor: seed, brightness: brightness)` 生成 Material 3 标准色板，包含：

- `primary` / `onPrimary` / `primaryContainer` / `onPrimaryContainer`
- `secondary` / `onSecondary` / `secondaryContainer` / `onSecondaryContainer`
- `tertiary` / `onTertiary` / `tertiaryContainer` / `onTertiaryContainer`
- `error` / `onError` / `errorContainer` / `onErrorContainer`
- `surface` / `onSurface` / `surfaceVariant` / `onSurfaceVariant`
- `outline` / `outlineVariant` / `shadow` / `scrim`
- `inverseSurface` / `onInverseSurface` / `inversePrimary`

**自定义覆盖（覆盖 Material 3 默认值）：**

```dart
// 亮色模式覆盖
ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.light).copyWith(
  background: const Color(0xFFF5F5F7),      // 暖灰白，降低刺眼感
  surface: const Color(0xFFFFFFFF),
  surfaceVariant: const Color(0xFFF0F0F2),  // 次级卡片、输入框背景
  onSurface: const Color(0xFF1C1917),       // 暖黑，非纯黑
  onSurfaceVariant: const Color(0xFF78716C), // 次级文字
  outline: const Color(0xFFD6D3D1),         // 边框、分割线
  outlineVariant: const Color(0xFFE7E5E4),
);

// 暗色模式覆盖
ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark).copyWith(
  background: const Color(0xFF0C0A09),      // 暖黑
  surface: const Color(0xFF1C1917),
  surfaceVariant: const Color(0xFF292524),  // 输入框、次级卡片
  onSurface: const Color(0xFFFAFAF9),       // 暖白
  onSurfaceVariant: const Color(0xFFA8A29E), // 次级文字
  outline: const Color(0xFF44403C),         // 边框、分割线
  outlineVariant: const Color(0xFF52525B),
);
```

### 3.4 功能色（跨主题固定）

功能色不随主题变化，保持用户认知一致性：

| 功能 | 亮色 | 暗色 | 用途 |
|------|------|------|------|
| **Success** | `#059669` | `#34D399` | 同步成功、保存确认 |
| **Warning** | `#D97706` | `#FBBF24` | 提醒、注意事项 |
| **Error** | `#DC2626` | `#F87171` | 删除、停止录制、错误 |
| **Info** | `#2563EB` | `#60A5FA` | 提示、链接 |

### 3.5 活动指示色（可配置）

活动颜色与主题预设解耦，用户可为每个活动分配任意颜色。提供 19 色标准调色板：

```dart
const activityPalette = [
  Color(0xFF0D9488), // Teal
  Color(0xFF2563EB), // Blue
  Color(0xFF7C3AED), // Purple
  Color(0xFFEA580C), // Orange
  Color(0xFFE11D48), // Rose
  Color(0xFF059669), // Emerald
  Color(0xFF475569), // Slate
  Color(0xFF0891B2), // Cyan
  Color(0xFF4F46E5), // Indigo
  Color(0xFFDB2777), // Pink
  Color(0xFFCA8A04), // Yellow
  Color(0xFF16A34A), // Green
  Color(0xFF9333EA), // Violet
  Color(0xFFC2410C), // Red Orange
  Color(0xFF0F766E), // Dark Teal
  Color(0xFF1D4ED8), // Dark Blue
  Color(0xFF7C2D12), // Brown
  Color(0xFF374151), // Gray
  Color(0xFFA8A29E), // Light Gray (未安排)
];
```

**暗色模式适配**：活动颜色在暗色模式下自动提亮 20%（通过 HSL 亮度通道调整），确保在深色背景上可见。

### 3.6 主题切换机制

**数据模型：**

```dart
enum ThemePreset {
  teal('Teal', Color(0xFF0D9488)),
  blue('Blue', Color(0xFF2563EB)),
  purple('Purple', Color(0xFF7C3AED)),
  orange('Orange', Color(0xFFEA580C)),
  rose('Rose', Color(0xFFE11D48)),
  emerald('Emerald', Color(0xFF059669)),
  slate('Slate', Color(0xFF475569));

  final String label;
  final Color seedColor;
  const ThemePreset(this.label, this.seedColor);
}

class AppThemeSettings {
  final ThemePreset preset;
  final ThemeMode mode; // system / light / dark

  const AppThemeSettings({
    this.preset = ThemePreset.teal,
    this.mode = ThemeMode.system,
  });
}
```

**主题生成器：**

```dart
class TimeTrackTheme {
  static ThemeData buildTheme(AppThemeSettings settings) {
    final brightness = switch (settings.mode) {
      ThemeMode.light => Brightness.light,
      ThemeMode.dark => Brightness.dark,
      ThemeMode.system => PlatformDispatcher.instance.platformBrightness,
    };

    final colorScheme = ColorScheme.fromSeed(
      seedColor: settings.preset.seedColor,
      brightness: brightness,
    ).copyWith(
      // 应用自定义覆盖...
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      // ...其他主题配置
    );
  }
}
```

**设置入口：**

在设置页新增"外观"子页，提供：
- 主题色选择：7 色圆形色块网格，选中带边框
- 模式选择：跟随系统 / 亮色 / 暗色（分段按钮）
- 实时预览：顶部显示当前配色预览卡片

---

## 4. 排版系统

### 4.1 字体规模

| Token | 尺寸 | 字重 | 行高 | 用途 |
|-------|------|------|------|------|
| `displayLarge` | 32sp | w700 | 1.2 | 当前活动名称（录制中） |
| `displayMedium` | 24sp | w700 | 1.3 | 页面大标题 |
| `headlineMedium` | 20sp | w600 | 1.4 | 卡片标题、对话框标题 |
| `titleLarge` | 16sp | w600 | 1.5 | 列表项标题、设置项 |
| `bodyLarge` | 14sp | w400 | 1.5 | 正文、描述 |
| `bodyMedium` | 14sp | w400 | 1.5 | 次级正文 |
| `labelLarge` | 12sp | w500 | 1.4 | 标签、时间戳、状态 |

### 4.2 排版规则

- **页面标题区高度**：从 ~120px 压缩到 ~56px
- **标题与副标题**：合并为一行或紧密排列（间距 4dp）
- **数字显示**：使用等宽字体（`fontFamily: 'Roboto Mono'` 或系统等宽字体），防止时间/时长数字跳动
- **最长行宽**：手机 35-60 字符，桌面 60-75 字符

---

## 5. 间距系统

### 5.1 基础单位

基础单位：**8dp**

| Token | 值 | 用途 |
|-------|-----|------|
| `space_1` | 4dp | 图标与文字间距、紧凑内边距 |
| `space_2` | 8dp | 控件间距、行内间距 |
| `space_3` | 12dp | 卡片间距、列表项间距 |
| `space_4` | 16dp | 页面边距（compact）、卡片内边距 |
| `space_5` | 24dp | 页面边距（medium）、区块间距 |
| `space_6` | 32dp | 页面边距（expanded）、大区块间距 |
| `space_8` | 48dp | 大标题与内容间距 |

### 5.2 页面边距

| 断点 | 宽度 | 水平边距 |
|------|------|----------|
| Compact | < 600px | 16dp |
| Medium | 600-840px | 24dp |
| Expanded | ≥ 840px | 32dp |

### 5.3 组件间距

- **卡片间距**：12dp（从 16dp 缩减）
- **列表项高度**：56dp（紧凑列表）
- **按钮最小高度**：44dp（触摸目标）
- **分段按钮间距**：8dp

---

## 6. 组件规范

### 6.1 活动卡片（ActivitySwitchButton）

```
┌─────────────────────────────────────┐
│ ▓ 工作                    ✎         │  ← 左侧 4dp 彩色边条
│                                     │     白色/暗色表面背景
└─────────────────────────────────────┘
```

| 属性 | 值 |
|------|-----|
| 背景 | `surface` 色 |
| 左侧边条 | 4dp 圆角，活动色，未选中 |
| 选中边条 | 6dp 圆角，`primaryContainer` 背景 |
| 文字 | 未选中：活动色；选中：`onPrimaryContainer` |
| 高度 | 48dp |
| 内边距 | 12dp 水平 / 8dp 垂直 |
| 圆角 | 10dp |
| 边框 | 1dp `outline` 色 |

**交互状态：**
- 默认：左侧 4dp 边条
- 按下：缩放 0.96，200ms
- 选中：背景变为 `primaryContainer`，边条加宽到 6dp
- 悬停（桌面）：背景 `surfaceVariant`

### 6.2 状态卡片（CurrentStatusCard）

```
┌─────────────────────────────────────┐
│ ⏱ 当前正在做          [● 未开始]    │  ← 标题和状态同一行
│                                     │
│ 未开始记录                          │  ← 24sp 粗体
│ 选择一个事项开始记录今天的时间。     │  ← 14sp 次级文字
│                                     │
│ [● 开始记录]                        │  ← 主按钮
└─────────────────────────────────────┘
```

| 属性 | 值 |
|------|-----|
| 背景 | `surface` 色 |
| 内边距 | 16dp |
| 标题行 | 标题 + 状态标签同一行 |
| 活动名称 | `displayMedium`（24sp），单行 |
| 提示文字 | `bodyMedium`（14sp） |
| 操作按钮 | 未开始：主按钮；录制中：红色停止按钮 |
| 整体高度 | ~120dp（从 ~180dp 压缩） |

**录制中状态：**
- 状态标签：呼吸灯动画（`AnimatedOpacity` 1.0↔0.4，2s 循环）
- 时长显示：等宽字体，每秒更新

### 6.3 底部导航栏（NavigationBar）

| 属性 | 值 |
|------|-----|
| 背景 | `surface` 色 |
| 高度 | 72dp |
| 选中状态 | 图标 + 文字变为 `primary` 色，无背景块 |
| 未选中状态 | `onSurfaceVariant` 色 |
| 标签行为 | `alwaysShow`（始终显示文字） |
| 图标大小 | 24dp |
| 文字 | `labelLarge`（12sp） |

### 6.4 设置项（SettingsTile）

```
┌─────────────────────────────────────┐
│ 🔔 提醒              30分钟/对话框  > │  ← 图标 + 标题 + 摘要 + 箭头
├─────────────────────────────────────┤
│ 📊 时间线            1分钟          > │
├─────────────────────────────────────┤
│ ☁️ 云同步            未配置         > │
└─────────────────────────────────────┘
```

| 属性 | 值 |
|------|-----|
| 高度 | 56dp |
| 左侧图标 | 24dp，`onSurfaceVariant` 色 |
| 标题 | `titleLarge`（16sp） |
| 副标题 | `labelLarge`（12sp），`onSurfaceVariant` 色 |
| 右侧摘要 | `bodyMedium`（14sp），`primary` 色 |
| 分割线 | 1dp `outline` 色，左侧缩进 56dp |
| 点击区域 | 整行 |

### 6.5 骨架屏（Skeleton）

```dart
class Skeleton extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const Skeleton({
    required this.width,
    required this.height,
    this.borderRadius = 10,
  });
}
```

| 属性 | 值 |
|------|-----|
| 基础色 | `surfaceVariant` |
| 脉冲色 | 比基础色亮/暗 10% |
| 动画 | `LinearGradient` 从左到右扫描，1.5s 循环 |
| 圆角 | 10dp |

**变体：**
- `SkeletonLine`：水平长条（用于文本占位）
- `SkeletonCircle`：圆形（用于头像、图标占位）
- `SkeletonCard`：卡片形状（用于卡片占位）

---

## 7. 页面布局规范

### 7.1 首页（HomePage）

**布局结构：**

```
┌─────────────────────────────────────┐
│ [本地模式 ⚡]  右上角: 同步状态图标    │  ← 状态标签药丸
├─────────────────────────────────────┤
│ ┌─────────────────────────────────┐ │
│ │ 当前状态卡片（120dp 高）         │ │
│ └─────────────────────────────────┘ │
│                                     │
│ 快捷切换                    [⇅ 排序] │  ← 标题和排序同一行
│ ─────────────────────────────────── │
│ ┌─────────────┐ ┌─────────────┐     │
│ │ ● 工作      │ │ ● 学习      │     │  ← 2 列网格
│ │         ✎   │ │         ✎   │     │
│ └─────────────┘ └─────────────┘     │
│ ┌─────────────┐ ┌─────────────┐     │
│ │ ● 看视频    │ │ ● 睡觉      │     │
│ └─────────────┘ └─────────────┘     │
│ ┌─────────────┐ ┌─────────────┐     │
│ │ ⚡ 临时事项  │ │ + 新增事项   │     │
│ └─────────────┘ └─────────────┘     │
└─────────────────────────────────────┘
```

**关键尺寸：**
- 状态卡片高度：120dp
- 活动卡片高度：48dp
- 网格间距：10dp
- 单屏活动卡片数：compact 6-8 个（从 4 个提升）

### 7.2 时间线页（TimelinePage）

**布局结构：**

```
┌─────────────────────────────────────┐
│ 时间轴                              │
│ 2026-07-15                          │
├─────────────────────────────────────┤
│ [←] [2026-07-15 📅] [→]  [记录 ▼] [+补记] │  ← 头部控件一行
├─────────────────────────────────────┤
│ ┌─────────────────────────────────┐ │
│ │ 时间线画布（直接展示）            │ │
│ │ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │ │
│ │ ▓▓▓▓▓▓▓▓▓▓ 未安排 00:00-09:40   │ │
│ │ ▓▓ 工作 09:40-09:48              │ │
│ └─────────────────────────────────┘ │
│                                     │
│ 记录列表  [开始时间 ▼] [⇅]          │  ← 排序控件一行
│ ─────────────────────────────────── │
│ ┌─────────────────────────────────┐ │
│ │ ▓ 未安排    9小时40分  00:00-09:40│ │  ← 56dp 紧凑列表项
│ │ ▓ 工作      8分钟      09:40-09:48│ │
│ └─────────────────────────────────┘ │
└─────────────────────────────────────┘
```

**关键尺寸：**
- 日期选择器行高：48dp
- 时间线画布高度：160dp（从 200dp 压缩）
- 记录列表项高度：56dp（从 ~80dp 压缩）
- 单屏记录数：6 条（从 3 条提升）

### 7.3 统计页（StatsPage）

**布局结构：**

```
┌─────────────────────────────────────┐
│ 统计                    [今天 ▼]    │  ← 标题和范围选择器一行
│ 查看今天的时间分布和每日累计。       │
├─────────────────────────────────────┤
│ ┌─────────────┐ ┌─────────────┐     │
│ │ 范围总记录   │ │ 最长连续     │     │  ← 指标卡片并排
│ │ 8 分钟      │ │ 8 分钟      │     │
│ └─────────────┘ └─────────────┘     │
├─────────────────────────────────────┤
│ ┌─────────────────────────────────┐ │
│ │ 📊 今天分布                      │ │
│ │      [饼图区域]                  │ │
│ │      工作 100%                   │ │
│ │                                 │ │
│ │ 工作    8分钟·1次   ▓▓▓▓▓▓▓▓▓▓  │ │  ← 水平进度条图例
│ │ test1   0分钟·1次   ▓           │ │
│ │ 学习    0分钟·1次   ▓           │ │
│ └─────────────────────────────────┘ │
├─────────────────────────────────────┤
│ ┌─────────────────────────────────┐ │
│ │ 📅 每日累计                      │ │
│ │                                 │ │
│ │ 2026-07-15  周三      8 分钟    │ │  ← 7 天数据
│ │ 2026-07-14  周二      2 小时    │ │
│ │ 2026-07-13  周一      1.5 小时  │ │
│ └─────────────────────────────────┘ │
└─────────────────────────────────────┘
```

**关键尺寸：**
- 指标卡片：两列并排（medium+），12dp 内边距
- 饼图高度：200dp（从 260dp 压缩）
- 图例：水平进度条形式，与饼图同区域
- 每日累计：展示最近 7 天，列表项 48dp

### 7.4 设置页（SettingsPage）

**列表布局：**

```
┌─────────────────────────────────────┐
│ 设置                                │
│ 提醒、同步和设备互通都保持本地优先。 │
├─────────────────────────────────────┤
│ ┌─────────────────────────────────┐ │
│ │ 🔔 提醒              30分钟/对话框│ │  ← 右侧显示当前值
│ ├─────────────────────────────────┤ │
│ │ 📊 时间线            1分钟       │ │
│ ├─────────────────────────────────┤ │
│ │ ☁️ 云同步            未配置      │ │
│ ├─────────────────────────────────┤ │
│ │ 📡 设备互通          未配对      │ │
│ ├─────────────────────────────────┤ │
│ │ ⬇️ 版本更新          0.3.0-pre+6│ │
│ ├─────────────────────────────────┤ │
│ │ 🎨 外观              Teal / 跟随 │ │  ← 新增外观设置项
│ └─────────────────────────────────┘ │
└─────────────────────────────────────┘
```

**子页布局（以提醒为例）：**

```
┌─────────────────────────────────────┐
│ ← 提醒                    [保存]    │  ← AppBar
├─────────────────────────────────────┤
│ 用轻提示确认长时间运行的事项。       │  ← 说明文字
│                                     │
│ 触发时间                    09:00   │  ← 标签和值同一行
│ ─────────────────────────────────── │
│ 持续时间                   180 分钟 │
│ ━━━━━━━━━━━━━━━━━━━━━━━━●━━━━━━━   │  ← 滑块紧跟下方
│                                     │
│ 间隔                        60 分钟 │
│ ━━━━━━━━━━━━━━━━━━━━━━━━●━━━━━━━   │
│                                     │
│ 方式                              │
│ [对话框] [横幅] [静默]              │  ← 分段按钮紧凑排列
└─────────────────────────────────────┘
```

---

## 8. 暗色模式适配

### 8.1 颜色映射

| 元素 | 亮色 | 暗色 |
|------|------|------|
| 页面背景 | `#F5F5F7` | `#0C0A09` |
| 卡片背景 | `#FFFFFF` | `#1C1917` |
| 次级表面 | `#F0F0F2` | `#292524` |
| 主文字 | `#1C1917` | `#FAFAF9` |
| 次级文字 | `#78716C` | `#A8A29E` |
| 边框 | `#D6D3D1` | `#44403C` |
| 活动边条 | 原始色 | 原始色 + 亮度 +20% |
| 选中卡片背景 | `primaryContainer` (light) | `primaryContainer` (dark) |

### 8.2 组件适配

- **卡片**：暗色模式下边框对比度降低，依靠背景色区分层级
- **活动边条**：自动提亮，确保在深色背景上可见
- **骨架屏**：基础色使用 `surfaceVariant`（暗色 `#292524`）
- **阴影**：暗色模式下减少或取消阴影，依靠边框和背景色区分

---

## 9. 交互规范

### 9.1 触觉反馈

| 场景 | 反馈类型 | 说明 |
|------|----------|------|
| 活动切换 | `lightImpact` | 轻点反馈 |
| 按钮点击 | `lightImpact` | 轻点反馈 |
| 保存/确认 | `mediumImpact` | 中等反馈 |
| 同步完成 | `success` | 成功反馈（iOS: success, Android: vibrate） |
| 删除/停止 | `heavyImpact` | 重反馈，提示不可逆操作 |

### 9.2 动画规范

| 动画 | 时长 | 曲线 | 说明 |
|------|------|------|------|
| 页面转场 | 200ms | `easeInOut` | compact: 滑动, expanded: 淡入淡出 |
| 活动切换 | 200ms | `easeOut` | 颜色 + 边条宽度 + 缩放 |
| 录制脉冲 | 2000ms | `easeInOut` | 循环，呼吸灯效果 |
| 骨架屏扫描 | 1500ms | `linear` | 线性渐变扫描 |
| SnackBar 滑入 | 300ms | `easeOut` | 从底部滑入 |
| 对话框弹出 | 200ms | `easeOut` | 缩放 + 淡入 |

### 9.3 加载状态

| 场景 | 加载指示 | 说明 |
|------|----------|------|
| 页面首次加载 | 骨架屏 | 脉冲灰色占位 |
| 下拉刷新 | `RefreshIndicator` | Material 圆形进度 |
| 异步操作 | `CircularProgressIndicator` | 按钮内或对话框内 |
| 图片/图表 | 骨架屏或模糊占位 | 保持布局稳定 |

---

## 10. 执行计划

### 10.0 可行性评估（2026-07-15）

总体判断：**方案可行，但必须分阶段落地**。现有代码已经具备 Material 3 主题、宽度断点、自适应导航、页面拆分和关键 Widget 测试基础，因此视觉密度、主题 token、活动卡片、状态卡片、导航栏和设置列表可以低风险推进。

需要拆分处理的部分：

| 范围 | 可行程度 | 说明 |
|------|----------|------|
| 主题预设基础 | 高 | 可先建立 `ThemePreset` 与统一主题生成器，不改变当前默认主题。 |
| 外观设置入口 | 中 | 需要新增设置模型、持久化、状态同步和本地化，不能只做 UI。 |
| 首页紧凑化 | 高 | 现有 `HomePage` 已使用断点和网格，适合局部优化。 |
| 时间线/统计页重构 | 中 | 涉及数据加载、排序、图表和列表行为，应逐页配测试推进。 |
| 触觉反馈/骨架屏 | 中 | 技术可行，但需要确认各平台策略和减少动态效果行为。 |
| 14 种主题组合验证 | 中 | 依赖外观设置完整落地后再做系统验证。 |

本次落地范围：

- 新增 `lib/ui/theme_preset.dart`，建立 7 套主题 seed 的代码基础。
- 重构 `lib/ui/app_theme.dart`，统一亮/暗主题生成、紧凑排版、列表密度和无背景块导航选中态。
- 优化 `CurrentStatusCard`、`ActivitySwitchButton`、底部导航栏和设置 section 列表，优先提升首页与设置页的信息密度。

暂不纳入本次落地：

- 设置页“外观”子页与主题持久化。
- 时间线、统计页的大规模重排。
- 触觉反馈、页面转场、骨架屏等交互增强。

### Phase 1 — 基础修复层

| # | 任务 | 文件 | 工作量 |
|---|------|------|--------|
| 1.1 | 硬编码中文本地化 | `l10n/`, `ui/sort_controls.dart`, `ui/timeline_entry_lists.dart`, `ui/timeline_header.dart`, `ui/interop_message_panel.dart`, `ui/stats_page.dart` | 小 |
| 1.2 | FutureBuilder 加载状态 | `ui/stats_page.dart`, `ui/timeline_page.dart` | 小 |
| 1.3 | 下拉刷新 | `ui/home_page.dart`, `ui/timeline_page.dart`, `ui/stats_page.dart` | 小 |
| 1.4 | 对话框最大高度 | `ui/ui_components.dart` | 小 |
| 1.5 | SnackBar 统一封装 | 新建 `ui/snackbar_helper.dart` | 小 |

### Phase 2 — 设计系统重构

| # | 任务 | 文件 | 工作量 |
|---|------|------|--------|
| 2.1 | 可配置主题系统 | 新建 `ui/theme_preset.dart`, 重写 `ui/app_theme.dart` | 大 |
| 2.2 | 排版系统调整 | `ui/app_theme.dart` | 小 |
| 2.3 | 间距系统统一 | `ui/adaptive_layout.dart`, `ui/ui_components.dart` | 小 |
| 2.4 | 活动颜色降级 | `ui/activity_colors.dart`, `ui/activity_switch_button.dart` | 中 |

### Phase 3 — 页面级重构

| # | 任务 | 文件 | 工作量 |
|---|------|------|--------|
| 3.1 | 首页重构 | `ui/home_page.dart`, `ui/current_status_card.dart` | 中 |
| 3.2 | 时间线重构 | `ui/timeline_page.dart`, `ui/timeline_header.dart`, `ui/timeline_entry_lists.dart`, `ui/timeline_canvas.dart` | 大 |
| 3.3 | 统计页重构 | `ui/stats_page.dart` | 大 |
| 3.4 | 设置页重构 | `ui/settings_page.dart`, `ui/settings_section_list.dart`, 新建 `ui/settings_tile.dart`, 新增外观设置 | 大 |
| 3.5 | 底部导航优化 | `ui/app_shell.dart` | 小 |
| 3.6 | 共享组件调整 | `ui/ui_components.dart` | 中 |

### Phase 4 — 交互增强层

| # | 任务 | 文件 | 工作量 |
|---|------|------|--------|
| 4.1 | 触觉反馈 | 新建 `ui/app_haptics.dart` | 小 |
| 4.2 | 录制脉冲动画 | `ui/current_status_card.dart` | 小 |
| 4.3 | 活动切换动画 | `ui/activity_switch_button.dart` | 中 |
| 4.4 | 页面转场动画 | `ui/app_shell.dart` | 中 |
| 4.5 | 加载骨架屏 | 新建 `ui/skeleton.dart` | 中 |

### Phase 5 — 验证与测试

| # | 任务 | 说明 | 工作量 |
|---|------|------|--------|
| 5.1 | 静态分析 | `flutter analyze` | 小 |
| 5.2 | 单元测试 | `flutter test` | 小 |
| 5.3 | 多宽度验证 | 360px / 600px / 1024px | 中 |
| 5.4 | 主题切换验证 | 7 预设 × 2 模式 = 14 种组合 | 中 |
| 5.5 | 可访问性验证 | 对比度、大字体、减少动态效果 | 中 |

---

## 附录 A：主题预设预览

### Teal（默认）
- **Seed**: `#0D9488`
- **氛围**: 专业、冷静、生产力
- **适用**: 通用场景

### Blue
- **Seed**: `#2563EB`
- **氛围**: 信任、科技、数据
- **适用**: 商务用户

### Purple
- **Seed**: `#7C3AED`
- **氛围**: 创意、专注、深度
- **适用**: 设计师、创作者

### Orange
- **Seed**: `#EA580C`
- **氛围**: 活力、温暖、运动
- **适用**: 运动、户外追踪

### Rose
- **Seed**: `#E11D48`
- **氛围**: 热情、醒目、紧迫
- **适用**: 番茄钟、高强度工作

### Emerald
- **Seed**: `#059669`
- **氛围**: 自然、平衡、健康
- **适用**: 健康、冥想追踪

### Slate
- **Seed**: `#475569`
- **氛围**: 极简、中性、低调
- **适用**: 极简主义者

---

## 附录 B：文件变更清单

### 新建文件
- `lib/ui/theme_preset.dart` — 主题预设枚举
- `lib/ui/snackbar_helper.dart` — SnackBar 统一封装
- `lib/ui/app_haptics.dart` — 触觉反馈辅助类
- `lib/ui/skeleton.dart` — 骨架屏组件
- `lib/ui/settings_tile.dart` — 设置列表项组件
- `docs/ui-design-system.md` — 本文档

### 重写文件
- `lib/ui/app_theme.dart` — 主题系统全面重构

### 修改文件
- `lib/l10n/app_zh.arb` — 补充本地化键值
- `lib/l10n/app_en.arb` — 补充本地化键值
- `lib/ui/app_shell.dart` — 导航栏优化、转场动画
- `lib/ui/home_page.dart` — 布局重构
- `lib/ui/current_status_card.dart` — 紧凑化、脉冲动画
- `lib/ui/activity_switch_button.dart` — 颜色降级、切换动画
- `lib/ui/activity_colors.dart` — 饱和度调整
- `lib/ui/timeline_page.dart` — 加载状态
- `lib/ui/timeline_header.dart` — 控件合并
- `lib/ui/timeline_entry_lists.dart` — 列表项紧凑化
- `lib/ui/timeline_canvas.dart` — 宽屏适配
- `lib/ui/stats_page.dart` — 布局重构、空状态
- `lib/ui/settings_page.dart` — 列表/详情重构
- `lib/ui/settings_section_list.dart` — 列表项调整
- `lib/ui/ui_components.dart` — 组件间距调整
- `lib/ui/adaptive_layout.dart` — 间距系统
- `lib/ui/sort_controls.dart` — 本地化
- `lib/ui/interop_message_panel.dart` — 本地化

---

*文档版本: 1.0*
*生成日期: 2026-07-15*
*适用项目: TimeTrack Flutter App*
