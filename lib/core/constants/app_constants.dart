class AppConstants {
  static const googlePlayUrl = 'TODO_GOOGLE_PLAY_URL';
  static const appStoreUrl = 'TODO_APP_STORE_URL';

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
