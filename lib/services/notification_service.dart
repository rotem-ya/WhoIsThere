import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'qa_logger_service.dart';

/// Top-level background handler — required by firebase_messaging to be a
/// top-level (or static) function. We don't need to do work here (the OS shows
/// the notification from the FCM `notification` payload automatically); this
/// just keeps the isolate registration valid.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Intentionally minimal. The notification is rendered by the system.
}

/// Push-notification plumbing for friend game invites.
///
/// Flow:
///   1. App registers the device's FCM token under
///      `users/{uid}.fcmTokens` (arrayUnion, multi-device safe).
///   2. A Cloud Function (`functions/index.js`) listens on
///      `gameInvites/{id}` onCreate, reads the recipient's tokens and sends
///      the push — so the invite arrives even when the app is closed.
///   3. Tapping the notification opens the app; [onInviteTap] is invoked so the
///      router can navigate to /friends.
///
/// Everything here is best-effort and fail-soft: a device without Play
/// Services, a denied permission, or any plugin error must never block app
/// startup or the rest of the social layer.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  FirebaseMessaging get _fm => FirebaseMessaging.instance;
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  bool _initialized = false;
  StreamSubscription<String>? _tokenRefreshSub;

  /// Called when the user taps a notification (background tap or cold-start
  /// launch). Wired from app init to the router.
  void Function(RemoteMessage message)? onMessageOpened;

  /// One-time setup: request permission, register handlers. Safe to call before
  /// sign-in; the token is bound to a user via [registerTokenForUser].
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      await _fm.requestPermission(alert: true, badge: true, sound: true);

      // Foreground taps and cold-start launch.
      FirebaseMessaging.onMessageOpenedApp.listen((m) {
        try {
          onMessageOpened?.call(m);
        } catch (_) {}
      });
      final initial = await _fm.getInitialMessage();
      if (initial != null) {
        try {
          onMessageOpened?.call(initial);
        } catch (_) {}
      }
      QaLoggerService.instance.log('PUSH', 'NOTIF_INIT_OK');
    } catch (e) {
      QaLoggerService.instance.log('PUSH', 'NOTIF_INIT_FAIL error=$e');
    }
  }

  /// Persists this device's FCM token onto the signed-in user's doc and keeps
  /// it fresh on refresh. Call after auth resolves to a real uid.
  Future<void> registerTokenForUser(String uid) async {
    if (uid.isEmpty) return;
    try {
      final token = await _fm.getToken();
      if (token != null && token.isNotEmpty) {
        await _saveToken(uid, token);
      }
      // Keep the stored token current if the OS rotates it.
      await _tokenRefreshSub?.cancel();
      _tokenRefreshSub = _fm.onTokenRefresh.listen((t) {
        if (t.isNotEmpty) _saveToken(uid, t);
      });
    } catch (e) {
      QaLoggerService.instance.log('PUSH', 'NOTIF_TOKEN_FAIL error=$e');
    }
  }

  Future<void> _saveToken(String uid, String token) async {
    try {
      await _db.collection('users').doc(uid).set({
        'fcmTokens': FieldValue.arrayUnion([token]),
      }, SetOptions(merge: true));
      QaLoggerService.instance.log('PUSH', 'NOTIF_TOKEN_SAVED');
    } catch (e) {
      QaLoggerService.instance.log('PUSH', 'NOTIF_TOKEN_SAVE_FAIL error=$e');
    }
  }

  /// Removes this device's token on sign-out so a former user stops receiving
  /// this device's pushes. Best-effort.
  Future<void> unregisterTokenForUser(String uid) async {
    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
    if (uid.isEmpty) return;
    try {
      final token = await _fm.getToken();
      if (token != null && token.isNotEmpty) {
        await _db.collection('users').doc(uid).set({
          'fcmTokens': FieldValue.arrayRemove([token]),
        }, SetOptions(merge: true));
      }
    } catch (_) {}
  }
}
