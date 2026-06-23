// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'TimeTrack';

  @override
  String get appSubtitle => '离线优先记录，按下一个事项就开始。';

  @override
  String get navCurrent => '当前';

  @override
  String get navTimeline => '时间线';

  @override
  String get navStats => '统计';

  @override
  String get navSettings => '设置';

  @override
  String get ok => '确认';

  @override
  String get cancel => '取消';

  @override
  String get delete => '删除';

  @override
  String get save => '保存';

  @override
  String get syncStatusLocal => '本地模式';

  @override
  String get syncStatusCloud => '可同步';

  @override
  String get activityUnassigned => '未分配';

  @override
  String get reminderClose => '关闭';

  @override
  String get emptyTimeline => '暂无记录';

  @override
  String get sync => '同步';

  @override
  String get edit => '编辑';

  @override
  String get create => '创建';

  @override
  String get start => '开始';

  @override
  String get stop => '停止';

  @override
  String get continueLabel => '继续';

  @override
  String get confirm => '确认';

  @override
  String get undoHint => '撤销 Ctrl+Z';

  @override
  String undoWithLabel(String label) {
    return '撤销：$label Ctrl+Z';
  }

  @override
  String get redoHint => '重做 Ctrl+Y';

  @override
  String redoWithLabel(String label) {
    return '重做：$label Ctrl+Y';
  }

  @override
  String get quickSwitch => '快捷切换';

  @override
  String get quickSwitchHint => '轻点选择，再点一次确认切换。';

  @override
  String quickSwitchSelected(String name) {
    return '已选择 $name，再次点击后切换。';
  }

  @override
  String get currentDoing => '当前正在做';

  @override
  String get notStarted => '未开始';

  @override
  String get recording => '记录中';

  @override
  String get notStartedRecord => '未开始记录';

  @override
  String get selectActivityToStart => '选择一个事项开始记录今天的时间。';

  @override
  String elapsedDuration(String duration) {
    return '已持续 $duration';
  }

  @override
  String get stopCurrentActivity => '停止当前事项';

  @override
  String confirmSwitchSemantics(String name) {
    return '确认切换到$name';
  }

  @override
  String currentActivitySemantics(String name) {
    return '当前事项$name';
  }

  @override
  String switchToSemantics(String name) {
    return '切换到$name';
  }

  @override
  String get systemActivityCannotEdit => '系统事项，不能编辑';

  @override
  String get editActivity => '编辑事项';

  @override
  String get oneOffActivity => '临时事项';

  @override
  String get newActivity => '新增事项';

  @override
  String get editActivityTitle => '编辑事项';

  @override
  String get name => '名称';

  @override
  String get deleteActivityTitle => '删除事项';

  @override
  String confirmDeleteActivity(String name) {
    return '确定删除\"$name\"吗？已有时间记录会保留，但之后不能再选择这个事项。';
  }

  @override
  String selectColorTooltip(String hex) {
    return '选择颜色 $hex';
  }

  @override
  String get rgbTuner => 'RGB 调色';

  @override
  String get oneOff => '单次';

  @override
  String activityRunningMinutes(int minutes) {
    return '当前事项已持续 $minutes 分钟。';
  }

  @override
  String get remindLater => '稍后提醒';

  @override
  String get stillDoingThis => '还在做这件事吗？';

  @override
  String get confirmPreviousPeriod => '需要确认上一段时间';

  @override
  String get noRunningActivity => '没有正在进行的事项。';

  @override
  String suspiciousEntryContent(String time) {
    return '当前事项从 $time 开始，持续时间偏长。可以先结束到当前时间，再补记中间内容。';
  }

  @override
  String get keepCurrent => '继续保留';

  @override
  String get endToNow => '结束到现在';

  @override
  String get syncing => '正在同步';

  @override
  String get cloudSyncActive => '已登录并开启云同步';

  @override
  String get lanPeerPaired => '已配对局域网主机';

  @override
  String get localModeHint => '本地模式：可在设置中开启局域网互通或导入导出';

  @override
  String get selectDate => '选择日期';

  @override
  String get previousDay => '前一天';

  @override
  String get nextDay => '后一天';

  @override
  String get emptyDayEntries => '这一天还没有记录。';

  @override
  String get emptyRangeEntries => '这个范围还没有记录。';

  @override
  String get emptyDayActions => '这一天还没有切换或编辑指令。';

  @override
  String get emptyRangeActions => '这个范围还没有切换或编辑指令。';

  @override
  String get timeline => '时间轴';

  @override
  String get compact => '紧凑';

  @override
  String get detailed => '详细';

  @override
  String get singleDay => '单日';

  @override
  String get threeDays => '3日';

  @override
  String get sevenDays => '7日';

  @override
  String get addEntry => '补记';

  @override
  String get viewMode => '视图';

  @override
  String get entries => '记录';

  @override
  String get actions => '指令';

  @override
  String futureDayBanner(String date) {
    return '$date 尚未到来。记录会在这一天实际发生后才出现在这里。';
  }

  @override
  String get dayCoverageLine => '一天覆盖线';

  @override
  String get inProgress => '进行中';

  @override
  String get zoomableTimeline => '可缩放时间线';

  @override
  String get timelineDragHint => '横向拖动查看全天刻度，缩放后仍保留同一时间尺度。';

  @override
  String get entryList => '记录列表';

  @override
  String get entryListHint => '按开始时间排列，点击任一记录可编辑。';

  @override
  String get switchToRecordHint => '切换到补记或选择其他日期继续查看。';

  @override
  String editEntrySemantics(String name) {
    return '编辑$name时间段';
  }

  @override
  String get editTooltip => '编辑';

  @override
  String deviceLabel(String id) {
    return '设备 $id';
  }

  @override
  String get addEntryTitle => '补记时间段';

  @override
  String get editEntryTitle => '编辑时间段';

  @override
  String get selectValidActivity => '请选择一个有效事项。';

  @override
  String get endTime => '结束';

  @override
  String get keepRunning => '保持进行中';

  @override
  String get closeToSaveHint => '关闭后可把这条记录保存为已结束。';

  @override
  String get note => '备注';

  @override
  String get selectExistingOrNew => '请选择一个已有事项，或输入新的名称。';

  @override
  String get runningCannotStartFuture => '进行中的记录不能从未来开始。';

  @override
  String get endMustBeAfterStart => '结束时间必须晚于开始时间。';

  @override
  String get overlapWarning => '这个时间段和已有记录重叠。再次点击保存将自动切割已有记录。';

  @override
  String get split => '切割';

  @override
  String get extendToNow => '延续到现在';

  @override
  String get mergeLeft => '合并左侧';

  @override
  String get mergeRight => '合并右侧';

  @override
  String get noAdjacentRecord => '没有可合并的相邻记录';

  @override
  String get left => '左侧';

  @override
  String get right => '右侧';

  @override
  String mergeDirectionRecord(String direction) {
    return '合并$direction记录';
  }

  @override
  String mergeConfirm(String name, String duration, int threshold) {
    return '$name 的时长为 $duration，超过 $threshold 分钟阈值。确定合并吗？';
  }

  @override
  String get merge => '合并';

  @override
  String get splitEntryTitle => '切割时间段';

  @override
  String get splitPoint => '切割点';

  @override
  String get splitPointError => '切割点必须在开始和结束之间。';

  @override
  String get extendEntryError => '开始时间晚于当前时间，无法延续';

  @override
  String get createActivityTitle => '创建事项';

  @override
  String get persistent => '持久';

  @override
  String get entryActivityLabel => '事项';

  @override
  String get editCurrentActivity => '编辑当前事项';

  @override
  String get noMatchingActivity => '没有匹配事项';

  @override
  String get today => '今天';

  @override
  String get yesterday => '昨天';

  @override
  String get thisWeek => '本周';

  @override
  String get lastWeek => '上周';

  @override
  String get stats => '统计';

  @override
  String statsSubtitle(String label) {
    return '查看 $label 的时间分布和每日累计。';
  }

  @override
  String get range => '范围';

  @override
  String get customDay => '自选日';

  @override
  String get totalRangeRecords => '范围总记录';

  @override
  String get longestStreak => '最长连续';

  @override
  String distributionChartTitle(String label) {
    return '$label分布';
  }

  @override
  String get noDataToVisualize => '暂无可视化数据';

  @override
  String get activityColorLegend => '按事项汇总，颜色与事项保持一致。';

  @override
  String get noData => '暂无数据';

  @override
  String get startRecordingHint => '开始记录或选择其他范围后会显示分布。';

  @override
  String get unknownActivity => '未知事项';

  @override
  String get dailyTotal => '每日累计';

  @override
  String get dailyTotalHint => '用于观察本周或自选范围的记录节奏。';

  @override
  String get recordHint => '有记录后会按日期列出总时长。';

  @override
  String get settings => '设置';

  @override
  String get settingsSubtitle => '提醒、同步和设备互通都保持本地优先。';

  @override
  String get timelineSettings => '时间线';

  @override
  String get timelineSettingsHint => '控制相邻记录合并时是否需要确认。';

  @override
  String get mergeThreshold => '合并阈值';

  @override
  String minutesFormat(int count) {
    return '$count 分钟';
  }

  @override
  String get reminderSettings => '提醒';

  @override
  String get reminderSettingsHint => '用轻提示确认长时间运行的事项。';

  @override
  String get triggerTime => '触发时间';

  @override
  String get durationLabel => '持续时间';

  @override
  String get interval => '间隔';

  @override
  String get method => '方式';

  @override
  String get methodDialog => '对话框';

  @override
  String get methodBanner => '横幅';

  @override
  String get methodSilent => '静默';

  @override
  String get supabaseConfigured => 'Supabase 已配置';

  @override
  String get supabaseNotConfigured => 'Supabase 未配置';

  @override
  String get loggedIn => '已登录';

  @override
  String get notLoggedIn => '未登录或本地模式';

  @override
  String get cloudSync => '云同步';

  @override
  String get cloudSyncHint => '未配置 Supabase 时应用继续以本地模式运行。';

  @override
  String get signOut => '退出';

  @override
  String get syncNow => '立即同步';

  @override
  String get deviceInterop => '设备互通';

  @override
  String get deviceInteropHint => '同一 Wi-Fi 下可通过局域网或文件互通数据。';

  @override
  String get importFile => '导入文件';

  @override
  String get exportFile => '导出文件';

  @override
  String get lanHost => '局域网主机';

  @override
  String get lanHostWaiting => '正在等待同网段设备连接。';

  @override
  String get lanHostWindowsNote => 'v1 默认 Windows 作为局域网主机；Android 作为客户端连接电脑。';

  @override
  String get lanHostAndroidNote => '在 Android 上输入下方地址和配对码。';

  @override
  String get lanHostStartNote => '开启后，其他设备可在同一 Wi-Fi 内配对。';

  @override
  String pairingCodeLabel(String code) {
    return '配对码：$code';
  }

  @override
  String get windowsOnly => '仅 Windows 可开启';

  @override
  String get stopHost => '关闭主机';

  @override
  String get startHost => '开启主机';

  @override
  String get connectLanHost => '连接局域网主机';

  @override
  String get connectLanHostHint => '输入地址和配对码后会立即尝试同步。';

  @override
  String pairedWith(String name) {
    return '已配对：$name';
  }

  @override
  String get removePairing => '移除配对';

  @override
  String get hostAddress => '主机地址';

  @override
  String get hostHint => '192.168.1.10:8787';

  @override
  String get pairingCodeInput => '配对码';

  @override
  String get pairAndSync => '配对并同步';

  @override
  String get multiDeviceSync => '多设备同步';

  @override
  String get multiDeviceSyncHint => '本地记录始终可用，登录后再同步到云端。';

  @override
  String get emailLabel => '邮箱';

  @override
  String get sending => '发送中';

  @override
  String get sendCode => '发送验证码';

  @override
  String get emailCode => '邮箱验证码';

  @override
  String get verifying => '验证中';

  @override
  String get verifyLogin => '验证登录';

  @override
  String sendFailed(String error) {
    return '发送失败：$error';
  }

  @override
  String verifyFailed(String error) {
    return '验证失败：$error';
  }

  @override
  String get exported => '已导出';

  @override
  String get imported => '已导入';

  @override
  String get operationFailed => '操作失败';

  @override
  String get interopStatus => '互通状态';

  @override
  String get failed => '失败';
}
