import 'package:flutter/foundation.dart' show debugPrint;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../core/utils/display_name_sanitizer.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
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
    final userCredential = await _auth.signInAnonymously();
    return _syncUser(userCredential.user!, preferredName: preferredName);
  }

  Future<UserModel?> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null; // User dismissed the picker — stay on auth screen.

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential = await _auth.signInWithCredential(credential);
    return _syncUser(userCredential.user!);
    // Exceptions propagate to the caller (auth screen) which shows a visible error.
    // Do NOT silently fall back to anonymous — that creates unintended ghost accounts.
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

    // Existing user — update login timestamps only, never overwrite displayName.
    await docRef.update({
      'lastLoginAt': FieldValue.serverTimestamp(),
      'lastSeenAt': FieldValue.serverTimestamp(),
      'provider': provider,
      'isGuest': isGuest,
    });
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
    if (!doc.exists) return _syncUser(user);
    return UserModel.fromFirestore(doc);
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
