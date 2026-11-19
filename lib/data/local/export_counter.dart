/// Counts successful exports per account on this device.
library;

import 'package:shared_preferences/shared_preferences.dart';

const String _legacyExportCount = 'stats.exports.count';

String _key(String userId) {
  if (userId.trim().isEmpty) throw ArgumentError.value(userId, 'userId');
  return 'stats.exports.${Uri.encodeComponent(userId)}.count';
}

/// Reads the number of successful exports recorded on this device.
Future<int> readExportCount(String userId) async {
  final prefs = await SharedPreferences.getInstance();
  // The old device total has no owner, so it cannot safely be assigned to any
  // account. Discard it rather than exposing another/deleted account's count.
  await prefs.remove(_legacyExportCount);
  return prefs.getInt(_key(userId)) ?? 0;
}

/// Increments the export counter after a delivery completed.
Future<void> recordExport(String userId) async {
  final prefs = await SharedPreferences.getInstance();
  final key = _key(userId);
  final next = (prefs.getInt(key) ?? 0) + 1;
  if (!await prefs.setInt(key, next)) {
    throw StateError('Could not save export count');
  }
}

/// Removes only this account's counter after successful account deletion.
Future<void> clearExportCount(String userId) async {
  final prefs = await SharedPreferences.getInstance();
  if (!await prefs.remove(_key(userId))) {
    throw StateError('Could not clear export count');
  }
  await prefs.remove(_legacyExportCount);
}
