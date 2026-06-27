import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:timetrack/core/app_version.dart';
import 'package:timetrack/data/app_update_service.dart';

void main() {
  group('AppUpdateService', () {
    test('selects newer prerelease and preferred Android APK asset', () async {
      final service = AppUpdateService(
        client: _FakeClient((request) async {
          return http.Response(
            jsonEncode([
              _release(
                tagName: 'v0.2.0-pre',
                prerelease: true,
                assets: [
                  _asset(
                    name: 'timetrack-windows-pre0.2.zip',
                    url: 'https://example.com/windows.zip',
                  ),
                  _asset(
                    name: 'timetrack-android-pre0.2.apk',
                    url: 'https://example.com/app.apk',
                  ),
                ],
              ),
            ]),
            200,
          );
        }),
        releasesUri: Uri.parse('https://example.com/releases'),
      );

      final result = await service.checkForUpdate(
        currentVersion: AppVersion.parse('0.1.0-pre'),
        platform: TargetPlatform.android,
      );

      final info = result.fold(
        onSuccess: (value) => value,
        onFailure: (message) => fail(message),
      );
      expect(info, isNotNull);
      expect(info!.latestVersion, AppVersion.parse('0.2.0-pre'));
      expect(info.downloadUrl, Uri.parse('https://example.com/app.apk'));
      expect(info.pageUrl, Uri.parse('https://example.com/v0.2.0-pre'));
    });

    test('selects Windows assets by extension priority', () async {
      final service = AppUpdateService(
        client: _FakeClient((request) async {
          return http.Response(
            jsonEncode([
              _release(
                tagName: 'v0.2.0-pre',
                prerelease: true,
                assets: [
                  _asset(
                    name: 'timetrack-windows-pre0.2.exe',
                    url: 'https://example.com/windows.exe',
                  ),
                  _asset(
                    name: 'timetrack-windows-pre0.2.msix',
                    url: 'https://example.com/windows.msix',
                  ),
                  _asset(
                    name: 'timetrack-windows-pre0.2.zip',
                    url: 'https://example.com/windows.zip',
                  ),
                ],
              ),
            ]),
            200,
          );
        }),
        releasesUri: Uri.parse('https://example.com/releases'),
      );

      final result = await service.checkForUpdate(
        currentVersion: AppVersion.parse('0.1.0-pre'),
        platform: TargetPlatform.windows,
      );

      final info = result.fold(
        onSuccess: (value) => value,
        onFailure: (message) => fail(message),
      );
      expect(info, isNotNull);
      expect(info!.downloadUrl, Uri.parse('https://example.com/windows.zip'));
    });

    test('ignores draft releases and stable current builds ignore prereleases',
        () async {
      final service = AppUpdateService(
        client: _FakeClient((request) async {
          return http.Response(
            jsonEncode([
              _release(tagName: 'v0.3.0-pre', draft: true, prerelease: true),
              _release(tagName: 'v0.2.1-pre', prerelease: true),
              _release(tagName: 'v0.2.0', prerelease: false),
            ]),
            200,
          );
        }),
        releasesUri: Uri.parse('https://example.com/releases'),
      );

      final result = await service.checkForUpdate(
        currentVersion: AppVersion.parse('0.2.0'),
        platform: TargetPlatform.windows,
      );

      final info = result.fold(
        onSuccess: (value) => value,
        onFailure: (message) => fail(message),
      );
      expect(info, isNull);
    });

    test('falls back to release page when no platform asset matches', () async {
      final service = AppUpdateService(
        client: _FakeClient((request) async {
          return http.Response(
            jsonEncode([
              _release(
                tagName: '0.2.0-pre',
                prerelease: true,
                assets: [
                  _asset(name: 'notes.txt', url: 'https://example.com/notes'),
                ],
              ),
            ]),
            200,
          );
        }),
        releasesUri: Uri.parse('https://example.com/releases'),
      );

      final result = await service.checkForUpdate(
        currentVersion: AppVersion.parse('0.1.0-pre'),
        platform: TargetPlatform.windows,
      );

      final info = result.fold(
        onSuccess: (value) => value,
        onFailure: (message) => fail(message),
      );
      expect(info, isNotNull);
      expect(info!.downloadUrl, info.pageUrl);
    });

    test('falls back to release page when Windows asset has no platform marker',
        () async {
      final service = AppUpdateService(
        client: _FakeClient((request) async {
          return http.Response(
            jsonEncode([
              _release(
                tagName: '0.2.0-pre',
                prerelease: true,
                assets: [
                  _asset(
                    name: 'timetrack-0.2.0-pre.zip',
                    url: 'https://example.com/generic.zip',
                  ),
                ],
              ),
            ]),
            200,
          );
        }),
        releasesUri: Uri.parse('https://example.com/releases'),
      );

      final result = await service.checkForUpdate(
        currentVersion: AppVersion.parse('0.1.0-pre'),
        platform: TargetPlatform.windows,
      );

      final info = result.fold(
        onSuccess: (value) => value,
        onFailure: (message) => fail(message),
      );
      expect(info, isNotNull);
      expect(info!.downloadUrl, info.pageUrl);
    });

    test('requires HTTPS releases URL', () {
      expect(
        () => AppUpdateService(
          releasesUri: Uri.parse('http://example.com/releases'),
        ),
        throwsArgumentError,
      );
    });

    test('ignores unsafe release and asset URLs', () async {
      final service = AppUpdateService(
        client: _FakeClient((request) async {
          return http.Response(
            jsonEncode([
              _release(
                tagName: 'v0.3.0-pre',
                prerelease: true,
                htmlUrl: 'file:///tmp/release',
              ),
              _release(
                tagName: 'v0.2.0-pre',
                prerelease: true,
                assets: [
                  _asset(
                    name: 'timetrack-android-pre0.2.apk',
                    url: 'ms-appinstaller://example.com/app.apk',
                  ),
                ],
              ),
            ]),
            200,
          );
        }),
        releasesUri: Uri.parse('https://example.com/releases'),
      );

      final result = await service.checkForUpdate(
        currentVersion: AppVersion.parse('0.1.0-pre'),
        platform: TargetPlatform.android,
      );

      final info = result.fold(
        onSuccess: (value) => value,
        onFailure: (message) => fail(message),
      );
      expect(info, isNotNull);
      expect(info!.latestVersion, AppVersion.parse('0.2.0-pre'));
      expect(info.downloadUrl, info.pageUrl);
    });

    test('returns failure for bad status, network errors, and invalid JSON',
        () async {
      final forbidden = AppUpdateService(
        client: _FakeClient((request) async => http.Response('nope', 403)),
        releasesUri: Uri.parse('https://example.com/releases'),
      );

      final statusResult = await forbidden.checkForUpdate(
        currentVersion: AppVersion.parse('0.1.0-pre'),
        platform: TargetPlatform.android,
      );

      expect(
        statusResult.fold(
          onSuccess: (_) => null,
          onFailure: (message) => message,
        ),
        contains('403'),
      );

      final networkFailure = AppUpdateService(
        client: _FakeClient((request) async => throw Exception('offline')),
        releasesUri: Uri.parse('https://example.com/releases'),
      );

      final networkResult = await networkFailure.checkForUpdate(
        currentVersion: AppVersion.parse('0.1.0-pre'),
        platform: TargetPlatform.android,
      );

      expect(
        networkResult.fold(
          onSuccess: (_) => null,
          onFailure: (message) => message,
        ),
        contains('offline'),
      );

      final invalidJson = AppUpdateService(
        client: _FakeClient((request) async => http.Response('not json', 200)),
        releasesUri: Uri.parse('https://example.com/releases'),
      );

      final jsonResult = await invalidJson.checkForUpdate(
        currentVersion: AppVersion.parse('0.1.0-pre'),
        platform: TargetPlatform.android,
      );

      expect(
        jsonResult.fold(
          onSuccess: (_) => null,
          onFailure: (message) => message,
        ),
        contains('Invalid'),
      );
    });

    test('normalizes transport failures without exposing exception details',
        () async {
      final failures = <Object>[
        const HandshakeException('CERTIFICATE_VERIFY_FAILED'),
        const SocketException('offline'),
        http.ClientException('connection closed'),
      ];

      for (final failure in failures) {
        final service = AppUpdateService(
          client: _FakeClient((request) async => throw failure),
          releasesUri: Uri.parse('https://example.com/releases'),
        );

        final result = await service.checkForUpdate(
          currentVersion: AppVersion.parse('0.1.0-pre'),
          platform: TargetPlatform.android,
        );

        final message = result.fold(
          onSuccess: (_) => fail('Expected update check to fail.'),
          onFailure: (message) => message,
        );
        expect(message, contains('Unable to reach the update server'));
        expect(message, isNot(contains(failure.runtimeType.toString())));
        expect(message, isNot(contains('CERTIFICATE_VERIFY_FAILED')));
        expect(message, isNot(contains('offline')));
        expect(message, isNot(contains('connection closed')));
      }
    });
  });
}

Map<String, Object?> _release({
  required String tagName,
  bool draft = false,
  bool prerelease = false,
  String? htmlUrl,
  List<Map<String, Object?>> assets = const [],
}) {
  return {
    'tag_name': tagName,
    'name': 'TimeTrack $tagName',
    'body': 'Release notes for $tagName',
    'html_url': htmlUrl ?? 'https://example.com/$tagName',
    'draft': draft,
    'prerelease': prerelease,
    'assets': assets,
  };
}

Map<String, Object?> _asset({
  required String name,
  required String url,
}) {
  return {
    'name': name,
    'browser_download_url': url,
  };
}

class _FakeClient extends http.BaseClient {
  _FakeClient(this._handler);

  final FutureOr<http.Response> Function(http.BaseRequest request) _handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await _handler(request);
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
      reasonPhrase: response.reasonPhrase,
      request: request,
    );
  }
}
