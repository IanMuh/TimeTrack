part of 'time_repository.dart';

mixin TimeRepositorySettingsFacade {
  RepositorySettingsRepository get _settingsFacade;

  Future<ProfileSettings> settings() async {
    return _settingsFacade.settings();
  }

  Future<void> saveSettings(ProfileSettings settings) async {
    await _settingsFacade.saveSettings(settings);
  }

  Future<void> replaceSettingsIfRemoteNewer(ProfileSettings remote) async {
    await _settingsFacade.replaceSettingsIfRemoteNewer(remote);
  }

  Future<String> currentDeviceId() async {
    return _settingsFacade.currentDeviceId();
  }
}
