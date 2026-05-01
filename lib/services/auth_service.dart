import 'package:flutter/foundation.dart' show debugPrint;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserModel?> signInForQa() async {
    try {
      final existingUser = _auth.currentUser;
      if (existingUser != null) {
        return _syncUser(existingUser, fallbackName: 'בודק');
      }
      return signInAnonymously();
    } catch (_) {
      return null;
    }
  }

  Future<UserModel?> signInAnonymously() async {
    final userCredential = await _auth.signInAnonymously();
    final user = userCredential.user!;
    return _syncUser(user, fallbackName: 'בודק');
  }

  Future<UserModel?> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      return _syncUser(userCredential.user!);
    } catch (_) {
      return signInForQa();
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

    final displayName = appleCredential.givenName != null
        ? '${appleCredential.givenName} ${appleCredential.familyName ?? ''}'.trim()
        : user.displayName ?? 'Player';

    if (userCredential.additionalUserInfo?.isNewUser == true) {
      await user.updateDisplayName(displayName);
    }

    return _syncUser(user, fallbackName: displayName);
  }

  Future<UserModel> _syncUser(User firebaseUser, {String fallbackName = 'Player'}) async {
    final docRef = _firestore.collection('users').doc(firebaseUser.uid);
    final doc = await docRef.get();

    if (!doc.exists) {
      final newUser = UserModel(
        id: firebaseUser.uid,
        name: firebaseUser.displayName?.trim().isNotEmpty == true
            ? firebaseUser.displayName!.trim()
            : fallbackName,
        photoUrl: firebaseUser.photoURL,
      );
      await docRef.set(newUser.toMap());
      return newUser;
    }

    return UserModel.fromFirestore(doc);
  }

  Future<UserModel?> getCurrentUserModel() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (!doc.exists) {
      return _syncUser(user, fallbackName: 'בודק');
    }
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
            return _syncUser(user, fallbackName: 'בודק');
          })
          .handleError((e) {
            debugPrint('userModelStream inner error: $e');
          });
    }).handleError((e) {
      // Catches PigeonUserDetails type errors from google_sign_in
      // and other auth stream errors — prevents app crash
      debugPrint('userModelStream error: $e');
    });
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
