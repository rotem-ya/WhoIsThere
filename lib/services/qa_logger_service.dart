import 'package:flutter/services.dart';

/// In-memory QA event log. Call [log] anywhere to record an event.
/// Capped at [_maxEvents] entries (oldest dropped). No network, no files.
/// Use [copyToClipboard] from the Profile screen to extract the log manually.
class QaLoggerService {
  QaLoggerService._();
  static final instance = QaLoggerService._();

  static const int _maxEvents = 300;

  final List<String> _events = [];

  int get eventCount => _events.length;

  void log(String tag, String message) {
    final now = DateTime.now();
    final ts = '${_p2(now.hour)}:${_p2(now.minute)}:${_p2(now.second)}.${_p3(now.millisecond)}';
    final entry = '[$ts] ${tag.padRight(16)} $message';
    if (_events.length >= _maxEvents) _events.removeAt(0);
    _events.add(entry);
  }

  Future<void> copyToClipboard() async {
    final text = _events.isEmpty
        ? '(no QA events recorded)'
        : '=== QA LOG (${_events.length} events) ===\n${_events.join('\n')}';
    await Clipboard.setData(ClipboardData(text: text));
  }

  void clear() => _events.clear();

  static String _p2(int n) => n.toString().padLeft(2, '0');
  static String _p3(int n) => n.toString().padLeft(3, '0');
}
