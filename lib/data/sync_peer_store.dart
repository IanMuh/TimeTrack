import 'package:sqflite/sqflite.dart';

import 'local_database.dart';

enum SyncPeerKind {
  lanClient('lan_client'),
  lanAuthorizedClient('lan_authorized_client');

  const SyncPeerKind(this.storageValue);

  final String storageValue;
}

class SyncPeer {
  const SyncPeer({
    required this.id,
    required this.kind,
    required this.displayName,
    required this.baseUrl,
    required this.token,
    required this.updatedAt,
  });

  final String id;
  final SyncPeerKind kind;
  final String displayName;
  final String? baseUrl;
  final String token;
  final DateTime updatedAt;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'kind': kind.storageValue,
      'display_name': displayName,
      'base_url': baseUrl,
      'token': token,
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  static SyncPeer fromMap(Map<String, Object?> map) {
    return SyncPeer(
      id: map['id'] as String,
      kind: SyncPeerKind.values.firstWhere(
        (kind) => kind.storageValue == map['kind'],
      ),
      displayName: map['display_name'] as String,
      baseUrl: map['base_url'] as String?,
      token: map['token'] as String,
      updatedAt: DateTime.parse(map['updated_at'] as String).toLocal(),
    );
  }
}

class SyncPeerStore {
  SyncPeerStore({required LocalDatabase database}) : _database = database;

  final LocalDatabase _database;

  Future<SyncPeer?> currentLanClientPeer() async {
    final db = await _database.db;
    final rows = await db.query(
      'sync_peers',
      where: 'kind = ?',
      whereArgs: [SyncPeerKind.lanClient.storageValue],
      orderBy: 'updated_at desc',
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return SyncPeer.fromMap(rows.first);
  }

  Future<void> savePeer(SyncPeer peer) async {
    final db = await _database.db;
    await db.insert(
      'sync_peers',
      peer.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> clearLanClientPeer() async {
    final db = await _database.db;
    await db.delete(
      'sync_peers',
      where: 'kind = ?',
      whereArgs: [SyncPeerKind.lanClient.storageValue],
    );
  }

  Future<bool> isAuthorizedLanToken(String token) async {
    final db = await _database.db;
    final rows = await db.query(
      'sync_peers',
      where: 'kind = ? and token = ?',
      whereArgs: [SyncPeerKind.lanAuthorizedClient.storageValue, token],
      limit: 1,
    );
    return rows.isNotEmpty;
  }
}
