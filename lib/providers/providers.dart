import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/constants/ad_constants.dart';
import '../models/economy/user_economy_model.dart';
import '../services/ad_service.dart';
import '../services/app_update_service.dart';
import '../services/auth_service.dart';
import '../services/economy_service.dart';
import '../services/hint_economy_guard.dart';
import '../services/local_economy_cache.dart';
import '../services/qa_logger_service.dart';
import '../services/room_service.dart';
import '../services/settings_service.dart';
import '../services/friends_service.dart';
import '../services/content_manifest_service.dart';
import '../services/cosmetics_catalog_service.dart';
import '../models/user_model.dart';
import '../models/room_model.dart';
import '../models/game_image_model.dart';
import '../models/friend_models.dart';

// Services
final authServiceProvider = Provider<AuthService>((ref) => AuthService());
final roomServiceProvider = Provider<RoomService>((ref) => RoomService());
final appUpdateServiceProvider =
    Provider<AppUpdateService>((ref) => AppUpdateService());

// One-shot fetch of the remote update config — watched by the home notice and
// the profile "update available" row so they share a single read.
final appUpdateInfoProvider = FutureProvider.autoDispose<AppUpdateInfo?>(
    (ref) => ref.watch(appUpdateServiceProvider).fetch());

// AdMob — single long-lived instance. Preloads rewarded + interstitial on
// creation so the first show is instant.
final adServiceProvider = Provider<AdService>((ref) {
  final service = AdService();
  if (AdConstants.adsEnabled) {
    service.preloadRewarded();
    service.preloadInterstitial();
  }
  ref.onDispose(service.dispose);
  return service;
});

// Economy — LocalEconomyCache created once (async init via FutureProvider)
final localEconomyCacheProvider = FutureProvider<LocalEconomyCache>(
  (ref) => LocalEconomyCache.create(),
);

final economyServiceProvider = Provider<EconomyService>((ref) {
  // Cache is optional — EconomyService handles a null cache gracefully.
  // Once localEconomyCacheProvider resolves, the provider rebuilds and passes
  // the real cache instance.
  final cache = ref.watch(localEconomyCacheProvider).valueOrNull;
  return EconomyService(FirebaseFirestore.instance, cache);
});

final hintEconomyGuardProvider = Provider<HintEconomyGuard>(
  (ref) => HintEconomyGuard(ref.watch(economyServiceProvider)),
);

// Fires true exactly once when the onboarding wallet grant succeeds (first install).
final firstTimeBonusProvider = StateProvider<bool>((ref) => false);

// Wallet stream for the currently authenticated user.
// Not autoDispose — keeps the ref alive so initWallet's .then() always runs.
final walletProvider = StreamProvider<UserEconomyModel?>((ref) {
  final userAsync = ref.watch(firebaseUserProvider);
  return userAsync.maybeWhen(
    data: (user) {
      if (user == null) return Stream.value(null);
      ref
          .read(economyServiceProvider)
          .initWallet(user.uid)
          .then(
            (granted) {
              QaLoggerService.instance.log('ECONOMY', 'INIT_WALLET_THEN granted=$granted');
              if (granted) {
                ref.read(firstTimeBonusProvider.notifier).state = true;
              }
            },
            onError: (e) {
              QaLoggerService.instance.log('ECONOMY', 'INIT_WALLET_THEN_ERROR ${e.toString().substring(0, e.toString().length.clamp(0, 60))}');
            },
          );
      return ref.read(economyServiceProvider).walletStream(user.uid);
    },
    orElse: () => Stream.value(null),
  );
});

// Auth state
final firebaseUserProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

final currentUserProvider = StreamProvider<UserModel?>((ref) {
  // Drive off the canonical auth stream (firebaseUserProvider) so this can
  // never diverge from the live SDK uid after an auth transition. The previous
  // design opened its OWN authStateChanges subscription inside
  // userModelStream(); if a Pigeon TypeError was swallowed mid-transition, it
  // could stay stuck on the stale (pre-link) UserModel. That stale id was
  // then written as a room's hostId and failed the Firestore create rule
  // (hostId == request.auth.uid) → permission-denied. Watching
  // firebaseUserProvider ties currentUserProvider to the exact same source as
  // walletProvider so they always agree on who the user is.
  final authUser = ref.watch(firebaseUserProvider).valueOrNull;
  if (authUser == null) return Stream.value(null);
  return ref.watch(authServiceProvider).userModelStreamForUid(authUser.uid);
});

// Emits whenever the live content manifest changes (admin edit). Screens that
// render admin-controlled content (topic active/labels, places) watch this to
// rebuild immediately — no app restart needed.
final contentManifestRevisionProvider = StreamProvider<int>((ref) {
  final notifier = ContentManifestService.instance.revision;
  final controller = StreamController<int>();
  void emit() => controller.add(notifier.value);
  emit(); // seed with the current value
  notifier.addListener(emit);
  ref.onDispose(() {
    notifier.removeListener(emit);
    controller.close();
  });
  return controller.stream;
});

