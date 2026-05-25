import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/economy/user_economy_model.dart';
import '../services/auth_service.dart';
import '../services/economy_service.dart';
import '../services/hint_economy_guard.dart';
import '../services/local_economy_cache.dart';
import '../services/qa_logger_service.dart';
import '../services/room_service.dart';
import '../services/settings_service.dart';
import '../models/user_model.dart';
import '../models/room_model.dart';
import '../models/game_image_model.dart';

// Services
final authServiceProvider = Provider<AuthService>((ref) => AuthService());
final roomServiceProvider = Provider<RoomService>((ref) => RoomService());

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
  return ref.watch(authServiceProvider).userModelStream();
});

// Deep-link join code — set by AppLinks handler, consumed by JoinRoomScreen
final pendingJoinCodeProvider = StateProvider<String?>((ref) => null);

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
