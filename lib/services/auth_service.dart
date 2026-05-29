import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show PlatformException;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../core/utils/display_name_sanitizer.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Credential Manager path (Android 14+): requires serverClientId.
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: '815269999993-10ejsitd6jnqn83ats57b6j4uq3ulnrs.apps.googleusercontent.com',
  );

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// QA / integration-test helper — not called from any production UI path.
  /// Signs in with the existing Firebase user or creates a fresh anonymous one.
  Future<UserModel?> signInForQa() async {
    assert(() {
      debugPrint('AuthService.signInForQa() called — QA path only');
      return true;
    }());
    try {
      final existingUser = _auth.currentUser;
      if (existingUser != null) return _syncUser(existingUser);
      return signInAnonymously(); // no preferredName in QA path
    } catch (_) {
      return null;
    }
  }

  Future<UserModel?> signInAnonymously({String? preferredName}) async {
    User? firebaseUser;
    try {
      final cred = await _auth.signInAnonymously();
      firebaseUser = cred.user;
    } on TypeError {
      // firebase_auth 4.16.x / firebase_core 2.32.x Pigeon version mismatch:
      // The native Android plugin signs the user in and authStateChanges()
      // fires, but the Dart-side Pigeon codec throws a type cast when
      // deserializing the method-channel response.  currentUser is already
      // set at this point — use it instead of treating this as auth failure.
      debugPrint('[AuthService] Pigeon cast workaround — falling back to currentUser');
      firebaseUser = _auth.currentUser;
    }
    if (firebaseUser == null) {
      throw FirebaseAuthException(
        code: 'sign-in-failed',
        message: 'signInAnonymously returned no user',
      );
    }
    return _syncUser(firebaseUser, preferredName: preferredName);
  }

  Future<UserModel?> signInWithGoogle() async {
    try {
      return await _runGoogleSignIn(_googleSignIn);
    } on PlatformException catch (e) {
      // Credential Manager (Android 14+) DEVELOPER_ERROR (ApiException: 10):
      // The device couldn't validate our app against the serverClientId.
      // Sign out any stale state and retry — on retry the dialog may prompt
      // the user to pick an account, which goes through a different code path
      // that often succeeds where the cached-credential path failed.
      if (e.code == 'sign_in_failed' && (e.message ?? '').contains('ApiException: 10')) {
        debugPrint('[AuthService] Credential Manager ApiException:10 — clearing cache, retrying');
        try { await _googleSignIn.signOut(); } catch (_) {}
        try { await _googleSignIn.disconnect(); } catch (_) {}
        // Second attempt: same instance (serverClientId kept so idToken is available)
        return await _runGoogleSignIn(_googleSignIn);
      }
      rethrow;
    }
    // Non-PlatformException errors (network, FirebaseAuthException) propagate to
    // _runAuth which shows a visible snackbar. Do NOT swallow them here.
  }

  /// Internal: runs the full Google sign-in dance for the given [instance].
  /// Handles the Pigeon cast bug in google_sign_in_android 6.x.
  Future<UserModel?> _runGoogleSignIn(GoogleSignIn instance) async {
    try {
      final googleUser = await instance.signIn();
      if (googleUser == null) return null; // User dismissed picker.

      final googleAuth = await googleUser.authentication;
      // idToken requires serverClientId; accessToken is always present.
      // Firebase accepts either — prefer idToken when available.
      if (googleAuth.idToken == null && googleAuth.accessToken == null) {
        throw Exception('Google Sign-In returned no auth tokens');
      }
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: googleAuth.accessToken,
      );
      final userCredential = await _auth.signInWithCredential(credential);
      // Force token refresh so the Firestore SDK picks up the new credentials
      // immediately — avoids a brief window of permission-denied on first write.
      try { await userCredential.user!.getIdToken(true); } catch (_) {}
      return _syncUser(userCredential.user!);
    } on TypeError {
      // google_sign_in_android 6.x Pigeon cast: native side has completed auth
      // but Dart-side deserialization fails. _auth.currentUser is already set.
      debugPrint('[AuthService] Google sign-in Pigeon cast — using _auth.currentUser');
      final firebaseUser = _auth.currentUser;
      if (firebaseUser != null) {
        try { await firebaseUser.getIdToken(true); } catch (_) {}
        return _syncUser(firebaseUser);
      }
      return null;
    }
  }

  Future<UserModel?> signInWithApple() async {
    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );

    final oauthCredential = OAuthProvider('apple.com').credential(
      idToken: appleCredential.identityToken,
      accessToken: appleCredential.authorizationCode,
    );

    final userCredential = await _auth.signInWithCredential(oauthCredential);
    final user = userCredential.user!;

    if (userCredential.additionalUserInfo?.isNewUser == true) {
      final raw = appleCredential.givenName != null
          ? '${appleCredential.givenName} ${appleCredential.familyName ?? ''}'.trim()
          : null;
      final displayName = DisplayNameSanitizer.sanitize(raw) ??
          DisplayNameSanitizer.sanitize(user.displayName) ??
          DisplayNameSanitizer.guestFallback();
      await user.updateDisplayName(displayName);
    }

    return _syncUser(user);
  }

  Future<UserModel> _syncUser(User firebaseUser, {String? preferredName}) async {
    final docRef = _firestore.collection('users').doc(firebaseUser.uid);
    final doc = await docRef.get();

    final provider = _resolveProvider(firebaseUser);
    final isGuest = firebaseUser.isAnonymous;

    if (!doc.exists) {
      // preferredName (from auth screen input) takes priority for new accounts.
      final rawName = preferredName ?? firebaseUser.displayName;
      final name = DisplayNameSanitizer.sanitize(rawName) ??
          DisplayNameSanitizer.guestFallback();

      final newUser = UserModel(
        id: firebaseUser.uid,
        name: name,
        photoUrl: firebaseUser.photoURL,
        provider: provider,
        isGuest: isGuest,
      );

      await docRef.set({
        ...newUser.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
        'lastSeenAt': FieldValue.serverTimestamp(),
      });
      return newUser;
    }

    // Existing user — update login timestamps. Also apply preferredName if the
    // user explicitly typed one (anonymous path only — never set for social logins).
    final updates = <String, dynamic>{
      'lastLoginAt': FieldValue.serverTimestamp(),
      'lastSeenAt': FieldValue.serverTimestamp(),
      'provider': provider,
      'isGuest': isGuest,
    };
    if (preferredName != null) {
      final sanitized = DisplayNameSanitizer.sanitize(preferredName);
      if (sanitized != null) updates['name'] = sanitized;
    }
    await docRef.update(updates);
    return UserModel.fromFirestore(await docRef.get());
  }

  static String _resolveProvider(User user) {
    if (user.isAnonymous) return 'anonymous';
    if (user.providerData.isEmpty) return 'unknown';
    return user.providerData.first.providerId;
  }

  Future<UserModel?> getCurrentUserModel() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (doc.exists) return UserModel.fromFirestore(doc);

    // Guard: give signInAnonymously() time to write the doc before falling back
    // to _syncUser (which would write a guestFallback name).
    await Future.delayed(const Duration(milliseconds: 500));
    final recheck = await _firestore.collection('users').doc(user.uid).get();
    if (recheck.exists) return UserModel.fromFirestore(recheck);
    return _syncUser(user);
  }

  Stream<UserModel?> userModelStream() {
    return _auth.authStateChanges().asyncExpand((user) {
      if (user == null) return Stream.value(null);
      return _firestore
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .asyncMap((doc) async {
            if (doc.exists) return UserModel.fromFirestore(doc);
            // Doc not found. Two scenarios:
            //   (a) signInAnonymously() is still writing it — retry until it appears.
            //   (b) Firestore doc is genuinely gone (reinstall, cleared data).
            // Retry up to 5× at 350 ms intervals (max 1.75 s total). On a good
            // network, case (a) resolves on the first or second retry (~350–700 ms).
            // Only fall through to _syncUser if doc is still absent after all retries.
            for (int attempt = 0; attempt < 5; attempt++) {
              await Future.delayed(const Duration(milliseconds: 350));
              final recheck = await _firestore.collection('users').doc(user.uid).get();
              if (recheck.exists) return UserModel.fromFirestore(recheck);
            }
            // Genuine recovery (case b) or very slow network — create the doc now.
            return _syncUser(user);
          })
          .handleError((e) {
            debugPrint('userModelStream inner error: $e');
          });
    }).handleError((e) {
      // Catches PigeonUserDetails type errors from google_sign_in
      // and other auth stream errors — prevents app crash on any platform.
      debugPrint('userModelStream error: $e');
    });
  }

  Future<void> updateDisplayName(String userId, String rawName) async {
    final name = DisplayNameSanitizer.sanitize(rawName);
    if (name == null) return;
    await _firestore.collection('users').doc(userId).update({'name': name});
  }

  Future<void> updateTotalPoints(String userId, int delta) async {
    await _firestore.collection('users').doc(userId).update({
      'totalPoints': FieldValue.increment(delta),
    });
  }

  Future<void> purchaseItem(String userId, String itemId, bool isImage) async {
    final field = isImage ? 'purchasedImageIds' : 'purchasedThemeIds';
    await _firestore.collection('users').doc(userId).update({
      field: FieldValue.arrayUnion([itemId]),
    });
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}
