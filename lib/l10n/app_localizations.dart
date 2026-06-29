import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh')
  ];

  /// No description provided for @appTitle.
  ///
  /// In zh, this message translates to:
  /// **'TimeTrack'**
  String get appTitle;

  /// No description provided for @appSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'离线优先记录，按下一个事项就开始。'**
  String get appSubtitle;

  /// No description provided for @navCurrent.
  ///
  /// In zh, this message translates to:
  /// **'当前'**
  String get navCurrent;

  /// No description provided for @navTimeline.
  ///
  /// In zh, this message translates to:
  /// **'时间线'**
  String get navTimeline;

  /// No description provided for @navStats.
  ///
  /// In zh, this message translates to:
  /// **'统计'**
  String get navStats;

  /// No description provided for @navSettings.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get navSettings;

  /// No description provided for @ok.
  ///
  /// In zh, this message translates to:
  /// **'确认'**
  String get ok;

  /// No description provided for @cancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get delete;

  /// No description provided for @save.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get save;

  /// No description provided for @syncStatusLocal.
  ///
  /// In zh, this message translates to:
  /// **'本地模式'**
  String get syncStatusLocal;

  /// No description provided for @syncStatusCloud.
  ///
  /// In zh, this message translates to:
  /// **'可同步'**
  String get syncStatusCloud;

  /// No description provided for @activityUnassigned.
  ///
  /// In zh, this message translates to:
  /// **'未分配'**
  String get activityUnassigned;

  /// No description provided for @reminderClose.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get reminderClose;

  /// No description provided for @emptyTimeline.
  ///
  /// In zh, this message translates to:
  /// **'暂无记录'**
  String get emptyTimeline;

  /// No description provided for @sync.
  ///
  /// In zh, this message translates to:
  /// **'同步'**
  String get sync;

  /// No description provided for @sortBy.
  ///
  /// In zh, this message translates to:
  /// **'排序依据'**
  String get sortBy;

  /// No description provided for @edit.
  ///
  /// In zh, this message translates to:
  /// **'编辑'**
  String get edit;

  /// No description provided for @create.
  ///
  /// In zh, this message translates to:
  /// **'创建'**
  String get create;

  /// No description provided for @start.
  ///
  /// In zh, this message translates to:
  /// **'开始'**
  String get start;

  /// No description provided for @stop.
  ///
  /// In zh, this message translates to:
  /// **'停止'**
  String get stop;

  /// No description provided for @continueLabel.
  ///
  /// In zh, this message translates to:
  /// **'继续'**
  String get continueLabel;

  /// No description provided for @confirm.
  ///
  /// In zh, this message translates to:
  /// **'确认'**
  String get confirm;

  /// No description provided for @undoHint.
  ///
  /// In zh, this message translates to:
  /// **'撤销 Ctrl+Z'**
  String get undoHint;

  /// No description provided for @undoWithLabel.
  ///
  /// In zh, this message translates to:
  /// **'撤销：{label} Ctrl+Z'**
  String undoWithLabel(String label);

  /// No description provided for @redoHint.
  ///
  /// In zh, this message translates to:
  /// **'重做 Ctrl+Y'**
  String get redoHint;

  /// No description provided for @redoWithLabel.
  ///
  /// In zh, this message translates to:
  /// **'重做：{label} Ctrl+Y'**
  String redoWithLabel(String label);

  /// No description provided for @quickSwitch.
  ///
  /// In zh, this message translates to:
  /// **'快捷切换'**
  String get quickSwitch;

  /// No description provided for @quickSwitchHint.
  ///
  /// In zh, this message translates to:
  /// **'轻点选择，再点一次确认切换。'**
  String get quickSwitchHint;

  /// No description provided for @quickSwitchSelected.
  ///
  /// In zh, this message translates to:
  /// **'已选择 {name}，再次点击后切换。'**
  String quickSwitchSelected(String name);

  /// No description provided for @currentDoing.
  ///
  /// In zh, this message translates to:
  /// **'当前正在做'**
  String get currentDoing;

  /// No description provided for @notStarted.
  ///
  /// In zh, this message translates to:
  /// **'未开始'**
  String get notStarted;

  /// No description provided for @recording.
  ///
  /// In zh, this message translates to:
  /// **'记录中'**
  String get recording;

  /// No description provided for @notStartedRecord.
  ///
  /// In zh, this message translates to:
  /// **'未开始记录'**
  String get notStartedRecord;

  /// No description provided for @selectActivityToStart.
  ///
  /// In zh, this message translates to:
  /// **'选择一个事项开始记录今天的时间。'**
  String get selectActivityToStart;

  /// No description provided for @elapsedDuration.
  ///
  /// In zh, this message translates to:
  /// **'已持续 {duration}'**
  String elapsedDuration(String duration);

  /// No description provided for @stopCurrentActivity.
  ///
  /// In zh, this message translates to:
  /// **'停止当前事项'**
  String get stopCurrentActivity;

  /// No description provided for @confirmSwitchSemantics.
  ///
  /// In zh, this message translates to:
  /// **'确认切换到{name}'**
  String confirmSwitchSemantics(String name);

  /// No description provided for @currentActivitySemantics.
  ///
  /// In zh, this message translates to:
  /// **'当前事项{name}'**
  String currentActivitySemantics(String name);

  /// No description provided for @switchToSemantics.
  ///
  /// In zh, this message translates to:
  /// **'切换到{name}'**
  String switchToSemantics(String name);

  /// No description provided for @systemActivityCannotEdit.
  ///
  /// In zh, this message translates to:
  /// **'系统事项，不能编辑'**
  String get systemActivityCannotEdit;

  /// No description provided for @editActivity.
  ///
  /// In zh, this message translates to:
  /// **'编辑事项'**
  String get editActivity;

  /// No description provided for @oneOffActivity.
  ///
  /// In zh, this message translates to:
  /// **'临时事项'**
  String get oneOffActivity;

  /// No description provided for @newActivity.
  ///
  /// In zh, this message translates to:
  /// **'新增事项'**
  String get newActivity;

  /// No description provided for @editActivityTitle.
  ///
  /// In zh, this message translates to:
  /// **'编辑事项'**
  String get editActivityTitle;

  /// No description provided for @name.
  ///
  /// In zh, this message translates to:
  /// **'名称'**
  String get name;

  /// No description provided for @color.
  ///
  /// In zh, this message translates to:
  /// **'颜色'**
  String get color;

  /// No description provided for @recentlyUpdated.
  ///
  /// In zh, this message translates to:
  /// **'最近更新'**
  String get recentlyUpdated;

  /// No description provided for @deleteActivityTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除事项'**
  String get deleteActivityTitle;

  /// No description provided for @confirmDeleteActivity.
  ///
  /// In zh, this message translates to:
  /// **'确定删除\"{name}\"吗？已有时间记录会保留，但之后不能再选择这个事项。'**
  String confirmDeleteActivity(String name);

  /// No description provided for @selectColorTooltip.
  ///
  /// In zh, this message translates to:
  /// **'选择颜色 {hex}'**
  String selectColorTooltip(String hex);

  /// No description provided for @rgbTuner.
  ///
  /// In zh, this message translates to:
  /// **'RGB 调色'**
  String get rgbTuner;

  /// No description provided for @oneOff.
  ///
  /// In zh, this message translates to:
  /// **'单次'**
  String get oneOff;

  /// No description provided for @activityRunningMinutes.
  ///
  /// In zh, this message translates to:
  /// **'当前事项已持续 {minutes} 分钟。'**
  String activityRunningMinutes(int minutes);

  /// No description provided for @remindLater.
  ///
  /// In zh, this message translates to:
  /// **'稍后提醒'**
  String get remindLater;

  /// No description provided for @stillDoingThis.
  ///
  /// In zh, this message translates to:
  /// **'还在做这件事吗？'**
  String get stillDoingThis;

  /// No description provided for @confirmPreviousPeriod.
  ///
  /// In zh, this message translates to:
  /// **'需要确认上一段时间'**
  String get confirmPreviousPeriod;

  /// No description provided for @noRunningActivity.
  ///
  /// In zh, this message translates to:
  /// **'没有正在进行的事项。'**
  String get noRunningActivity;

  /// No description provided for @suspiciousEntryContent.
  ///
  /// In zh, this message translates to:
  /// **'当前事项从 {time} 开始，持续时间偏长。可以先结束到当前时间，再补记中间内容。'**
  String suspiciousEntryContent(String time);

  /// No description provided for @keepCurrent.
  ///
  /// In zh, this message translates to:
  /// **'继续保留'**
  String get keepCurrent;

  /// No description provided for @endToNow.
  ///
  /// In zh, this message translates to:
  /// **'结束到现在'**
  String get endToNow;

  /// No description provided for @syncing.
  ///
  /// In zh, this message translates to:
  /// **'正在同步'**
  String get syncing;

  /// No description provided for @cloudSyncActive.
  ///
  /// In zh, this message translates to:
  /// **'已登录并开启云同步'**
  String get cloudSyncActive;

  /// No description provided for @lanPeerPaired.
  ///
  /// In zh, this message translates to:
  /// **'已配对局域网主机'**
  String get lanPeerPaired;

  /// No description provided for @localModeHint.
  ///
  /// In zh, this message translates to:
  /// **'本地模式：可在设置中开启局域网互通或导入导出'**
  String get localModeHint;

  /// No description provided for @selectDate.
  ///
  /// In zh, this message translates to:
  /// **'选择日期'**
  String get selectDate;

  /// No description provided for @previousDay.
  ///
  /// In zh, this message translates to:
  /// **'前一天'**
  String get previousDay;

  /// No description provided for @nextDay.
  ///
  /// In zh, this message translates to:
  /// **'后一天'**
  String get nextDay;

  /// No description provided for @emptyDayEntries.
  ///
  /// In zh, this message translates to:
  /// **'这一天还没有记录。'**
  String get emptyDayEntries;

  /// No description provided for @emptyRangeEntries.
  ///
  /// In zh, this message translates to:
  /// **'这个范围还没有记录。'**
  String get emptyRangeEntries;

  /// No description provided for @emptyDayActions.
  ///
  /// In zh, this message translates to:
  /// **'这一天还没有切换或编辑指令。'**
  String get emptyDayActions;

  /// No description provided for @emptyRangeActions.
  ///
  /// In zh, this message translates to:
  /// **'这个范围还没有切换或编辑指令。'**
  String get emptyRangeActions;

  /// No description provided for @timeline.
  ///
  /// In zh, this message translates to:
  /// **'时间轴'**
  String get timeline;

  /// No description provided for @compact.
  ///
  /// In zh, this message translates to:
  /// **'紧凑'**
  String get compact;

  /// No description provided for @detailed.
  ///
  /// In zh, this message translates to:
  /// **'详细'**
  String get detailed;

  /// No description provided for @singleDay.
  ///
  /// In zh, this message translates to:
  /// **'单日'**
  String get singleDay;

  /// No description provided for @threeDays.
  ///
  /// In zh, this message translates to:
  /// **'3日'**
  String get threeDays;

  /// No description provided for @sevenDays.
  ///
  /// In zh, this message translates to:
  /// **'7日'**
  String get sevenDays;

  /// No description provided for @addEntry.
  ///
  /// In zh, this message translates to:
  /// **'补记'**
  String get addEntry;

  /// No description provided for @viewMode.
  ///
  /// In zh, this message translates to:
  /// **'视图'**
  String get viewMode;

  /// No description provided for @entries.
  ///
  /// In zh, this message translates to:
  /// **'记录'**
  String get entries;

  /// No description provided for @actions.
  ///
  /// In zh, this message translates to:
  /// **'指令'**
  String get actions;

  /// No description provided for @displayOptions.
  ///
  /// In zh, this message translates to:
  /// **'显示选项'**
  String get displayOptions;

  /// No description provided for @singleLineZoom.
  ///
  /// In zh, this message translates to:
  /// **'单行缩放'**
  String get singleLineZoom;

  /// No description provided for @segmentedDayDisplay.
  ///
  /// In zh, this message translates to:
  /// **'分段显示'**
  String get segmentedDayDisplay;

  /// No description provided for @futureDayBanner.
  ///
  /// In zh, this message translates to:
  /// **'{date} 尚未到来。记录会在这一天实际发生后才出现在这里。'**
  String futureDayBanner(String date);

  /// No description provided for @dayCoverageLine.
  ///
  /// In zh, this message translates to:
  /// **'一天覆盖线'**
  String get dayCoverageLine;

  /// No description provided for @inProgress.
  ///
  /// In zh, this message translates to:
  /// **'进行中'**
  String get inProgress;

  /// No description provided for @zoomableTimeline.
  ///
  /// In zh, this message translates to:
  /// **'可缩放时间线'**
  String get zoomableTimeline;

  /// No description provided for @timelineDragHint.
  ///
  /// In zh, this message translates to:
  /// **'横向拖动查看全天刻度，缩放后仍保留同一时间尺度。'**
  String get timelineDragHint;

  /// No description provided for @entryList.
  ///
  /// In zh, this message translates to:
  /// **'记录列表'**
  String get entryList;

  /// No description provided for @entryListHint.
  ///
  /// In zh, this message translates to:
  /// **'按开始时间排列，点击任一记录可编辑。'**
  String get entryListHint;

  /// No description provided for @switchToRecordHint.
  ///
  /// In zh, this message translates to:
  /// **'切换到补记或选择其他日期继续查看。'**
  String get switchToRecordHint;

  /// No description provided for @editEntrySemantics.
  ///
  /// In zh, this message translates to:
  /// **'编辑{name}时间段'**
  String editEntrySemantics(String name);

  /// No description provided for @editTooltip.
  ///
  /// In zh, this message translates to:
  /// **'编辑'**
  String get editTooltip;

  /// No description provided for @deviceLabel.
  ///
  /// In zh, this message translates to:
  /// **'设备 {id}'**
  String deviceLabel(String id);

  /// No description provided for @addEntryTitle.
  ///
  /// In zh, this message translates to:
  /// **'补记时间段'**
  String get addEntryTitle;

  /// No description provided for @editEntryTitle.
  ///
  /// In zh, this message translates to:
  /// **'编辑时间段'**
  String get editEntryTitle;

  /// No description provided for @selectValidActivity.
  ///
  /// In zh, this message translates to:
  /// **'请选择一个有效事项。'**
  String get selectValidActivity;

  /// No description provided for @endTime.
  ///
  /// In zh, this message translates to:
  /// **'结束'**
  String get endTime;

  /// No description provided for @keepRunning.
  ///
  /// In zh, this message translates to:
  /// **'保持进行中'**
  String get keepRunning;

  /// No description provided for @closeToSaveHint.
  ///
  /// In zh, this message translates to:
  /// **'关闭后可把这条记录保存为已结束。'**
  String get closeToSaveHint;

  /// No description provided for @note.
  ///
  /// In zh, this message translates to:
  /// **'备注'**
  String get note;

  /// No description provided for @selectExistingOrNew.
  ///
  /// In zh, this message translates to:
  /// **'请选择一个已有事项，或输入新的名称。'**
  String get selectExistingOrNew;

  /// No description provided for @runningCannotStartFuture.
  ///
  /// In zh, this message translates to:
  /// **'进行中的记录不能从未来开始。'**
  String get runningCannotStartFuture;

  /// No description provided for @endMustBeAfterStart.
  ///
  /// In zh, this message translates to:
  /// **'结束时间必须晚于开始时间。'**
  String get endMustBeAfterStart;

  /// No description provided for @overlapWarning.
  ///
  /// In zh, this message translates to:
  /// **'这个时间段和已有记录重叠。再次点击保存将自动切割已有记录。'**
  String get overlapWarning;

  /// No description provided for @split.
  ///
  /// In zh, this message translates to:
  /// **'切割'**
  String get split;

  /// No description provided for @extendToNow.
  ///
  /// In zh, this message translates to:
  /// **'延续到现在'**
  String get extendToNow;

  /// No description provided for @mergeLeft.
  ///
  /// In zh, this message translates to:
  /// **'合并左侧'**
  String get mergeLeft;

  /// No description provided for @mergeRight.
  ///
  /// In zh, this message translates to:
  /// **'合并右侧'**
  String get mergeRight;

  /// No description provided for @noAdjacentRecord.
  ///
  /// In zh, this message translates to:
  /// **'没有可合并的相邻记录'**
  String get noAdjacentRecord;

  /// No description provided for @left.
  ///
  /// In zh, this message translates to:
  /// **'左侧'**
  String get left;

  /// No description provided for @right.
  ///
  /// In zh, this message translates to:
  /// **'右侧'**
  String get right;

  /// No description provided for @mergeDirectionRecord.
  ///
  /// In zh, this message translates to:
  /// **'合并{direction}记录'**
  String mergeDirectionRecord(String direction);

  /// No description provided for @mergeConfirm.
  ///
  /// In zh, this message translates to:
  /// **'{name} 的时长为 {duration}，超过 {threshold} 分钟阈值。确定合并吗？'**
  String mergeConfirm(String name, String duration, int threshold);

  /// No description provided for @merge.
  ///
  /// In zh, this message translates to:
  /// **'合并'**
  String get merge;

  /// No description provided for @splitEntryTitle.
  ///
  /// In zh, this message translates to:
  /// **'切割时间段'**
  String get splitEntryTitle;

  /// No description provided for @splitPoint.
  ///
  /// In zh, this message translates to:
  /// **'切割点'**
  String get splitPoint;

  /// No description provided for @splitPointError.
  ///
  /// In zh, this message translates to:
  /// **'切割点必须在开始和结束之间。'**
  String get splitPointError;

  /// No description provided for @extendEntryError.
  ///
  /// In zh, this message translates to:
  /// **'开始时间晚于当前时间，无法延续'**
  String get extendEntryError;

  /// No description provided for @createActivityTitle.
  ///
  /// In zh, this message translates to:
  /// **'创建事项'**
  String get createActivityTitle;

  /// No description provided for @persistent.
  ///
  /// In zh, this message translates to:
  /// **'持久'**
  String get persistent;

  /// No description provided for @entryActivityLabel.
  ///
  /// In zh, this message translates to:
  /// **'事项'**
  String get entryActivityLabel;

  /// No description provided for @editCurrentActivity.
  ///
  /// In zh, this message translates to:
  /// **'编辑当前事项'**
  String get editCurrentActivity;

  /// No description provided for @noMatchingActivity.
  ///
  /// In zh, this message translates to:
  /// **'没有匹配事项'**
  String get noMatchingActivity;

  /// No description provided for @today.
  ///
  /// In zh, this message translates to:
  /// **'今天'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In zh, this message translates to:
  /// **'昨天'**
  String get yesterday;

  /// No description provided for @thisWeek.
  ///
  /// In zh, this message translates to:
  /// **'本周'**
  String get thisWeek;

  /// No description provided for @lastWeek.
  ///
  /// In zh, this message translates to:
  /// **'上周'**
  String get lastWeek;

  /// No description provided for @stats.
  ///
  /// In zh, this message translates to:
  /// **'统计'**
  String get stats;

  /// No description provided for @statsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'查看 {label} 的时间分布和每日累计。'**
  String statsSubtitle(String label);

  /// No description provided for @range.
  ///
  /// In zh, this message translates to:
  /// **'范围'**
  String get range;

  /// No description provided for @filters.
  ///
  /// In zh, this message translates to:
  /// **'筛选'**
  String get filters;

  /// No description provided for @statsDimension.
  ///
  /// In zh, this message translates to:
  /// **'统计维度'**
  String get statsDimension;

  /// No description provided for @activityDimension.
  ///
  /// In zh, this message translates to:
  /// **'事项'**
  String get activityDimension;

  /// No description provided for @primaryCategoryDimension.
  ///
  /// In zh, this message translates to:
  /// **'主分类'**
  String get primaryCategoryDimension;

  /// No description provided for @durationBucketDimension.
  ///
  /// In zh, this message translates to:
  /// **'单条时长'**
  String get durationBucketDimension;

  /// No description provided for @categoryDurationDimension.
  ///
  /// In zh, this message translates to:
  /// **'分类+时长'**
  String get categoryDurationDimension;

  /// No description provided for @customDay.
  ///
  /// In zh, this message translates to:
  /// **'自选日'**
  String get customDay;

  /// No description provided for @totalRangeRecords.
  ///
  /// In zh, this message translates to:
  /// **'范围总记录'**
  String get totalRangeRecords;

  /// No description provided for @longestStreak.
  ///
  /// In zh, this message translates to:
  /// **'最长连续'**
  String get longestStreak;

  /// No description provided for @distributionChartTitle.
  ///
  /// In zh, this message translates to:
  /// **'{label}分布'**
  String distributionChartTitle(String label);

  /// No description provided for @noDataToVisualize.
  ///
  /// In zh, this message translates to:
  /// **'暂无可视化数据'**
  String get noDataToVisualize;

  /// No description provided for @activityColorLegend.
  ///
  /// In zh, this message translates to:
  /// **'按事项汇总，颜色与事项保持一致。'**
  String get activityColorLegend;

  /// No description provided for @noData.
  ///
  /// In zh, this message translates to:
  /// **'暂无数据'**
  String get noData;

  /// No description provided for @startRecordingHint.
  ///
  /// In zh, this message translates to:
  /// **'开始记录或选择其他范围后会显示分布。'**
  String get startRecordingHint;

  /// No description provided for @unknownActivity.
  ///
  /// In zh, this message translates to:
  /// **'未知事项'**
  String get unknownActivity;

  /// No description provided for @dailyTotal.
  ///
  /// In zh, this message translates to:
  /// **'每日累计'**
  String get dailyTotal;

  /// No description provided for @dailyTotalHint.
  ///
  /// In zh, this message translates to:
  /// **'用于观察本周或自选范围的记录节奏。'**
  String get dailyTotalHint;

  /// No description provided for @recordHint.
  ///
  /// In zh, this message translates to:
  /// **'有记录后会按日期列出总时长。'**
  String get recordHint;

  /// No description provided for @settings.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settings;

  /// No description provided for @settingsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'提醒、同步和设备互通都保持本地优先。'**
  String get settingsSubtitle;

  /// No description provided for @settingsSections.
  ///
  /// In zh, this message translates to:
  /// **'返回设置分区'**
  String get settingsSections;

  /// No description provided for @activityCategorySettings.
  ///
  /// In zh, this message translates to:
  /// **'事项分类'**
  String get activityCategorySettings;

  /// No description provided for @timelineSettings.
  ///
  /// In zh, this message translates to:
  /// **'时间线'**
  String get timelineSettings;

  /// No description provided for @timelineSettingsHint.
  ///
  /// In zh, this message translates to:
  /// **'控制相邻记录合并时是否需要确认。'**
  String get timelineSettingsHint;

  /// No description provided for @mergeThreshold.
  ///
  /// In zh, this message translates to:
  /// **'合并阈值'**
  String get mergeThreshold;

  /// No description provided for @minutesFormat.
  ///
  /// In zh, this message translates to:
  /// **'{count} 分钟'**
  String minutesFormat(int count);

  /// No description provided for @reminderSettings.
  ///
  /// In zh, this message translates to:
  /// **'提醒'**
  String get reminderSettings;

  /// No description provided for @reminderSettingsHint.
  ///
  /// In zh, this message translates to:
  /// **'用轻提示确认长时间运行的事项。'**
  String get reminderSettingsHint;

  /// No description provided for @reminderInAppNotice.
  ///
  /// In zh, this message translates to:
  /// **'当前提醒是应用内提示；应用关闭、被系统挂起或后台受限时不保证触发。'**
  String get reminderInAppNotice;

  /// No description provided for @triggerTime.
  ///
  /// In zh, this message translates to:
  /// **'触发时间'**
  String get triggerTime;

  /// No description provided for @durationLabel.
  ///
  /// In zh, this message translates to:
  /// **'持续时间'**
  String get durationLabel;

  /// No description provided for @interval.
  ///
  /// In zh, this message translates to:
  /// **'间隔'**
  String get interval;

  /// No description provided for @method.
  ///
  /// In zh, this message translates to:
  /// **'方式'**
  String get method;

  /// No description provided for @methodDialog.
  ///
  /// In zh, this message translates to:
  /// **'对话框'**
  String get methodDialog;

  /// No description provided for @methodBanner.
  ///
  /// In zh, this message translates to:
  /// **'横幅'**
  String get methodBanner;

  /// No description provided for @methodSilent.
  ///
  /// In zh, this message translates to:
  /// **'静默'**
  String get methodSilent;

  /// No description provided for @supabaseConfigured.
  ///
  /// In zh, this message translates to:
  /// **'Supabase 已配置'**
  String get supabaseConfigured;

  /// No description provided for @supabaseNotConfigured.
  ///
  /// In zh, this message translates to:
  /// **'Supabase 未配置'**
  String get supabaseNotConfigured;

  /// No description provided for @loggedIn.
  ///
  /// In zh, this message translates to:
  /// **'已登录'**
  String get loggedIn;

  /// No description provided for @notLoggedIn.
  ///
  /// In zh, this message translates to:
  /// **'未登录或本地模式'**
  String get notLoggedIn;

  /// No description provided for @cloudSync.
  ///
  /// In zh, this message translates to:
  /// **'云同步'**
  String get cloudSync;

  /// No description provided for @cloudSyncHint.
  ///
  /// In zh, this message translates to:
  /// **'未配置 Supabase 时应用继续以本地模式运行。'**
  String get cloudSyncHint;

  /// No description provided for @syncStatus.
  ///
  /// In zh, this message translates to:
  /// **'同步状态'**
  String get syncStatus;

  /// No description provided for @syncTargetLabel.
  ///
  /// In zh, this message translates to:
  /// **'当前目标：{target}'**
  String syncTargetLabel(String target);

  /// No description provided for @syncTargetNone.
  ///
  /// In zh, this message translates to:
  /// **'无'**
  String get syncTargetNone;

  /// No description provided for @syncTargetCloud.
  ///
  /// In zh, this message translates to:
  /// **'云同步'**
  String get syncTargetCloud;

  /// No description provided for @syncTargetLan.
  ///
  /// In zh, this message translates to:
  /// **'局域网'**
  String get syncTargetLan;

  /// No description provided for @syncTargetCloudLan.
  ///
  /// In zh, this message translates to:
  /// **'云同步 + 局域网'**
  String get syncTargetCloudLan;

  /// No description provided for @lastSyncNever.
  ///
  /// In zh, this message translates to:
  /// **'最近成功：尚未同步'**
  String get lastSyncNever;

  /// No description provided for @lastSyncAt.
  ///
  /// In zh, this message translates to:
  /// **'最近成功：{time}'**
  String lastSyncAt(String time);

  /// No description provided for @lastSyncError.
  ///
  /// In zh, this message translates to:
  /// **'最近失败：{error}'**
  String lastSyncError(String error);

  /// No description provided for @signOut.
  ///
  /// In zh, this message translates to:
  /// **'退出'**
  String get signOut;

  /// No description provided for @syncNow.
  ///
  /// In zh, this message translates to:
  /// **'立即同步'**
  String get syncNow;

  /// No description provided for @versionUpdate.
  ///
  /// In zh, this message translates to:
  /// **'版本更新'**
  String get versionUpdate;

  /// No description provided for @versionUpdateHint.
  ///
  /// In zh, this message translates to:
  /// **'检查是否有新的 TimeTrack 版本，并打开对应下载页。'**
  String get versionUpdateHint;

  /// No description provided for @currentVersion.
  ///
  /// In zh, this message translates to:
  /// **'当前版本'**
  String get currentVersion;

  /// No description provided for @latestVersion.
  ///
  /// In zh, this message translates to:
  /// **'最新版本'**
  String get latestVersion;

  /// No description provided for @versionUnknown.
  ///
  /// In zh, this message translates to:
  /// **'未知'**
  String get versionUnknown;

  /// No description provided for @updateStatusIdle.
  ///
  /// In zh, this message translates to:
  /// **'尚未检查'**
  String get updateStatusIdle;

  /// No description provided for @updateStatusChecking.
  ///
  /// In zh, this message translates to:
  /// **'正在检查更新...'**
  String get updateStatusChecking;

  /// No description provided for @updateStatusUpToDate.
  ///
  /// In zh, this message translates to:
  /// **'已是最新版本'**
  String get updateStatusUpToDate;

  /// No description provided for @updateStatusAvailable.
  ///
  /// In zh, this message translates to:
  /// **'有可用更新'**
  String get updateStatusAvailable;

  /// No description provided for @updateStatusFailed.
  ///
  /// In zh, this message translates to:
  /// **'更新检查失败'**
  String get updateStatusFailed;

  /// No description provided for @updateErrorLabel.
  ///
  /// In zh, this message translates to:
  /// **'错误：{error}'**
  String updateErrorLabel(String error);

  /// No description provided for @checkUpdates.
  ///
  /// In zh, this message translates to:
  /// **'检查更新'**
  String get checkUpdates;

  /// No description provided for @openDownloadPage.
  ///
  /// In zh, this message translates to:
  /// **'打开下载页'**
  String get openDownloadPage;

  /// No description provided for @updateAvailablePrompt.
  ///
  /// In zh, this message translates to:
  /// **'TimeTrack {version} 已可用。'**
  String updateAvailablePrompt(String version);

  /// No description provided for @viewInSettings.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get viewInSettings;

  /// No description provided for @deviceInterop.
  ///
  /// In zh, this message translates to:
  /// **'设备互通'**
  String get deviceInterop;

  /// No description provided for @deviceInteropHint.
  ///
  /// In zh, this message translates to:
  /// **'同一 Wi-Fi 下可通过局域网或文件互通数据。'**
  String get deviceInteropHint;

  /// No description provided for @interopSecurityNotice.
  ///
  /// In zh, this message translates to:
  /// **'导出的文件是明文 JSON；局域网同步请只在可信 Wi-Fi 使用，移除配对会清除此设备保存的主机令牌。'**
  String get interopSecurityNotice;

  /// No description provided for @importFile.
  ///
  /// In zh, this message translates to:
  /// **'导入文件'**
  String get importFile;

  /// No description provided for @exportFile.
  ///
  /// In zh, this message translates to:
  /// **'导出文件'**
  String get exportFile;

  /// No description provided for @lanHost.
  ///
  /// In zh, this message translates to:
  /// **'局域网主机'**
  String get lanHost;

  /// No description provided for @lanHostWaiting.
  ///
  /// In zh, this message translates to:
  /// **'正在等待同网段设备连接。'**
  String get lanHostWaiting;

  /// No description provided for @lanHostWindowsNote.
  ///
  /// In zh, this message translates to:
  /// **'v1 默认 Windows 作为局域网主机；Android 作为客户端连接电脑。'**
  String get lanHostWindowsNote;

  /// No description provided for @lanHostAndroidNote.
  ///
  /// In zh, this message translates to:
  /// **'在 Android 上输入下方地址和配对码。'**
  String get lanHostAndroidNote;

  /// No description provided for @lanHostStartNote.
  ///
  /// In zh, this message translates to:
  /// **'开启后，其他设备可在同一 Wi-Fi 内配对。'**
  String get lanHostStartNote;

  /// No description provided for @pairingCodeLabel.
  ///
  /// In zh, this message translates to:
  /// **'配对码：{code}'**
  String pairingCodeLabel(String code);

  /// No description provided for @windowsOnly.
  ///
  /// In zh, this message translates to:
  /// **'仅 Windows 可开启'**
  String get windowsOnly;

  /// No description provided for @stopHost.
  ///
  /// In zh, this message translates to:
  /// **'关闭主机'**
  String get stopHost;

  /// No description provided for @startHost.
  ///
  /// In zh, this message translates to:
  /// **'开启主机'**
  String get startHost;

  /// No description provided for @connectLanHost.
  ///
  /// In zh, this message translates to:
  /// **'连接局域网主机'**
  String get connectLanHost;

  /// No description provided for @connectLanHostHint.
  ///
  /// In zh, this message translates to:
  /// **'输入地址和配对码后会立即尝试同步。'**
  String get connectLanHostHint;

  /// No description provided for @pairedWith.
  ///
  /// In zh, this message translates to:
  /// **'已配对：{name}'**
  String pairedWith(String name);

  /// No description provided for @removePairing.
  ///
  /// In zh, this message translates to:
  /// **'移除配对'**
  String get removePairing;

  /// No description provided for @hostAddress.
  ///
  /// In zh, this message translates to:
  /// **'主机地址'**
  String get hostAddress;

  /// No description provided for @hostHint.
  ///
  /// In zh, this message translates to:
  /// **'192.168.1.10:8787'**
  String get hostHint;

  /// No description provided for @pairingCodeInput.
  ///
  /// In zh, this message translates to:
  /// **'配对码'**
  String get pairingCodeInput;

  /// No description provided for @pairAndSync.
  ///
  /// In zh, this message translates to:
  /// **'配对并同步'**
  String get pairAndSync;

  /// No description provided for @multiDeviceSync.
  ///
  /// In zh, this message translates to:
  /// **'多设备同步'**
  String get multiDeviceSync;

  /// No description provided for @multiDeviceSyncHint.
  ///
  /// In zh, this message translates to:
  /// **'本地记录始终可用，登录后再同步到云端。'**
  String get multiDeviceSyncHint;

  /// No description provided for @emailLabel.
  ///
  /// In zh, this message translates to:
  /// **'邮箱'**
  String get emailLabel;

  /// No description provided for @sending.
  ///
  /// In zh, this message translates to:
  /// **'发送中'**
  String get sending;

  /// No description provided for @sendCode.
  ///
  /// In zh, this message translates to:
  /// **'发送验证码'**
  String get sendCode;

  /// No description provided for @emailCode.
  ///
  /// In zh, this message translates to:
  /// **'邮箱验证码'**
  String get emailCode;

  /// No description provided for @verifying.
  ///
  /// In zh, this message translates to:
  /// **'验证中'**
  String get verifying;

  /// No description provided for @verifyLogin.
  ///
  /// In zh, this message translates to:
  /// **'验证登录'**
  String get verifyLogin;

  /// No description provided for @sendFailed.
  ///
  /// In zh, this message translates to:
  /// **'发送失败：{error}'**
  String sendFailed(String error);

  /// No description provided for @verifyFailed.
  ///
  /// In zh, this message translates to:
  /// **'验证失败：{error}'**
  String verifyFailed(String error);

  /// No description provided for @exported.
  ///
  /// In zh, this message translates to:
  /// **'已导出'**
  String get exported;

  /// No description provided for @imported.
  ///
  /// In zh, this message translates to:
  /// **'已导入'**
  String get imported;

  /// No description provided for @operationFailed.
  ///
  /// In zh, this message translates to:
  /// **'操作失败'**
  String get operationFailed;

  /// No description provided for @interopStatus.
  ///
  /// In zh, this message translates to:
  /// **'互通状态'**
  String get interopStatus;

  /// No description provided for @failed.
  ///
  /// In zh, this message translates to:
  /// **'失败'**
  String get failed;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
