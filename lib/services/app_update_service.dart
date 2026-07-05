import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';

/// One of "our other apps" listed in the "האפליקציות שלנו" screen. Fully
/// admin-controlled via `app_config/app → ourApps` (a list of maps), so new
/// apps can be added without shipping a new build.
///
///   name        string  display name (e.g. "שאלו את הילדים")
///   subtitle    string  short one-line description (optional)
///   emoji       string  leading emoji shown in the row (optional)
///   androidUrl  string  Play Store URL (optional)
///   iosUrl      string  App Store URL (optional)
class OurApp {
  final String name;
  final String subtitle;
  final String emoji;
  final String androidUrl;
  final String iosUrl;

  const OurApp({
    required this.name,
    required this.subtitle,
    required this.emoji,
    required this.androidUrl,
    required this.iosUrl,
  });

  factory OurApp.fromMap(Map<String, dynamic> data) => OurApp(
        name: (data['name'] as String?)?.trim() ?? '',
        subtitle: (data['subtitle'] as String?)?.trim() ?? '',
        emoji: (data['emoji'] as String?)?.trim() ?? '📱',
        androidUrl: (data['androidUrl'] as String?)?.trim() ?? '',
        iosUrl: (data['iosUrl'] as String?)?.trim() ?? '',
      );

  /// The best store URL for the current platform (falls back to the other
  /// platform's URL when only one is set, so a link always works).
  String get storeUrl {
    final primary = Platform.isIOS ? iosUrl : androidUrl;
    final secondary = Platform.isIOS ? androidUrl : iosUrl;
    return primary.isNotEmpty ? primary : secondary;
  }

  bool get hasLink => androidUrl.isNotEmpty || iosUrl.isNotEmpty;
}

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
///   ourApps      list    other apps by us, shown in "האפליקציות שלנו"
class AppUpdateInfo {
  final bool enabled;
  final int latestBuild;
  final int minBuild;
  final String message;
  final String androidUrl;
  final String iosUrl;
  final List<OurApp> ourApps;

  const AppUpdateInfo({
    required this.enabled,
    required this.latestBuild,
    required this.minBuild,
    required this.message,
    required this.androidUrl,
    required this.iosUrl,
    this.ourApps = const [],
  });

  factory AppUpdateInfo.fromMap(Map<String, dynamic> data) {
    int asInt(Object? v) => (v as num?)?.toInt() ?? 0;
    final rawApps = data['ourApps'];
    final apps = <OurApp>[];
    if (rawApps is List) {
      for (final e in rawApps) {
        if (e is Map) {
          final app = OurApp.fromMap(Map<String, dynamic>.from(e));
          if (app.name.isNotEmpty) apps.add(app);
        }
      }
    }
    return AppUpdateInfo(
      enabled: (data['enabled'] as bool?) ?? false,
      latestBuild: asInt(data['latestBuild']),
      minBuild: asInt(data['minBuild']),
      message: (data['message'] as String?) ?? 'גרסה חדשה זמינה. מומלץ לעדכן.',
      androidUrl: (data['androidUrl'] as String?) ?? '',
      iosUrl: (data['iosUrl'] as String?) ?? '',
      ourApps: apps,
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
