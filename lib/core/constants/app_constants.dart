import 'dart:io' show Platform;

class AppConstants {
  /// Android package id (see android/app/build.gradle → applicationId). The
  /// Play listing URL is fully determined by it, so we can build it without a
  /// remote config. A remote override (app_config/app → androidUrl) still wins
  /// when present.
  static const androidPackage = 'com.whoisthere.app';

  static const googlePlayUrl =
      'https://play.google.com/store/apps/details?id=$androidPackage';

  /// App Store listing URL. Apple ID 6776076758 ("מה בתמונה?", approved
  /// 2026-07-03). A remote override (app_config/app → iosUrl) still wins when
  /// present.
  static const appStoreId = '6776076758';

  static const appStoreUrl = 'https://apps.apple.com/app/id$appStoreId';

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

  /// Canonical public-web host: Firebase Hosting (project whoisthere-380fa).
  /// Independent of any GitHub repo visibility; also serves /app-ads.txt at
  /// the domain root for AdMob. Deployed by .github/workflows/deploy-hosting
  /// from the public/ directory. The two legacy GitHub Pages hosts
  /// (rotem-ya.github.io/WhoIsThere and .../apps-share-pages/whoisthere) are
  /// still recognized by the deep-link handler + AndroidManifest so links
  /// shared by older builds keep opening the app.
  static const webBase = 'https://whoisthere-380fa.web.app';

  /// Production join page.
  static const joinPageUrl = '$webBase/join/';

  /// Direct-join deep link for a given room code.
  static String joinUrlForCode(String code) => '$joinPageUrl?code=$code';

  /// Production friend-invite page.
  static const friendPageUrl = '$webBase/friend/';

  /// Friend-invite deep link for a given personal friend code. Opening it adds
  /// the inviter as a friend automatically (see FriendsScreen).
  static String friendInviteUrl(String code) => '$friendPageUrl?code=$code';
}
