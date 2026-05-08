import '../core/constants/economy_config.dart';
import '../models/economy/economy_transaction_model.dart';
import '../models/economy/user_economy_model.dart';
import 'economy_service.dart';

enum HintType { revealTile, extraGuess }

class HintEconomyGuard {
  final EconomyService _economyService;

  HintEconomyGuard(this._economyService);

  int priceFor(HintType hint) {
    switch (hint) {
      case HintType.revealTile:
        return EconomyConfig.hintRevealTilePrice;
      case HintType.extraGuess:
        return EconomyConfig.hintExtraGuessPrice;
    }
  }

  bool canAfford(UserEconomyModel wallet, HintType hint) =>
      wallet.coins >= priceFor(hint);

  /// Returns true if the hint was granted (coins deducted successfully).
  Future<bool> useHint({
    required String uid,
    required HintType hint,
    required UserEconomyModel wallet,
    String? roomId,
  }) async {
    if (!canAfford(wallet, hint)) return false;

    final type = hint == HintType.revealTile
        ? TransactionType.hintRevealTile
        : TransactionType.hintExtraGuess;

    return _economyService.spendCoins(
      uid: uid,
      amount: priceFor(hint),
      type: type,
      roomId: roomId,
    );
  }
}
