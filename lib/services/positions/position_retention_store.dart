import 'package:shared_preferences/shared_preferences.dart';

/// Remembers which position rows the retention rule has already retired.
///
/// Without this the mock book re-seeds on every cold start and yesterday's
/// squared-off rows pop back into the list, which makes the cleanup look like
/// it never ran. The real broker API does its own housekeeping server-side, but
/// the same store keeps this honest while that is still pending.
class PositionRetentionStore {
  const PositionRetentionStore({this.key = 'position_retention.removed'});

  final String key;

  Future<Set<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(key) ?? const <String>[]).toSet();
  }

  Future<void> save(Set<String> removed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(key, removed.toList()..sort());
  }

  /// Drops every remembered id. Used by tests and by a "show everything again"
  /// escape hatch.
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }
}
