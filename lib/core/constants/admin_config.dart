/// Admin access configuration.
///
/// A user is treated as an admin if EITHER:
///   • their Firebase ID token carries the custom claim `admin == true`
///     (the owner account already has this — see firestore.rules / images), OR
///   • their login email is in [adminEmails] below.
///
/// The email allowlist is the easy, no-Firebase-console path: add an address
/// here, rebuild, and that account gets the in-app Admin panel. Firestore rules
/// mirror the same two checks so admin writes to other users' docs are allowed.
class AdminConfig {
  AdminConfig._();

  /// Lower-cased admin login emails. Keep in sync with firestore.rules.
  static const List<String> adminEmails = [
    'rot4735@gmail.com',
  ];

  static bool isAdminEmail(String? email) {
    if (email == null) return false;
    return adminEmails.contains(email.trim().toLowerCase());
  }
}
