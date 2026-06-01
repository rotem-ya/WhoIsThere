class AppConstants {
  static const googlePlayUrl = 'TODO_GOOGLE_PLAY_URL';
  static const appStoreUrl = 'TODO_APP_STORE_URL';

  /// Production GitHub Pages join page (see CLAUDE.md sync workflow).
  static const joinPageUrl =
      'https://rotem-ya.github.io/apps-share-pages/whoisthere/join/';

  /// Direct-join deep link for a given room code.
  static String joinUrlForCode(String code) => '$joinPageUrl?code=$code';
}
