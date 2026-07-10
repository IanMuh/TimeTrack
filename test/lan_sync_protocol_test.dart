import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:timetrack/data/lan_sync_protocol.dart';

void main() {
  test('LAN sync JSON protocol stays outside socket coordination', () {
    final syncSource = File('lib/data/lan_sync.dart').readAsStringSync();
    final protocolFile = File('lib/data/lan_sync_protocol.dart');

    expect(protocolFile.existsSync(), isTrue);

    final protocolSource = protocolFile.readAsStringSync();
    expect(syncSource, contains("export 'lan_sync_protocol.dart';"));
    expect(
      syncSource,
      isNot(contains('LanSyncJsonProtocol _json')),
    );
    expect(syncSource, isNot(contains('jsonDecode')));
    expect(syncSource, isNot(contains('jsonEncode')));
    expect(syncSource, isNot(contains('utf8.decoder.bind')));
    expect(syncSource, isNot(contains('Future<void> _writeJson(')));
    expect(
        syncSource, isNot(contains('Future<Map<String, Object?>> _readJson')));
    expect(protocolSource, contains('class LanSyncJsonProtocol'));
    expect(protocolSource, contains('jsonDecode'));
    expect(protocolSource, contains('jsonEncode'));
    expect(protocolSource, contains('utf8.decoder.bind'));
  });

  test('LAN sync facade exports server and client implementation files', () {
    final facade = File('lib/data/lan_sync.dart');
    final server = File('lib/data/lan_sync_server.dart');
    final client = File('lib/data/lan_sync_client.dart');

    expect(server.existsSync(), isTrue);
    expect(client.existsSync(), isTrue);

    final facadeSource = facade.readAsStringSync();
    final serverSource = server.readAsStringSync();
    final clientSource = client.readAsStringSync();

    expect(facadeSource, contains("export 'lan_sync_server.dart';"));
    expect(facadeSource, contains("export 'lan_sync_client.dart';"));
    expect(facadeSource, contains("export 'lan_sync_protocol.dart';"));
    expect(facadeSource, isNot(contains('class LanSyncServer')));
    expect(facadeSource, isNot(contains('class LanSyncClient')));
    expect(serverSource, contains('class LanSyncServer'));
    expect(serverSource, isNot(contains('class LanSyncClient')));
    expect(clientSource, contains('class LanSyncClient'));
    expect(clientSource, isNot(contains('class LanSyncServer')));
    expect(_pureLineCount(facade), lessThanOrEqualTo(20));
    expect(_pureLineCount(server), lessThanOrEqualTo(250));
    expect(_pureLineCount(client), lessThanOrEqualTo(250));
  });

  test('LAN sync protocol requires JSON object maps', () {
    expect(
      requireLanJsonObject({'ok': true}, 'request'),
      {'ok': true},
    );
    final dynamicObjectMap = <Object?, Object?>{'ok': true};
    expect(
      requireLanJsonObject(dynamicObjectMap, 'request'),
      {'ok': true},
    );
    expect(
      () => requireLanJsonObject(['nope'], 'request'),
      throwsA(isA<FormatException>()),
    );
  });
}

int _pureLineCount(File file) {
  return file.readAsLinesSync().where((line) {
    final trimmed = line.trim();
    return trimmed.isNotEmpty &&
        !trimmed.startsWith('//') &&
        !trimmed.startsWith('#') &&
        !trimmed.startsWith('--');
  }).length;
}
