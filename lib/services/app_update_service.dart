import 'package:cloud_firestore/cloud_firestore.dart';

/// Remote "is there a newer version?" config, read from `app_config/app`.
/// The owner edits this doc (e.g. from the admin app or the Firebase console)
/// to push an in-app update notice without shipping new code.
///
///   enabled      bool    master switch for the notice
///   latestBuild  int     newest build number available (soft update if > current)
///   minBuild     int     oldest still-supported build (forced update if > current)
///   message      string  Hebrew text shown in the dialog
///   androidUrl   string  Play Store listing URL
///   iosUrl       string  App Store listing URL
class AppUpdateInfo {
  final bool enabled;
  final int latestBuild;
  final int minBuild;
  final String message;
  final String androidUrl;
  final String iosUrl;

  const AppUpdateInfo({
    required this.enabled,
    required this.latestBuild,
    required this.minBuild,
    required this.message,
    required this.androidUrl,
    required this.iosUrl,
  });

  factory AppUpdateInfo.fromMap(Map<String, dynamic> data) {
    int asInt(Object? v) => (v as num?)?.toInt() ?? 0;
    return AppUpdateInfo(
      enabled: (data['enabled'] as bool?) ?? false,
      latestBuild: asInt(data['latestBuild']),
      minBuild: asInt(data['minBuild']),
      message: (data['message'] as String?) ?? 'גרסה חדשה זמינה. מומלץ לעדכן.',
      androidUrl: (data['androidUrl'] as String?) ?? '',
      iosUrl: (data['iosUrl'] as String?) ?? '',
    );
  }
}

class AppUpdateService {
  /// Reads the remote update config. Returns null on any error or if the doc
  /// doesn't exist — the caller then simply shows nothing (fail-safe).
  Future<AppUpdateInfo?> fetch() async {
    try {
      final snap =
          await FirebaseFirestore.instance.doc('app_config/app').get();
      final data = snap.data();
      if (!snap.exists || data == null) return null;
      return AppUpdateInfo.fromMap(data);
    } catch (_) {
      return null;
    }
  }
}
