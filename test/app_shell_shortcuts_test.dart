import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timetrack/app/app_state.dart';
import 'package:timetrack/data/file_interop_service.dart';
import 'package:timetrack/data/lan_sync.dart';
import 'package:timetrack/data/local_database.dart';
import 'package:timetrack/data/sync_peer_store.dart';
import 'package:timetrack/data/sync_service.dart';
import 'package:timetrack/data/time_repository.dart';
import 'package:timetrack/domain/activity.dart';
import 'package:timetrack/domain/time_entry.dart';
import 'package:timetrack/ui/app_shell.dart';

class _ShellTestState extends AppState {
  _ShellTestState()
      : super(
          repository: _repository,
          syncService: SyncService(repository: _repository, client: null),
          lanSyncServer: LanSyncServer(
            repository: _repository,
            peerStore: _peerStore,
            portCandidates: const [0],
          ),
          lanSyncClient:
              LanSyncClient(repository: _repository, peerStore: _peerStore),
          fileInteropService: FileInteropService(repository: _repository),
        ) {
    isLoading = false;
    now = DateTime(2026, 1, 1, 12);
    selectedDay = DateTime(2026, 1, 1);
    activities = [
      Activity(
        id: 'work',
        userId: null,
        name: '工作',
        color: 0xff2563eb,
        isFavorite: true,
        updatedAt: now,
        isDeleted: false,
      ),
      Activity(
        id: 'unassigned',
        userId: null,
        name: '未安排',
        color: 0xff64748b,
        isFavorite: false,
        updatedAt: now,
        isDeleted: false,
        isUnassigned: true,
      ),
    ];
  }

  static final _database = LocalDatabase();
  static final _repository = TimeRepository(database: _database);
  static final _peerStore = SyncPeerStore(database: _database);

  var undoCount = 0;
  var redoCount = 0;
  var manualEntryDialogOpened = false;
  bool _canUndo = false;
  bool _canRedo = false;
  String? _undoLabel;
  String? _redoLabel;

  void setHistory({
    required bool canUndo,
    required bool canRedo,
    String? undoLabel,
    String? redoLabel,
  }) {
    _canUndo = canUndo;
    _canRedo = canRedo;
    _undoLabel = undoLabel;
    _redoLabel = redoLabel;
    notifyListeners();
  }

  @override
  bool get canUndo => _canUndo;

  @override
  bool get canRedo => _canRedo;

  @override
  String? get undoLabel => _undoLabel;

  @override
  String? get redoLabel => _redoLabel;

  @override
  bool get canHostLan => false;

  @override
  bool get hasSyncTarget => false;

  @override
  bool get shouldShowReminderDialog => false;

  @override
  bool get shouldShowReminderBanner => false;

  @override
  bool get hasSuspiciousRunningEntry => false;

  @override
  Future<void> undo() async {
    undoCount += 1;
    _canUndo = false;
    _canRedo = true;
    _redoLabel = _undoLabel;
    _undoLabel = null;
    notifyListeners();
  }

  @override
  Future<void> redo() async {
    redoCount += 1;
    _canUndo = true;
    _canRedo = false;
    _undoLabel = _redoLabel;
    _redoLabel = null;
    notifyListeners();
  }

  @override
  Future<void> selectDay(DateTime day) async {
    selectedDay = day;
    notifyListeners();
  }

  @override
  Future<List<Activity>> entryActivityChoices() async {
    return activities.where((activity) => !activity.isUnassigned).toList();
  }

  @override
  Future<List<Activity>> oneOffActivitySuggestions() async => const [];

  @override
  Future<List<TimeEntry>> overlaps(TimeEntry entry) async => const [];

  @override
  Future<void> createManualEntry({
    required String activityId,
    required DateTime startAt,
    required DateTime endAt,
    required String note,
  }) async {
    manualEntryDialogOpened = true;
    notifyListeners();
  }
}

Future<void> _pumpShell(
  WidgetTester tester,
  _ShellTestState state, {
  required double width,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(home: AppShell(state: state)));
  await tester.pump();
}

Future<void> _pumpShortcutFrame(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 80));
}

Finder _historyButton(String tooltipPrefix) {
  return find.byWidgetPredicate(
    (widget) =>
        widget is IconButton &&
        (widget.tooltip?.startsWith(tooltipPrefix) ?? false),
  );
}

void main() {
  testWidgets('shell shows undo and redo controls on expanded layout',
      (tester) async {
    final state = _ShellTestState();
    addTearDown(state.dispose);

    await _pumpShell(tester, state, width: 1000);

    expect(find.byTooltip('撤销 Ctrl+Z'), findsOneWidget);
    expect(find.byTooltip('重做 Ctrl+Y'), findsOneWidget);
    expect(tester.widget<IconButton>(_historyButton('撤销')).onPressed, isNull);
    expect(tester.widget<IconButton>(_historyButton('重做')).onPressed, isNull);

    state.setHistory(
      canUndo: true,
      canRedo: true,
      undoLabel: '补记时间段',
      redoLabel: '删除时间段',
    );
    await _pumpShortcutFrame(tester);

    expect(find.byTooltip('撤销：补记时间段 Ctrl+Z'), findsOneWidget);
    expect(find.byTooltip('重做：删除时间段 Ctrl+Y'), findsOneWidget);
  });

  testWidgets('shell shows undo and redo controls on compact layout',
      (tester) async {
    final state = _ShellTestState();
    addTearDown(state.dispose);

    await _pumpShell(tester, state, width: 390);

    expect(find.byTooltip('撤销 Ctrl+Z'), findsOneWidget);
    expect(find.byTooltip('重做 Ctrl+Y'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('undo and redo keyboard shortcuts invoke state actions',
      (tester) async {
    final state = _ShellTestState()
      ..setHistory(canUndo: true, canRedo: false, undoLabel: '补记时间段');
    addTearDown(state.dispose);
    await _pumpShell(tester, state, width: 1000);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await _pumpShortcutFrame(tester);

    expect(state.undoCount, 1);
    expect(state.canRedo, isTrue);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyY);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await _pumpShortcutFrame(tester);

    expect(state.redoCount, 1);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await _pumpShortcutFrame(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await _pumpShortcutFrame(tester);

    expect(state.redoCount, 2);
  });

  testWidgets('undo shortcut does not override focused text editing',
      (tester) async {
    final state = _ShellTestState()
      ..setHistory(canUndo: true, canRedo: false, undoLabel: '补记时间段');
    addTearDown(state.dispose);
    await _pumpShell(tester, state, width: 1000);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await _pumpShortcutFrame(tester);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await _pumpShortcutFrame(tester);

    await tester.enterText(
      find.byKey(const ValueKey('entry-activity-search-field')),
      '新事项',
    );
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await _pumpShortcutFrame(tester);

    expect(state.undoCount, 0);
  });

  testWidgets('destination and timeline shortcuts work', (tester) async {
    final state = _ShellTestState();
    addTearDown(state.dispose);
    await _pumpShell(tester, state, width: 1000);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await _pumpShortcutFrame(tester);
    expect(find.text('时间轴'), findsOneWidget);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await _pumpShortcutFrame(tester);
    expect(state.selectedDay, DateTime(2025, 12, 31));

    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await _pumpShortcutFrame(tester);
    expect(state.selectedDay, DateTime(2026, 1, 1));

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await _pumpShortcutFrame(tester);
    expect(find.widgetWithText(AlertDialog, '补记时间段'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, '取消'));
    await _pumpShortcutFrame(tester);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit4);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await _pumpShortcutFrame(tester);
    expect(find.text('设置'), findsWidgets);
  });
}