// Emits whenever the live cosmetics catalog changes (admin edit) — the store
// screens watch this to show new/edited frames, name styles, win effects and
// board skins immediately.
final cosmeticsRevisionProvider = StreamProvider<int>((ref) {
  final notifier = CosmeticsCatalogService.instance.revision;
  final controller = StreamController<int>();
  void emit() => controller.add(notifier.value);
  emit(); // seed with the current value
  notifier.addListener(emit);
  ref.onDispose(() {
    notifier.removeListener(emit);
    controller.close();
  });
  return controller.stream;
});

// Deep-link join code — set by AppLinks handler, consumed by JoinRoomScreen
final pendingJoinCodeProvider = StateProvider<String?>((ref) => null);

// Deep-link friend code — set by the AppLinks handler when a friend-invite link
// is opened, consumed by FriendsScreen which auto-sends the request.
final pendingFriendCodeProvider = StateProvider<String?>((ref) => null);

// Current room
final currentRoomIdProvider = StateProvider<String?>((ref) => null);

final currentRoomProvider = StreamProvider<RoomModel?>((ref) {
  final roomId = ref.watch(currentRoomIdProvider);
  if (roomId == null) return Stream.value(null);
  return ref.watch(roomServiceProvider).watchRoom(roomId);
});

// Per-room stream — screens watch this directly using their roomId param
final roomStreamProvider =
    StreamProvider.autoDispose.family<RoomModel?, String>((ref, roomId) {
  final shortId = roomId.substring(0, roomId.length.clamp(0, 6));
  return ref.watch(roomServiceProvider).watchRoom(roomId).transform(
    StreamTransformer.fromHandlers(
      handleError: (e, st, sink) {
        final msg = e.toString();
        QaLoggerService.instance.log('ROOM', 'ROOM_STREAM_ERROR roomId=$shortId e=${msg.length > 80 ? msg.substring(0, 80) : msg}');
        sink.addError(e, st);
      },
      handleDone: (sink) {
        QaLoggerService.instance.log('ROOM', 'ROOM_STREAM_DONE roomId=$shortId');
        sink.close();
      },
    ),
  );
});

// ── Friends / social ────────────────────────────────────────────────────────
final friendsServiceProvider = Provider<FriendsService>((ref) => FriendsService());

// Accepted friends of the signed-in user.
final friendsListProvider = StreamProvider.autoDispose<List<FriendModel>>((ref) {
  final uid = ref.watch(firebaseUserProvider).valueOrNull?.uid;
  if (uid == null) return Stream.value(const []);
  return ref.watch(friendsServiceProvider).friends(uid);
});

// Incoming pending friend requests for the signed-in user.
final friendRequestsProvider =
    StreamProvider.autoDispose<List<FriendRequestModel>>((ref) {
  final uid = ref.watch(firebaseUserProvider).valueOrNull?.uid;
  if (uid == null) return Stream.value(const []);
  return ref.watch(friendsServiceProvider).incomingRequests(uid);
});

// Incoming game invites ("X invited you to play") for the signed-in user.
final gameInvitesProvider =
    StreamProvider.autoDispose<List<GameInviteModel>>((ref) {
  final uid = ref.watch(firebaseUserProvider).valueOrNull?.uid;
  if (uid == null) return Stream.value(const []);
  return ref.watch(friendsServiceProvider).incomingGameInvites(uid);
});

// Cumulative friends leaderboard (me + friends, sorted by points). Recomputes
// when my profile changes or my friends list changes; invalidate to refresh.
final friendsLeaderboardProvider =
    FutureProvider.autoDispose<List<FriendScore>>((ref) async {
  final me = ref.watch(currentUserProvider).valueOrNull;
  if (me == null) return const [];
  // Re-run when the friends list changes.
  ref.watch(friendsListProvider);
  return ref.watch(friendsServiceProvider).leaderboard(
        myUid: me.id,
        myName: me.name,
        myPoints: me.friendsGamePoints,
      );
});

// Recent friends-game history for the signed-in user.
final friendGamesProvider =
    StreamProvider.autoDispose<List<FriendGameRecord>>((ref) {
  final uid = ref.watch(firebaseUserProvider).valueOrNull?.uid;
  if (uid == null) return Stream.value(const []);
  return ref.watch(friendsServiceProvider).recentGames(uid);
});

// Selected image for game
final selectedGameImageProvider = StateProvider<GameImageModel?>((ref) => null);

// Public images list — autoDispose so it re-fetches fresh each time screen is mounted
final publicImagesProvider =
    FutureProvider.autoDispose<List<GameImageModel>>((ref) {
  return ref.watch(roomServiceProvider).getPublicImages();
});

