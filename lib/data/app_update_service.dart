import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../core/app_version.dart';
import '../core/result.dart';

enum AppUpdateStatus {
  idle,
  checking,
  upToDate,
  available,
  failed,
}

class AppUpdateInfo {
  const AppUpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.releaseName,
    required this.releaseNotes,
    required this.pageUrl,
    required this.downloadUrl,
    required this.isPrerelease,
  });

  final AppVersion currentVersion;
  final AppVersion latestVersion;
  final String releaseName;
  final String releaseNotes;
  final Uri pageUrl;
  final Uri downloadUrl;
  final bool isPrerelease;
}

typedef UpdateUrlLauncher = Future<bool> Function(Uri uri);

class AppUpdateService {
  AppUpdateService({
    http.Client? client,
    Uri? releasesUri,
    Duration timeout = const Duration(seconds: 8),
    UpdateUrlLauncher? launcher,
    bool enabled = true,
  })  : _client = client ?? http.Client(),
        _releasesUri = _requireHttpsUri(releasesUri ?? defaultReleasesUri),
        _timeout = timeout,
        _launcher = launcher ?? _launchExternal,
        _enabled = enabled;

  AppUpdateService.disabled()
      : _client = http.Client(),
        _releasesUri = defaultReleasesUri,
        _timeout = const Duration(seconds: 8),
        _launcher = _launchExternal,
        _enabled = false;

  static final defaultReleasesUri =
      Uri.parse('https://api.github.com/repos/IanMuh/TimeTrack/releases');
  static const _networkFailureMessage =
      'Unable to reach the update server. Check your network connection and system certificate settings.';

  final http.Client _client;
  final Uri _releasesUri;
  final Duration _timeout;
  final UpdateUrlLauncher _launcher;
  final bool _enabled;

  bool get isEnabled => _enabled;

  Future<AppResult<AppUpdateInfo?>> checkForUpdate({
    required AppVersion currentVersion,
    required TargetPlatform platform,
  }) async {
    if (!_enabled) {
      return const AppSuccess(null);
    }

    try {
      final response = await _client.get(
        _releasesUri,
        headers: const {
          'Accept': 'application/vnd.github+json',
          'X-GitHub-Api-Version': '2022-11-28',
          'User-Agent': 'TimeTrack',
        },
      ).timeout(_timeout);
      if (response.statusCode != 200) {
        return AppFailure('Update check failed: HTTP ${response.statusCode}.');
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! List<Object?>) {
        return const AppFailure(
            'Invalid update response: expected release list.');
      }

      final candidates = <AppUpdateInfo>[];
      for (final item in decoded) {
        if (item is! Map<String, Object?>) {
          continue;
        }
        final info = _releaseInfoFromJson(
          item,
          currentVersion: currentVersion,
          platform: platform,
        );
        if (info != null &&
            _compareVersionsForUpdate(info.latestVersion, currentVersion) > 0) {
          candidates.add(info);
        }
      }
      if (candidates.isEmpty) {
        return const AppSuccess(null);
      }
      candidates.sort((left, right) => _compareVersionsForUpdate(
            right.latestVersion,
            left.latestVersion,
          ));
      return AppSuccess(candidates.first);
    } on TimeoutException {
      return const AppFailure('Update check timed out.');
    } on HandshakeException {
      return const AppFailure(_networkFailureMessage);
    } on SocketException {
      return const AppFailure(_networkFailureMessage);
    } on http.ClientException {
      return const AppFailure(_networkFailureMessage);
    } on IOException {
      return const AppFailure(_networkFailureMessage);
    } on FormatException catch (error) {
      return AppFailure('Invalid update response: ${error.message}.');
    } catch (error) {
      return AppFailure('Update check failed: $error');
    }
  }

  Future<AppResult<bool>> openDownload(AppUpdateInfo update) async {
    final opened = await _launcher(update.downloadUrl);
    if (opened) {
      return const AppSuccess(true);
    }
    return const AppFailure('Unable to open update download page.');
  }

  AppUpdateInfo? _releaseInfoFromJson(
    Map<String, Object?> json, {
    required AppVersion currentVersion,
    required TargetPlatform platform,
  }) {
    if (json['draft'] == true) {
      return null;
    }
    final isPrerelease = json['prerelease'] == true;
    if (isPrerelease && !currentVersion.isPrerelease) {
      return null;
    }

    final tagName = json['tag_name'];
    final pageUrlValue = json['html_url'];
    if (tagName is! String || pageUrlValue is! String) {
      return null;
    }
    final pageUrl = _httpsUri(pageUrlValue);
    if (pageUrl == null) {
      return null;
    }

    late final AppVersion latestVersion;
    try {
      latestVersion = AppVersion.parse(tagName);
    } on FormatException {
      return null;
    }

    final releaseNotes = _stringValue(json['body']) ?? '';
    final releaseVersion =
        _releaseNotesVersionForUpdate(releaseNotes, latestVersion) ??
            latestVersion;
    final assets = json['assets'] is List<Object?>
        ? json['assets'] as List<Object?>
        : const <Object?>[];
    return AppUpdateInfo(
      currentVersion: currentVersion,
      latestVersion: releaseVersion,
      releaseName: _stringValue(json['name']) ?? tagName,
      releaseNotes: releaseNotes,
      pageUrl: pageUrl,
      downloadUrl: _downloadUrlFor(platform, assets) ?? pageUrl,
      isPrerelease: isPrerelease,
    );
  }

