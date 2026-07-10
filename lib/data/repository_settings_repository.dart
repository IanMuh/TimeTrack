import '../core/result.dart';
import '../domain/profile_settings.dart';
import 'device_id_store.dart';
import 'repository_result.dart';
import 'settings_repository.dart';

class RepositorySettingsRepository {
  RepositorySettingsRepository({
    required SettingsRepository settingsRepository,
    required DeviceIdStore deviceIdStore,
  })  : _settingsRepo = settingsRepository,
        _deviceIdStore = deviceIdStore;

  final SettingsRepository _settingsRepo;
  final DeviceIdStore _deviceIdStore;

  Future<ProfileSettings> settings() async {
    final result = await _settingsRepo.settings();
    return _unwrap(result);
  }

  Future<void> saveSettings(ProfileSettings settings) async {
    final result = await _settingsRepo.saveSettings(settings);
    _unwrap(result);
  }

  Future<void> replaceSettingsIfRemoteNewer(ProfileSettings remote) async {
    final result = await _settingsRepo.replaceSettingsIfRemoteNewer(remote);
    _unwrap(result);
  }

  Future<String> currentDeviceId() async {
    return _deviceIdStore.currentDeviceId();
  }

  T _unwrap<T>(AppResult<T> result) {
    return unwrapRepositoryResult(result);
  }
}
