/// Device-local persistence used when Supabase is not configured.
///
/// This keeps the entire product usable offline and makes the domain layer
/// testable. Data is stored as JSON under the app documents directory, keyed by
/// user so multiple accounts on one device stay isolated.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// A tiny JSON-file key/value store.
class LocalStore {
  LocalStore._(this._root);

  final Directory _root;

  /// Root directory of the store, exposed for maintenance operations.
  Directory get rootDirectory => _root;

  static const String _storeDirName = 'cv_portfolio_store';

  /// Opens (creating if needed) the store directory.
  static Future<LocalStore> open() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/$_storeDirName');
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return LocalStore._(dir);
  }

  /// Opens a store rooted at an explicit [dir].
  ///
  /// Used by tests so persistence can be exercised against a temporary
  /// directory without touching the real application documents folder.
  @visibleForTesting
  static LocalStore forDirectory(Directory dir) {
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return LocalStore._(dir);
  }

  File _file(String key) => File('${_root.path}/${_sanitize(key)}.json');

  static String _sanitize(String key) =>
      key.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');

  /// Reads and decodes a JSON list stored under [key].
  Future<List<Map<String, dynamic>>> readList(String key) async {
    final file = _file(key);
    if (!file.existsSync()) return [];
    try {
      final raw = await file.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map<String, dynamic>>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    } on FormatException {
      // A corrupt file must not crash the app; treat it as empty.
      return [];
    }
    return [];
  }

  /// Reads and decodes a JSON map stored under [key].
  Future<Map<String, dynamic>?> readMap(String key) async {
    final items = await readList(key);
    return items.isEmpty ? null : items.first;
  }

  /// Overwrites [key] with [items].
  Future<void> writeList(String key, List<Map<String, dynamic>> items) async {
    final file = _file(key);
    await file.writeAsString(jsonEncode(items), flush: true);
  }

  /// Overwrites [key] with a single map.
  Future<void> writeMap(String key, Map<String, dynamic> value) async {
    await writeList(key, [value]);
  }

  /// Deletes [key].
  Future<void> remove(String key) async {
    final file = _file(key);
    if (file.existsSync()) await file.delete();
  }

  /// Directory used for uploaded media blobs.
  Future<Directory> mediaDir() async {
    final dir = Directory('${_root.path}/media');
    if (!dir.existsSync()) await dir.create(recursive: true);
    return dir;
  }

  /// Wipes every record for a user (account deletion).
  Future<void> removeWherePrefix(String prefix) async {
    if (!_root.existsSync()) return;
    await for (final entity in _root.list()) {
      if (entity is File &&
          entity.uri.pathSegments.last.startsWith(_sanitize(prefix))) {
        await entity.delete();
      }
    }
  }
}
