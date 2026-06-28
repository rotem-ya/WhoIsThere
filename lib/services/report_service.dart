import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/constants/build_info.dart';
import 'analytics_service.dart';
import 'qa_logger_service.dart';

/// User feedback + automatic crash/error reporting, both written to Firestore
/// for the admin to review. All writes are best-effort and never throw into the
/// caller — a failed report must not break the app or a crash handler.
///
/// (Distinct from `FeedbackService`, which is haptic feedback.)
///
/// Firestore:
///   feedback/{autoId}       — user-submitted feedback
///   crash_reports/{autoId}  — auto-sent on a detected crash/error (throttled)
class ReportService {
  ReportService._();
  static final ReportService instance = ReportService._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  String _platform() {
    try {
      return Platform.operatingSystem;
    } catch (_) {
      return 'unknown';
    }
  }

  String? _uid() {
    try {
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

  // ── User feedback ───────────────────────────────────────────────────────────

  /// Submits free-text feedback. Returns true on success. Capped at 2000 chars.
  Future<bool> submitFeedback({required String text, String? name}) async {
    var body = text.trim();
    if (body.isEmpty) return false;
    if (body.length > 2000) body = body.substring(0, 2000);
    try {
      await _db.collection('feedback').add({
        'uid': _uid(),
        'name': name,
        'text': body,
        // Recent device log — turns "it doesn't work" complaints into
        // diagnosable reports, same as crash_reports carry.
        'log': QaLoggerService.instance.recentLog(),
        'build': kBuildLabel,
        'version': kAppVersion,
        'platform': _platform(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      QaLoggerService.instance.log('FEEDBACK', 'FEEDBACK_SENT len=${body.length}');
      AnalyticsService.instance.feedbackSent();
      return true;
    } catch (e) {
      QaLoggerService.instance.log('FEEDBACK', 'FEEDBACK_FAIL $e');
      return false;
    }
  }

  // ── Automatic crash / error reports ─────────────────────────────────────────

  // Throttle: don't spam Firestore during a crash loop. Cap per session and
  // skip errors we've already reported (by a short signature).
  static const int _maxReportsPerSession = 5;
  final Set<String> _reportedSignatures = {};
  int _reportCount = 0;

  /// Auto-sends a crash/error with the recent QA log attached. Deduped by a
  /// signature of [error] and capped per session. Fire-and-forget, never throws.
  void reportCrash({required String kind, required Object error, StackTrace? stack}) {
    try {
      if (_reportCount >= _maxReportsPerSession) return;
      final msg = error.toString();
      final sig = '$kind:${msg.length > 80 ? msg.substring(0, 80) : msg}';
      if (!_reportedSignatures.add(sig)) return; // already reported this one
      _reportCount++;

      final stackStr = stack?.toString() ?? '';
      _db.collection('crash_reports').add({
        'uid': _uid(),
        'kind': kind, // 'flutter' | 'uncaught'
        'error': msg.length > 1000 ? msg.substring(0, 1000) : msg,
        'stack': stackStr.length > 2000 ? stackStr.substring(0, 2000) : stackStr,
        'log': QaLoggerService.instance.recentLog(),
        'build': kBuildLabel,
        'version': kAppVersion,
        'platform': _platform(),
        'createdAt': FieldValue.serverTimestamp(),
      }).then((_) {
        QaLoggerService.instance.log('CRASH', 'CRASH_REPORT_SENT kind=$kind');
      }).catchError((_) {});
    } catch (_) {
      // Never let crash reporting cause a crash.
    }
  }
}