  Uri? _downloadUrlFor(TargetPlatform platform, List<Object?> assets) {
    final parsedAssets = [
      for (final asset in assets)
        if (asset is Map<String, Object?>) _ReleaseAsset.fromJson(asset),
    ].whereType<_ReleaseAsset>().toList();
    if (parsedAssets.isEmpty) {
      return null;
    }

    final matches = switch (platform) {
      TargetPlatform.android => _androidAssets(parsedAssets),
      TargetPlatform.windows => _windowsAssets(parsedAssets),
      _ => const <_ReleaseAsset>[],
    };
    if (matches.isEmpty) {
      return null;
    }
    return matches.first.url;
  }

  List<_ReleaseAsset> _androidAssets(List<_ReleaseAsset> assets) {
    final apkAssets = [
      for (final asset in assets)
        if (asset.name.toLowerCase().endsWith('.apk')) asset,
    ];
    return [
      ...apkAssets
          .where((asset) => asset.name.toLowerCase().contains('android')),
      ...apkAssets
          .where((asset) => !asset.name.toLowerCase().contains('android')),
    ];
  }

  List<_ReleaseAsset> _windowsAssets(List<_ReleaseAsset> assets) {
    const extensions = ['.zip', '.msix', '.exe'];
    return [
      for (final extension in extensions)
        ...assets.where((asset) {
          final name = asset.name.toLowerCase();
          return name.endsWith(extension) && _isWindowsAssetName(name);
        }),
    ];
  }

  static bool _isWindowsAssetName(String name) {
    return name.contains('windows') ||
        name.contains('win') ||
        name.contains('x64');
  }

  static int _compareVersionsForUpdate(AppVersion left, AppVersion right) {
    final semanticCompare = left.compareTo(right);
    if (semanticCompare != 0) {
      return semanticCompare;
    }
    return _compareBuildMetadataForUpdate(
      left.buildMetadata,
      right.buildMetadata,
    );
  }

  static int _compareBuildMetadataForUpdate(String? left, String? right) {
    if (left == null || left.isEmpty) {
      return right == null || right.isEmpty ? 0 : -1;
    }
    if (right == null || right.isEmpty) {
      return 1;
    }

    final leftParts = left.split('.');
    final rightParts = right.split('.');
    final length = leftParts.length < rightParts.length
        ? leftParts.length
        : rightParts.length;
    for (var index = 0; index < length; index += 1) {
      final result = _compareBuildMetadataPart(
        leftParts[index],
        rightParts[index],
      );
      if (result != 0) {
        return result;
      }
    }
    return leftParts.length.compareTo(rightParts.length);
  }

  static int _compareBuildMetadataPart(String left, String right) {
    final leftNumber = int.tryParse(left);
    final rightNumber = int.tryParse(right);
    if (leftNumber != null && rightNumber != null) {
      return leftNumber.compareTo(rightNumber);
    }
    return left.compareTo(right);
  }

  static AppVersion? _releaseNotesVersionForUpdate(
    String releaseNotes,
    AppVersion tagVersion,
  ) {
    AppVersion? bestVersion;
    final versionPattern = RegExp(
      r'v?\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?\+[0-9A-Za-z.-]+',
    );
    for (final match in versionPattern.allMatches(releaseNotes)) {
      final value = match.group(0);
      if (value == null) {
        continue;
      }
      final parsed = _tryParseVersion(value);
      if (parsed == null || parsed.compareTo(tagVersion) != 0) {
        continue;
      }
      if (_compareVersionsForUpdate(parsed, tagVersion) <= 0) {
        continue;
      }
      if (bestVersion == null ||
          _compareVersionsForUpdate(parsed, bestVersion) > 0) {
        bestVersion = parsed;
      }
    }
    return bestVersion;
  }

  static AppVersion? _tryParseVersion(String value) {
    try {
      return AppVersion.parse(value);
    } on FormatException {
      return null;
    }
  }

  static Uri? _httpsUri(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        uri.scheme.toLowerCase() != 'https' ||
        uri.host.isEmpty) {
      return null;
    }
    return uri;
  }

  static Uri _requireHttpsUri(Uri uri) {
    if (uri.scheme.toLowerCase() != 'https' || uri.host.isEmpty) {
      throw ArgumentError.value(
        uri,
        'releasesUri',
        'Update releases URL must be an HTTPS URL.',
      );
    }
    return uri;
  }

  static String? _stringValue(Object? value) {
    if (value is String && value.isNotEmpty) {
      return value;
    }
    return null;
  }

  static Future<bool> _launchExternal(Uri uri) {
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _ReleaseAsset {
  const _ReleaseAsset({
    required this.name,
    required this.url,
  });

  final String name;
  final Uri url;

  static _ReleaseAsset? fromJson(Map<String, Object?> json) {
    final name = json['name'];
    final urlValue = json['browser_download_url'];
    if (name is! String || urlValue is! String) {
      return null;
    }
    final url = AppUpdateService._httpsUri(urlValue);
    if (url == null) {
      return null;
    }
    return _ReleaseAsset(name: name, url: url);
  }
}
