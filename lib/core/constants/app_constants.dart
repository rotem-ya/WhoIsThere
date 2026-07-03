import 'dart:io' show Platform;

class AppConstants {
  /// Android package id (see android/app/build.gradle → applicationId). The
  /// Play listing URL is fully determined by it, so we can build it without a
  /// remote config. A remote override (app_config/app → androidUrl) still wins
  /// when present.
  static const androidPackage = 'com.whoisthere.app';

  static const googlePlayUrl =
      'https://play.google.com/store/apps/details?id=$androidPackage';

  /// App Store listing URL. The numeric Apple ID is only known once the app
  /// record is created in App Store Connect, so this is filled from the remote
  /// config (app_config/app → iosUrl). Empty until then; sharing simply omits
  /// the iOS line while it's blank.
  static const appStoreUrl = '';

  /// Best store URL for the current platform, preferring a remote override.
  static String storeUrl({String? androidOverride, String? iosOverride}) {
    if (Platform.isIOS) {
      final ios = (iosOverride ?? '').trim();
      return ios.isNotEmpty ? ios : appStoreUrl;
    }
    final android = (androidOverride ?? '').trim();
    return android.isNotEmpty ? android : googlePlayUrl;
  }

  /// The message shared from the "שתף את האפליקציה" action. Includes whichever
  /// store links are known (Play is always available; the App Store line is
  /// added only once its URL is configured).
  static String shareMessage({String? androidUrl, String? iosUrl}) {
    final android = (androidUrl ?? '').trim();
    final ios = (iosUrl ?? '').trim();
    final playLink = android.isNotEmpty ? android : googlePlayUrl;
    final appleLink = ios.isNotEmpty ? ios : appStoreUrl;

    final b = StringBuffer()
      ..writeln('בואו לשחק איתי ב"מה בתמונה?" 🖼️')
      ..writeln('משחק ניחוש תמונות מהיר וכיפי — מי מזהה ראשון מנצח!')
      ..writeln()
      ..writeln('📲 הורדה:')
      ..writeln('אנדרואיד: $playLink');
    if (appleLink.isNotEmpty) {
      b.writeln('אייפון: $appleLink');
    }
    return b.toString().trim();
  }

  /// Production GitHub Pages join page (see CLAUDE.md sync workflow).
  static const joinPageUrl =
      'https://rotem-ya.github.io/apps-share-pages/whoisthere/join/';

  /// Direct-join deep link for a given room code.
  static String joinUrlForCode(String code) => '$joinPageUrl?code=$code';

  /// Production GitHub Pages friend-invite page (synced from docs/friend.html).
  static const friendPageUrl =
      'https://rotem-ya.github.io/apps-share-pages/whoisthere/friend/';

  /// Friend-invite deep link for a given personal friend code. Opening it adds
  /// the inviter as a friend automatically (see FriendsScreen).
  static String friendInviteUrl(String code) => '$friendPageUrl?code=$code';
}
