import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/build_info.dart';

/// Persistent QA event log. Events survive app restarts (up to [_maxEvents]).
/// Call [init] once from main() before runApp. Call [log] anywhere.
/// Use [copyToClipboard] from Profile screen to extract the log.
class QaLoggerService {
  QaLoggerService._();
  static final instance = QaLoggerService._();

  static const int _maxEvents = 300;
  static const String _prefKey = 'qa_log_events';

  final List<String> _events = [];
  SharedPreferences? _prefs;
  bool _initialized = false;

  int get eventCount => _events.length;

  String get exportText => _events.isEmpty
      ? '(no QA events recorded)'
      : _events.join('\n');

  Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final stored = _prefs!.getStringList(_prefKey) ?? [];
      _events.addAll(stored);
      while (_events.length > _maxEvents) _events.removeAt(0);
    } catch (_) {}
    _initialized = true;
    log('QA', 'SESSION_START stored=${_events.length - 1} build=$kBuildLabel branch=$kGitBranch version=$kAppVersion');
  }

  void log(String tag, String message) {
    final now = DateTime.now();
    final ts = '${_p2(now.hour)}:${_p2(now.minute)}:${_p2(now.second)}.${_p3(now.millisecond)}';
    final entry = '[$ts] ${tag.padRight(16)} $message';
    if (_events.length >= _maxEvents) _events.removeAt(0);
    _events.add(entry);
    _persist();
  }

  void _persist() {
    if (!_initialized || _prefs == null) return;
    _prefs!.setStringList(_prefKey, List.of(_events)).ignore();
  }

  Future<void> copyToClipboard() async {
    final text = _events.isEmpty
        ? '(no QA events recorded)'
        : '=== QA LOG (${_events.length} events) ===\n${_events.join('\n')}';
    await Clipboard.setData(ClipboardData(text: text));
  }

  void clear() {
    _events.clear();
    _prefs?.remove(_prefKey).ignore();
  }

  static String _p2(int n) => n.toString().padLeft(2, '0');
  static String _p3(int n) => n.toString().padLeft(3, '0');
}