// All images (for store)
final allImagesProvider = FutureProvider<List<GameImageModel>>((ref) {
  return ref.watch(roomServiceProvider).getAllImages();
});

// Voting state notifiers

class ImageVoteNotifier extends StateNotifier<Map<String, int>> {
  ImageVoteNotifier() : super({});

  void tally(Map<String, String> votes, String hostId) {
    final tally = <String, int>{};
    for (final entry in votes.entries) {
      final weight =
          entry.key == hostId ? 2 : 1;
      tally[entry.value] = (tally[entry.value] ?? 0) + weight;
    }
    state = tally;
  }
}

final imageVoteTallyProvider =
    StateNotifierProvider<ImageVoteNotifier, Map<String, int>>(
  (ref) => ImageVoteNotifier(),
);

// Turn state: tracks if current player has placed a piece this turn
class TurnStateNotifier extends StateNotifier<TurnState> {
  TurnStateNotifier() : super(TurnState.initial());

  void reset() => state = TurnState.initial();
  void setPiecePlaced() => state = state.copyWith(hasPlacedPiece: true);
  void setGuessUsed() => state = state.copyWith(hasGuessed: true);
  void setSelectedPiece(int? index) =>
      state = state.copyWith(selectedPieceIndex: index);
}

class TurnState {
  final bool hasPlacedPiece;
  final bool hasGuessed;
  final int? selectedPieceIndex;

  const TurnState({
    required this.hasPlacedPiece,
    required this.hasGuessed,
    this.selectedPieceIndex,
  });

  factory TurnState.initial() =>
      const TurnState(hasPlacedPiece: false, hasGuessed: false);

  TurnState copyWith({
    bool? hasPlacedPiece,
    bool? hasGuessed,
    int? selectedPieceIndex,
  }) =>
      TurnState(
        hasPlacedPiece: hasPlacedPiece ?? this.hasPlacedPiece,
        hasGuessed: hasGuessed ?? this.hasGuessed,
        selectedPieceIndex: selectedPieceIndex ?? this.selectedPieceIndex,
      );
}

final turnStateProvider =
    StateNotifierProvider<TurnStateNotifier, TurnState>(
  (ref) => TurnStateNotifier(),
);

// ── Settings ──────────────────────────────────────────────────────────────────

class AppSettings {
  final double musicVolume;
  final double sfxVolume;
  final bool vibrationEnabled;
  // Previous non-zero volume, restored when un-muting
  final double _prevMusicVolume;
  final double _prevSfxVolume;

  const AppSettings({
    this.musicVolume = 1.0,
    this.sfxVolume = 1.0,
    this.vibrationEnabled = true,
    double prevMusicVolume = 1.0,
    double prevSfxVolume = 1.0,
  })  : _prevMusicVolume = prevMusicVolume,
        _prevSfxVolume = prevSfxVolume;

  AppSettings copyWith({
    double? musicVolume,
    double? sfxVolume,
    bool? vibrationEnabled,
    double? prevMusicVolume,
    double? prevSfxVolume,
  }) =>
      AppSettings(
        musicVolume: musicVolume ?? this.musicVolume,
        sfxVolume: sfxVolume ?? this.sfxVolume,
        vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
        prevMusicVolume: prevMusicVolume ?? _prevMusicVolume,
        prevSfxVolume: prevSfxVolume ?? _prevSfxVolume,
      );
}

class SettingsNotifier extends StateNotifier<AppSettings> {
  final SettingsService _svc;

  SettingsNotifier(this._svc)
      : super(AppSettings(
          musicVolume: _svc.musicVolume,
          sfxVolume: _svc.sfxVolume,
          vibrationEnabled: _svc.vibrationEnabled,
          prevMusicVolume: _svc.musicVolume > 0 ? _svc.musicVolume : 1.0,
          prevSfxVolume: _svc.sfxVolume > 0 ? _svc.sfxVolume : 1.0,
        ));

  void setMusicVolume(double v) {
    final prev = v > 0 ? v : state._prevMusicVolume;
    state = state.copyWith(musicVolume: v, prevMusicVolume: prev);
    _svc.setMusicVolume(v).ignore();
  }

  void setSfxVolume(double v) {
    final prev = v > 0 ? v : state._prevSfxVolume;
    state = state.copyWith(sfxVolume: v, prevSfxVolume: prev);
    _svc.setSfxVolume(v).ignore();
  }

  void setVibrationEnabled(bool v) {
    state = state.copyWith(vibrationEnabled: v);
    _svc.setVibrationEnabled(v).ignore();
  }

  void toggleMusicMute() {
    if (state.musicVolume > 0) {
      setMusicVolume(0);
    } else {
      setMusicVolume(state._prevMusicVolume);
    }
  }

  void toggleSfxMute() {
    if (state.sfxVolume > 0) {
      setSfxVolume(0);
    } else {
      setSfxVolume(state._prevSfxVolume);
    }
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier(SettingsService.instance);
});
