import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show PlatformException;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../core/utils/display_name_sanitizer.dart';
import 'qa_logger_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Classic Google Sign-In (no Credential Manager): works on all Android versions.
  // serverClientId is intentionally omitted — Credential Manager (Android 14+)
  // throws DEVELOPER_ERROR (ApiException:10) when web-client domain restrictions
  // are not perfectly aligned. The classic API validates only against the Android
  // OAuth client SHA-1 in google-services.json, which is always correct.
  // Firebase accepts accessToken alone when idToken is absent.
  final GoogleSignIn _googleSignIn = GoogleSignIn();

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
    return await _runGoogleSignIn(_googleSignIn);
    // Exceptions (network, FirebaseAuthException, PlatformException) propagate to
    // _runAuth which shows a visible snackbar.
  }

  /// Internal: runs the full Google sign-in dance for the given [instance].
  ///
  /// Strategy: when the current user is anonymous, prefer [linkWithCredential]
  /// over [signInWithCredential]. Linking upgrades the account IN-PLACE:
  /// the UID, wallet, and all Firestore data are preserved — no token/rules
  /// transition, no permission-denied window.
  ///
  /// Falls back to [signInWithCredential] when:
  ///   • No current user (fresh sign-in from auth screen).
  ///   • [credential-already-in-use] — Google account already has its own
  ///     Firebase UID; sign into that account instead.
  ///
  /// Also handles the google_sign_in_android 6.x Pigeon cast bug (TypeError
  /// or PlatformException thrown after the native credential exchange succeeds).
  Future<UserModel?> _runGoogleSignIn(GoogleSignIn instance) async {
    try {
      final googleUser = await instance.signIn();
      if (googleUser == null) return null; // User dismissed picker.

      final googleAuth = await googleUser.authentication;
      if (googleAuth.idToken == null && googleAuth.accessToken == null) {
        throw Exception('Google Sign-In returned no auth tokens');
      }
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: googleAuth.accessToken,
      );

      // Choose link vs sign-in based on current auth state.
      final anonUser = _auth.currentUser;
      UserCredential userCredential;

      if (anonUser != null && anonUser.isAnonymous) {
        // Upgrade the anonymous account — UID and wallet are preserved.
        try {
          userCredential = await anonUser.linkWithCredential(credential);
          QaLoggerService.instance.log(
            'AUTH', 'AUTH_GOOGLE_LINKED uid=${userCredential.user?.uid}');
        } on FirebaseAuthException catch (e) {
          if (e.code == 'credential-already-in-use' ||
              e.code == 'provider-already-linked') {
            // This Google account already has its own Firebase UID.
            // Sign into the existing account (UID will change).
            QaLoggerService.instance.log(
              'AUTH', 'AUTH_GOOGLE_LINK_CONFLICT code=${e.code} → signIn');
            userCredential = await _auth.signInWithCredential(
                e.credential ?? credential);
          } else {
            rethrow;
          }
        }
      } else {
        // Not anonymous (or no current user) — plain sign-in.
        userCredential = await _auth.signInWithCredential(credential);
        QaLoggerService.instance.log(
          'AUTH', 'AUTH_GOOGLE_SIGNIN uid=${userCredential.user?.uid}');
      }

      // Force token refresh so the Firestore SDK has the latest credentials.
      try { await userCredential.user!.getIdToken(true); } catch (_) {}
      return _syncUser(userCredential.user!);
    } on TypeError {
      debugPrint('[AuthService] Pigeon cast TypeError — attempting authStateChanges recovery');
      return _recoverFromSignInError('TypeError');
    } on PlatformException catch (e) {
      debugPrint('[AuthService] PlatformException: ${e.code} — attempting authStateChanges recovery');
      return _recoverFromSignInError('PlatformException:${e.code}');
    }
  }

  /// Waits for Firebase Auth to emit a non-anonymous user after a Pigeon cast
  /// error from signInWithCredential. The native sign-in already completed, so
  /// the auth state change arrives within ~1-3 seconds.
  Future<UserModel?> _recoverFromSignInError(String reason) async {
    try {
      final User? recoveredUser = await _auth
          .authStateChanges()
          .where((u) => u != null && !u.isAnonymous)
          .first
          .timeout(const Duration(seconds: 3));

      if (recoveredUser != null) {
        debugPrint('[AuthService] AUTH_GOOGLE_SUCCESS_RECOVERED reason=$reason uid=${recoveredUser.uid}');
        // Force token refresh — Firestore SDK had a stale anonymous token.
        try { await recoveredUser.getIdToken(true); } catch (_) {}
        await Future.delayed(const Duration(milliseconds: 200));
        return _syncUser(recoveredUser);
      }
    } catch (_) {
      // timeout or stream error — sign-in genuinely did not complete
    }
    debugPrint('[AuthService] AUTH_GOOGLE_FAILED_AFTER_TYPEERROR_RECOVERY reason=$reason');
    return null;
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

    // Mirrors the Google link-and-upgrade strategy: anonymous accounts are
    // upgraded in-place so the UID, wallet, and Firestore data are preserved.
    final anonUser = _auth.currentUser;
    UserCredential userCredential;

    if (anonUser != null && anonUser.isAnonymous) {
      try {
        userCredential = await anonUser.linkWithCredential(oauthCredential);
        QaLoggerService.instance.log(
            'AUTH', 'AUTH_APPLE_LINKED uid=${userCredential.user?.uid}');
      } on FirebaseAuthException catch (e) {
        if (e.code == 'credential-already-in-use' ||
            e.code == 'provider-already-linked') {
          QaLoggerService.instance.log(
              'AUTH', 'AUTH_APPLE_LINK_CONFLICT code=${e.code} → signIn');
          userCredential =
              await _auth.signInWithCredential(e.credential ?? oauthCredential);
        } else {
          rethrow;
        }
      }
    } else {
      userCredential = await _auth.signInWithCredential(oauthCredential);
      QaLoggerService.instance.log(
          'AUTH', 'AUTH_APPLE_SIGNIN uid=${userCredential.user?.uid}');
    }

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

    try { await user.getIdToken(true); } catch (_) {}
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
      return userModelStreamForUid(user.uid);
    }).handleError((e) {
      // Catches PigeonUserDetails type errors from google_sign_in
      // and other auth stream errors — prevents app crash on any platform.
      debugPrint('userModelStream error: $e');
    });
  }

  /// Streams the [UserModel] for a specific [uid]'s Firestore doc, with the
  /// same retry-until-written behaviour as [userModelStream] but WITHOUT
  /// opening its own authStateChanges subscription.
  ///
  /// This lets [currentUserProvider] drive off the single canonical auth
  /// stream (firebaseUserProvider). The previous design opened a SECOND
  /// authStateChanges subscription inside userModelStream(); if a Pigeon
  /// TypeError was swallowed mid-transition, that subscription could get
  /// stuck on the stale pre-link UserModel. The stale user.id was then
  /// written as a room's hostId and failed the Firestore rule
  /// (hostId == request.auth.uid) → permission-denied. Keying off the live
  /// uid removes the divergence entirely.
  Stream<UserModel?> userModelStreamForUid(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .asyncMap((doc) async {
          if (doc.exists) return UserModel.fromFirestore(doc);
          // Doc not found — two scenarios:
          //   (a) sign-in is still writing it → retry until it appears.
          //   (b) doc genuinely gone (reinstall, cleared data).
          // Retry up to 5× at 350 ms intervals (max 1.75 s total).
          for (int attempt = 0; attempt < 5; attempt++) {
            await Future.delayed(const Duration(milliseconds: 350));
            final recheck = await _firestore.collection('users').doc(uid).get();
            if (recheck.exists) return UserModel.fromFirestore(recheck);
          }
          // Genuine recovery (case b) — only if uid still matches the live user.
          final user = _auth.currentUser;
          if (user != null && user.uid == uid) return _syncUser(user);
          return null;
        })
        .handleError((e) {
          debugPrint('userModelStreamForUid error uid=$uid: $e');
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
