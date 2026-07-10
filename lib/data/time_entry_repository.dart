import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../core/date_time_ext.dart';
import '../core/result.dart';
import '../domain/action_log.dart';
import '../domain/profile_settings.dart';
import '../domain/time_entry.dart';
import 'activity_repository.dart';
import 'local_database.dart';
import 'repository_interfaces.dart';
import 'time_entry_repository_errors.dart';

part 'time_entry_repository_result_facade.dart';
part 'time_entry_repository_query_logic.dart';
part 'time_entry_repository_storage_logic.dart';
part 'time_entry_repository_support_logic.dart';
part 'time_entry_repository_normalization_logic.dart';
part 'time_entry_repository_command_logic.dart';
part 'time_entry_repository_edit_logic.dart';

typedef TimeEntryClock = DateTime Function();

class TimeEntryRepository
    with
        TimeEntryRepositoryResultFacade,
        TimeEntryRepositoryQueryLogic,
        TimeEntryRepositoryStorageLogic,
        TimeEntryRepositorySupportLogic,
        TimeEntryRepositoryNormalizationLogic,
        TimeEntryRepositoryCommandLogic,
        TimeEntryRepositoryEditLogic
    implements
        ITimeEntryQueryRepository,
        ITimeEntryCommandRepository,
        ITimeEntrySyncRepository {
  TimeEntryRepository({
    required LocalDatabase database,
    required ActivityRepository activityRepository,
    String? deviceId,
    Uuid? uuid,
    TimeEntryClock? clock,
  })  : _database = database,
        _activityRepo = activityRepository,
        _deviceIdOverride = deviceId,
        _uuid = uuid ?? const Uuid(),
        _clock = clock ?? DateTime.now;

  @override
  final LocalDatabase _database;
  @override
  final ActivityRepository _activityRepo;
  @override
  final String? _deviceIdOverride;
  @override
  final Uuid _uuid;
  final TimeEntryClock _clock;
  @override
  String? _cachedDeviceId;

  @override
  DateTime _now() => _clock();
}
