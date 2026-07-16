import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show PlatformException;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/win_effect.dart';
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
              e.code == 'provider-already-linked' ||
              e.code == 'email-already-in-use') {
            // This Google account already has its own Firebase UID.
            // Sign into the existing account (UID will change).
            QaLoggerService.instance.log(
              'AUTH', 'AUTH_GOOGLE_LINK_CONFLICT code=${e.code} → signIn');
            // The Google account exists under its own UID, so we sign into it
            // (UID changes) and carry the guest's progress across. Capture +
            // delete the guest data BEFORE switching accounts (Firestore rules
            // only let a user delete their own doc), then write it onto the
            // Google account.
            final anonUid = anonUser.uid;
            final guest = await _captureGuestData(anonUid);
            await _deleteUserData(anonUid);
            userCredential = await _auth.signInWithCredential(
                e.credential ?? credential);
            final newUid = userCredential.user?.uid;
            if (guest != null && newUid != null && newUid != anonUid) {
              await _writeMergedData(guest, newUid);
            }
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

  /// True for the known firebase_auth Pigeon codec bug where a successful native
  /// sign-in throws `type 'List<Object?>' is not a subtype of type
  /// 'PigeonUserDetails?'` in the Dart layer. The auth actually succeeded; we
  /// recover via the auth-state stream / currentUser.
  static bool _isPigeonCastError(Object e) {
    final s = e.toString();
    return s.contains('PigeonUserDetails') ||
        s.contains("subtype of type 'PigeonUserDetails?'") ||
        (s.contains('List<Object?>') && s.contains('is not a subtype'));
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

  /// Cryptographically-random nonce (Apple sign-in replay protection).
  static String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._';
    final rnd = math.Random.secure();
    return List.generate(length, (_) => charset[rnd.nextInt(charset.length)])
        .join();
  }

  /// Acquires a fresh Apple credential carrying a new single-use nonce. Each
  /// Apple ID token is bound to one nonce and may be presented to Firebase only
  /// once, so a fresh credential must be re-acquired whenever a prior attempt
  /// (e.g. a failed link) already consumed one — otherwise Firebase rejects it
  /// with missing-or-invalid-nonce ("Duplicate credential received").
  Future<(AuthorizationCredentialAppleID, OAuthCredential)>
      _acquireAppleCredential() async {
    // Firebase requires a nonce: send the SHA-256 hash to Apple, and the raw
    // value to Firebase, so it can verify the ID token wasn't replayed.
    final rawNonce = _generateNonce();
    final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();
    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: hashedNonce,
    );
    final oauthCredential = OAuthProvider('apple.com').credential(
      idToken: appleCredential.identityToken,
      rawNonce: rawNonce,
      accessToken: appleCredential.authorizationCode,
    );
    return (appleCredential, oauthCredential);
  }

  Future<UserModel?> signInWithApple() async {
    QaLoggerService.instance.log('AUTH', 'AUTH_APPLE_BEGIN');
    var (appleCredential, oauthCredential) = await _acquireAppleCredential();
    QaLoggerService.instance.log('AUTH', 'AUTH_APPLE_CREDENTIAL_OK');

    // Mirrors the Google link-and-upgrade strategy: anonymous accounts are
    // upgraded in-place so the UID, wallet, and Firestore data are preserved.
    // Wrapped so the firebase_auth Pigeon cast bug (native sign-in succeeds but
    // the Dart layer throws a List→PigeonUserDetails cast error) recovers via
    // the auth-state stream instead of surfacing a bogus "error" to the user.
    try {
      return await _appleSignInInner(appleCredential, oauthCredential);
    } catch (e) {
      if (_isPigeonCastError(e)) {
        QaLoggerService.instance.log('AUTH', 'AUTH_APPLE_TYPEERROR_RECOVER');
        final recovered = await _recoverFromSignInError('AUTH_APPLE_typeerror');
        if (recovered != null) return recovered;
      }
      rethrow;
    }
  }

  /// The link-or-sign-in body of [signInWithApple], split out so its Pigeon
  /// cast errors can be caught and recovered in one place.
  Future<UserModel?> _appleSignInInner(
    AuthorizationCredentialAppleID appleCredential,
    OAuthCredential oauthCredential,
  ) async {
    final anonUser = _auth.currentUser;
    UserCredential userCredential;

    if (anonUser != null && anonUser.isAnonymous) {
      try {
        userCredential = await anonUser.linkWithCredential(oauthCredential);
        QaLoggerService.instance.log(
            'AUTH', 'AUTH_APPLE_LINKED uid=${userCredential.user?.uid}');
      } on FirebaseAuthException catch (e) {
        if (e.code == 'credential-already-in-use' ||
            e.code == 'provider-already-linked' ||
            e.code == 'email-already-in-use') {
          // The Apple account already exists (e.g. the user signed in with
          // Apple before). Sign into that existing account instead of linking,
          // then merge the anonymous guest's data into it.
          QaLoggerService.instance.log(
              'AUTH', 'AUTH_APPLE_LINK_CONFLICT code=${e.code} → signIn');
          // The failed link already consumed our Apple nonce. Firebase only
          // returns a reusable credential for credential-already-in-use; for
          // email-already-in-use (e.credential == null) we must re-acquire a
          // fresh Apple credential, otherwise sign-in fails with
          // missing-or-invalid-nonce ("Duplicate credential received").
          // Capture + delete the guest data BEFORE switching accounts (rules
          // only let a user delete their own doc), then carry it onto the
          // Apple account after sign-in.
          final anonUid = anonUser.uid;
          final guest = await _captureGuestData(anonUid);
          await _deleteUserData(anonUid);
          final conflictCredential = e.credential;
          if (conflictCredential != null) {
            userCredential =
                await _auth.signInWithCredential(conflictCredential);
          } else {
            final (freshApple, freshOauth) = await _acquireAppleCredential();
            appleCredential = freshApple;
            userCredential = await _auth.signInWithCredential(freshOauth);
          }
          final newUid = userCredential.user?.uid;
          if (guest != null && newUid != null && newUid != anonUid) {
            await _writeMergedData(guest, newUid);
          }
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

      final email = firebaseUser.email?.trim().toLowerCase();
      await docRef.set({
        ...newUser.toMap(),
        if (email != null && email.isNotEmpty) 'email': email,
        'createdAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
        'lastSeenAt': FieldValue.serverTimestamp(),
      });
      return newUser.copyWith(email: email);
    }

    // Existing user — update login timestamps. Also apply preferredName if the
    // user explicitly typed one (anonymous path only — never set for social logins).
    final updates = <String, dynamic>{
      'lastLoginAt': FieldValue.serverTimestamp(),
      'lastSeenAt': FieldValue.serverTimestamp(),
      'provider': provider,
      'isGuest': isGuest,
    };
    // Backfill / refresh the login email (lower-cased) so admins can look the
    // user up by email. Only for accounts that actually carry one.
    final email = firebaseUser.email?.trim().toLowerCase();
    if (email != null && email.isNotEmpty) updates['email'] = email;
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

  bool _winEffectRefundChecked = false;

  /// v1.3: אפקטי הניצחון הוסרו מהחנות ו"מופע זיקוקים" הפך לאפקט של כולם.
  /// מחזיר חד-פעמית את מלוא המטבעות למי שרכש אפקטים בעבר (דגל
  /// winEffectsRefundedAt על מסמך המשתמש). Fail-soft — ינוסה שוב בפתיחה הבאה.
  Future<void> refundRetiredWinEffects() async {
    if (_winEffectRefundChecked) return;
    _winEffectRefundChecked = true;
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      final userRef = _firestore.collection('users').doc(user.uid);
      final walletRef = userRef.collection('economy').doc('wallet');
      await _firestore.runTransaction((tx) async {
        final snap = await tx.get(userRef);
        final data = snap.data();
        if (data == null || data['winEffectsRefundedAt'] != null) return;
        final owned =
            List<String>.from(data['ownedWinEffects'] ?? const <String>[]);
        var refund = 0;
        for (final id in owned) {
          refund += winEffectFor(id).price; // free/'none' add 0
        }
        if (refund <= 0) return;
        tx.set(
            walletRef,
            {'coins': FieldValue.increment(refund)},
            SetOptions(merge: true));
        tx.set(
            userRef,
            {
              'winEffectsRefundedAt': FieldValue.serverTimestamp(),
              'winEffectsRefundAmount': refund,
            },
            SetOptions(merge: true));
      });
    } catch (_) {
      _winEffectRefundChecked = false; // retry on the next app open
    }
  }

  DateTime? _lastSeenTouch;

  /// Fire-and-forget refresh of the signed-in user's `lastSeenAt` so the admin
  /// "recently connected" list reflects app opens, not just fresh logins.
  /// Throttled to once per 2 minutes per session and fully fail-soft.
  Future<void> touchLastSeen() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final now = DateTime.now();
    if (_lastSeenTouch != null &&
        now.difference(_lastSeenTouch!) < const Duration(minutes: 2)) {
      return;
    }
    _lastSeenTouch = now;
    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .update({'lastSeenAt': FieldValue.serverTimestamp()});
    } catch (_) {
      _lastSeenTouch = null; // let the next call retry
    }
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

  /// Copies progress from an anonymous account into a social-login account.
  /// Called only when linkWithCredential fails (credential-already-in-use),
  /// meaning the user has a pre-existing Google/Apple UID. Both accounts may
  /// have real data; we take the best of each field to avoid losing progress.
  /// Reads the guest (anonymous) user's mergeable data BEFORE we switch to an
  /// existing social account. Returns null when the guest has no doc.
  Future<_GuestSnapshot?> _captureGuestData(String fromUid) async {
    try {
      final results = await Future.wait([
        _firestore.doc('users/$fromUid').get(),
        _firestore.doc('users/$fromUid/economy/wallet').get(),
        _firestore.doc('users/$fromUid/exposure_history/data').get(),
      ]);
      if (!results[0].exists) return null;
      return _GuestSnapshot(
        user: results[0].data() ?? {},
        wallet: results[1].data(),
        exposure: results[2].data(),
      );
    } catch (e) {
      QaLoggerService.instance.log('AUTH', 'GUEST_CAPTURE_ERROR $e');
      return null;
    }
  }

  /// Merges a captured guest [snap] into the signed-in social account [toUid]:
  /// owned lists unioned, points/coins/earned + matches SUMMED (the guest's
  /// progress is added to the existing account, not just the larger of the
  /// two), exposure maxed per image.
  Future<void> _writeMergedData(_GuestSnapshot snap, String toUid) async {
    QaLoggerService.instance.log('AUTH', 'MERGE_ANON_START to=$toUid');
    try {
      final results = await Future.wait([
        _firestore.doc('users/$toUid').get(),
        _firestore.doc('users/$toUid/economy/wallet').get(),
        _firestore.doc('users/$toUid/exposure_history/data').get(),
      ]);
      final src = snap.user;
      final tgt = results[0].data() ?? {};
      final srcW = snap.wallet ?? {};
      final tgtW = results[1].data() ?? {};
      final tgtExp = results[2];

      List<String> union(String key) => {
            ...List<String>.from(src[key] ?? []),
            ...List<String>.from(tgt[key] ?? []),
          }.toList();

      final mergedDiscovered = union('discoveredImageIds');
      final mergedSkins = {'default', ...union('ownedSkins')}.toList();

      await _firestore.doc('users/$toUid').set({
        'totalPoints': ((src['totalPoints'] as num?)?.toInt() ?? 0) +
            ((tgt['totalPoints'] as num?)?.toInt() ?? 0),
        'discoveredImageIds': mergedDiscovered,
        'ownedSkins': mergedSkins,
        'ownedFrames': union('ownedFrames'),
        'ownedNameStyles': union('ownedNameStyles'),
        'ownedWinEffects': union('ownedWinEffects'),
        'ownedBoardSkins': union('ownedBoardSkins'),
        'ownedAvatars': union('ownedAvatars'),
      }, SetOptions(merge: true));

      if (snap.wallet != null) {
        int s(String k) => (srcW[k] as num?)?.toInt() ?? 0;
        int t(String k) => (tgtW[k] as num?)?.toInt() ?? 0;
        await _firestore.doc('users/$toUid/economy/wallet').set({
          'coins':              s('coins') + t('coins'),
          'totalEarned':        s('totalEarned') + t('totalEarned'),
          'totalMatchesPlayed': s('totalMatchesPlayed') + t('totalMatchesPlayed'),
          'totalMatchesWon':    s('totalMatchesWon') + t('totalMatchesWon'),
          'totalHintsUsed':     s('totalHintsUsed') + t('totalHintsUsed'),
        }, SetOptions(merge: true));
      }

      if (snap.exposure != null) {
        final srcMap = snap.exposure!;
        final tgtMap = tgtExp.data() ?? {};
        final merged = <String, int>{};
        for (final key in {...srcMap.keys, ...tgtMap.keys}) {
          merged[key] = math.max(
            (srcMap[key] as num?)?.toInt() ?? 0,
            (tgtMap[key] as num?)?.toInt() ?? 0,
          );
        }
        if (merged.isNotEmpty) {
          await _firestore
              .doc('users/$toUid/exposure_history/data')
              .set(merged, SetOptions(merge: true));
        }
      }

      QaLoggerService.instance.log('AUTH',
          'MERGE_ANON_OK to=$toUid discovered=${mergedDiscovered.length} skins=${mergedSkins.length}');
    } catch (e) {
      QaLoggerService.instance.log('AUTH', 'MERGE_ANON_ERROR $e');
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  /// Permanently deletes the signed-in user's account — their Firestore data
  /// and their Firebase Auth user. Required by App Store Guideline 5.1.1(v):
  /// an account created in-app must be deletable from within the app.
  ///
  /// Firebase requires a recent login to delete an account; if the session is
  /// stale we re-authenticate with the same provider and retry once. Throws on
  /// failure so the UI can surface a message.
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final uid = user.uid;

    // 1) Remove the user's Firestore data (best-effort per sub-collection; a
    //    failed sub-doc delete must not block deleting the auth account).
    await _deleteUserData(uid);

    // 2) Delete the auth user, re-authenticating if the session is too old.
    try {
      await user.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        await _reauthenticate(user);
        await user.delete();
      } else {
        rethrow;
      }
    }

    // 3) Clear the provider session so the next launch starts clean.
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    QaLoggerService.instance.log('AUTH', 'ACCOUNT_DELETED uid=$uid');
  }

  Future<void> _deleteUserData(String uid) async {
    final userRef = _firestore.collection('users').doc(uid);
    // The client can't recurse arbitrary sub-collections; delete the ones we
    // know about, then the main doc.
    for (final sub in [
      'friends',
      'friendGames',
      'exposure_history',
      'economy',
      'economy_transactions',
    ]) {
      try {
        final docs = await userRef.collection(sub).get();
        for (final d in docs.docs) {
          await d.reference.delete();
        }
      } catch (_) {}
    }
    try {
      await userRef.delete();
    } catch (e) {
      QaLoggerService.instance.log('AUTH', 'ACCOUNT_DATA_DELETE_ERR $e');
    }
  }

  Future<void> _reauthenticate(User user) async {
    final providers = user.providerData.map((p) => p.providerId).toList();
    if (providers.contains('google.com')) {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw FirebaseAuthException(
            code: 'reauth-cancelled', message: 'האימות בוטל');
      }
      final googleAuth = await googleUser.authentication;
      final cred = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: googleAuth.accessToken,
      );
      await user.reauthenticateWithCredential(cred);
    } else if (providers.contains('apple.com')) {
      final (_, oauthCredential) = await _acquireAppleCredential();
      await user.reauthenticateWithCredential(oauthCredential);
    }
    // Anonymous users have no provider and don't require recent login.
  }
}

/// Immutable snapshot of a guest (anonymous) account's mergeable data, captured
/// BEFORE the account is deleted and we switch to an existing social account.
/// [user] is the users/{uid} doc; [wallet] the economy/wallet doc; [exposure]
/// the exposure_history/data doc (both nullable when the guest never created
/// them).
class _GuestSnapshot {
  final Map<String, dynamic> user;
  final Map<String, dynamic>? wallet;
  final Map<String, dynamic>? exposure;
  _GuestSnapshot({required this.user, this.wallet, this.exposure});
}
