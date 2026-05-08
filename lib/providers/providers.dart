import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/economy/user_economy_model.dart';
import '../services/auth_service.dart';
import '../services/economy_service.dart';
import '../services/hint_economy_guard.dart';
import '../services/local_economy_cache.dart';
import '../services/room_service.dart';
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

// Wallet stream for the currently authenticated user
final walletProvider = StreamProvider.autoDispose<UserEconomyModel?>((ref) {
  final userAsync = ref.watch(firebaseUserProvider);
  return userAsync.maybeWhen(
    data: (user) {
      if (user == null) return Stream.value(null);
      return ref.watch(economyServiceProvider).walletStream(user.uid);
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
  return ref.watch(roomServiceProvider).watchRoom(roomId);
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

