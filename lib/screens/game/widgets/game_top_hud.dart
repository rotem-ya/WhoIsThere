import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/game_constants.dart';
import '../../../models/player_model.dart';
import '../../../providers/providers.dart';
import '../../../services/reward_calculator.dart';
import '../../../widgets/common/player_avatar.dart';
import '../../../widgets/economy/coin_display.dart';

String? _prizePressureLabel(double ratio) {
  if (ratio >= 0.92) return 'פרס מינימלי';
  if (ratio >= 0.85) return 'הזדמנות אחרונה';
  if (ratio >= 0.75) return 'סיכון עולה';
  return null;
}

class TopHud extends StatelessWidget {
  final List<PlayerModel> players;
  final String? currentPlayerId;
  final String currentPlayerName;
  final String revealedText;
  final VoidCallback onBack;
  final bool isMyTurn;
  final TurnPhase turnPhase;
  final bool isMyGuessOpportunity;
  final bool isMyGuessModeActive;
  final String guessModePlayerName;
  final double revealRatio;
  final bool isSolo;
  final int revealedCount;
  final int totalTiles;
  final int? guessOpportunityDeadlineMs;
  final bool isLastTile;
  final int potTotal;
  final String? guessModePlayerId;
  final Set<String> stunnedPlayerIds;
  final String roomId;
  final String? localUserId;
  final int guessBlock5Count;
  final int guessBlock10Count;
  final int blackoutCardCount;
  final bool showExposure;

  const TopHud({
    required this.players,
    required this.currentPlayerId,
    required this.currentPlayerName,
    required this.revealedText,
    required this.onBack,
    required this.isMyTurn,
    required this.turnPhase,
    required this.isMyGuessOpportunity,
    required this.isMyGuessModeActive,
    required this.guessModePlayerName,
    this.revealRatio = 0.0,
    this.isSolo = false,
    this.revealedCount = 0,
    this.totalTiles = 1,
    this.guessOpportunityDeadlineMs,
    this.isLastTile = false,
    this.potTotal = 0,
    this.guessModePlayerId,
    this.stunnedPlayerIds = const {},
    this.roomId = '',
    this.localUserId,
    this.guessBlock5Count = 0,
    this.guessBlock10Count = 0,
    this.blackoutCardCount = 0,
    this.showExposure = false,
  });

  @override
  Widget build(BuildContext context) {
    final isEndgame = revealRatio >= 0.75;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const CoinDisplay(compact: true),
                const SizedBox(width: 6),
                if (potTotal > 0) ...[
                  _PotChip(potTotal: potTotal),
                  const SizedBox(width: 4),
                ],
                _BonusPreviewChip(
                  isSolo: isSolo,
                  revealedCount: revealedCount,
                  totalTiles: totalTiles,
                ),
                const Spacer(),
                _SmallBackButton(onTap: onBack),
              ],
            ),
            const SizedBox(height: 6),
            if (players.isNotEmpty)
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF081E3A).withOpacity(0.90),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isEndgame
                        ? const Color(0xFFFF9F43).withOpacity(0.55)
                        : const Color(0xFF1890D0).withOpacity(0.50),
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0040A0).withOpacity(0.30),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: _PlayerGrid(
                  players: players,
                  guessModePlayerId: guessModePlayerId,
                  stunnedPlayerIds: stunnedPlayerIds,
                  myUid: localUserId,
                  roomId: roomId,
                  isSolo: isSolo,
                  guessBlock5Count: guessBlock5Count,
                  guessBlock10Count: guessBlock10Count,
                  blackoutCardCount: blackoutCardCount,
                  showExposure: showExposure,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Small back button ──────────────────────────────────────────────────────────

class _SmallBackButton extends StatelessWidget {
  final VoidCallback onTap;
  const _SmallBackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: const Color(0xFF0D1E30).withOpacity(0.75),
          shape: BoxShape.circle,
          border: Border.all(
            color: const Color(0xFF2A5070).withOpacity(0.45),
            width: 0.8,
          ),
        ),
        child: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white60, size: 12),
      ),
    );
  }
}

// ── Player grid ────────────────────────────────────────────────────────────────

class _PlayerGrid extends StatelessWidget {
  final List<PlayerModel> players;
  final String? guessModePlayerId;
  final Set<String> stunnedPlayerIds;
  final String? myUid;
  final String roomId;
  final bool isSolo;
  final int guessBlock5Count;
  final int guessBlock10Count;
  final int blackoutCardCount;
  final bool showExposure;

  const _PlayerGrid({
    required this.players,
    this.guessModePlayerId,
    this.stunnedPlayerIds = const {},
    this.myUid,
    this.roomId = '',
    this.isSolo = false,
    this.guessBlock5Count = 0,
    this.guessBlock10Count = 0,
    this.blackoutCardCount = 0,
    this.showExposure = false,
  });

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < players.length; i += 2) {
      if (rows.isNotEmpty) rows.add(const SizedBox(height: 4));
      rows.add(Row(
        children: [
          Expanded(
            child: _PlayerCell(
              player: players[i],
              isGuessing: players[i].id == guessModePlayerId,
              isStunned: stunnedPlayerIds.contains(players[i].id),
              isMe: players[i].id == myUid,
              myUid: myUid,
              roomId: roomId,
              isSolo: isSolo,
              guessBlock5Count: guessBlock5Count,
              guessBlock10Count: guessBlock10Count,
              blackoutCardCount: blackoutCardCount,
              showExposure: showExposure,
            ),
          ),
          if (i + 1 < players.length) ...[
            const SizedBox(width: 6),
            Expanded(
              child: _PlayerCell(
                player: players[i + 1],
                isGuessing: players[i + 1].id == guessModePlayerId,
                isStunned: stunnedPlayerIds.contains(players[i + 1].id),
                isMe: players[i + 1].id == myUid,
                myUid: myUid,
                roomId: roomId,
                isSolo: isSolo,
                guessBlock5Count: guessBlock5Count,
                guessBlock10Count: guessBlock10Count,
                blackoutCardCount: blackoutCardCount,
                showExposure: showExposure,
              ),
            ),
          ] else
            const Expanded(child: SizedBox()),
        ],
      ));
    }
    return Column(mainAxisSize: MainAxisSize.min, children: rows);
  }
}

// ── Player cell — tap opens action sheet ──────────────────────────────────────

class _PlayerCell extends ConsumerWidget {
  final PlayerModel player;
  final bool isGuessing;
  final bool isStunned;
  final bool isMe;
  final String? myUid;
  final String roomId;
  final bool isSolo;
  final int guessBlock5Count;
  final int guessBlock10Count;
  final int blackoutCardCount;
  final bool showExposure;

  const _PlayerCell({
    required this.player,
    this.isGuessing = false,
    this.isStunned = false,
    this.isMe = false,
    this.myUid,
    this.roomId = '',
    this.isSolo = false,
    this.guessBlock5Count = 0,
    this.guessBlock10Count = 0,
    this.blackoutCardCount = 0,
    this.showExposure = false,
  });

  bool get _canTarget =>
      !isMe && roomId.isNotEmpty && myUid != null;

  void _showActionSheet(BuildContext context) {
    if (!_canTarget) return;
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _PlayerActionSheet(
        targetPlayer: player,
        roomId: roomId,
        myUid: myUid!,
        guessBlock5Count: guessBlock5Count,
        guessBlock10Count: guessBlock10Count,
        blackoutCardCount: blackoutCardCount,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rawName = player.name.length > 9 ? player.name.substring(0, 9) : player.name;
    final name = player.isHost ? '$rawName ⭐' : rawName;
    return GestureDetector(
      onTap: _canTarget ? () => _showActionSheet(context) : null,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isStunned
                  ? const Color(0xFF2A1040).withOpacity(0.75)
                  : isGuessing
                      ? const Color(0xFF1A2E10).withOpacity(0.75)
                      : const Color(0xFF0D1E30).withOpacity(0.55),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isStunned
                    ? const Color(0xFF8B4FBF).withOpacity(0.55)
                    : isGuessing
                        ? const Color(0xFF4CAF50).withOpacity(0.50)
                        : const Color(0xFF2A5070).withOpacity(0.30),
                width: isStunned || isGuessing ? 1.0 : 0.8,
              ),
            ),
            child: Row(
              children: [
                PlayerAvatar(
                  name: player.name,
                  seed: player.name,
                  radius: 10,
                  avatarId: player.avatarId,
                  frameId: player.frameId,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isGuessing ? const Color(0xFF80C080) : Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (isStunned)
                  const Padding(
                    padding: EdgeInsets.only(left: 3),
                    child: Text('🔒', style: TextStyle(fontSize: 9)),
                  )
                else if (isGuessing)
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Text('✍', style: TextStyle(fontSize: 10)),
                  ),
                // Private rooms: show how many times this player has already
                // seen the current image (0 = first time) next to their name.
                if (showExposure && !player.isBot)
                  Padding(
                    padding: const EdgeInsets.only(left: 3),
                    child: Text(
                      '👁${player.priorExposureCount}',
                      style: const TextStyle(fontSize: 9, color: Colors.amber),
                    ),
                  ),
                const SizedBox(width: 4),
                Text(
                  '${player.score}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.45),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: -7,
            right: -5,
            child: _DiscoveredMicroBadge(count: player.discoveredCount),
          ),
        ],
      ),
    );
  }
}

// ── Player action sheet ────────────────────────────────────────────────────────

class _PlayerActionSheet extends ConsumerStatefulWidget {
  final PlayerModel targetPlayer;
  final String roomId;
  final String myUid;
  final int guessBlock5Count;
  final int guessBlock10Count;
  final int blackoutCardCount;

  const _PlayerActionSheet({
    required this.targetPlayer,
    required this.roomId,
    required this.myUid,
    required this.guessBlock5Count,
    required this.guessBlock10Count,
    required this.blackoutCardCount,
  });

  @override
  ConsumerState<_PlayerActionSheet> createState() => _PlayerActionSheetState();
}

class _PlayerActionSheetState extends ConsumerState<_PlayerActionSheet> {
  bool _busy = false;

  Future<void> _useGuessBlock(bool is10s) async {
    if (_busy) return;
    setState(() => _busy = true);
    HapticFeedback.mediumImpact();
    await ref.read(roomServiceProvider).applyGuessBlockCard(
      roomId: widget.roomId,
      actorUid: widget.myUid,
      targetUid: widget.targetPlayer.id,
      is10s: is10s,
    );
    if (mounted) Navigator.pop(context);
  }

  Future<void> _useBlackout() async {
    if (_busy) return;
    setState(() => _busy = true);
    HapticFeedback.mediumImpact();
    await ref.read(roomServiceProvider).applyBlackoutCard(
      roomId: widget.roomId,
      actorUid: widget.myUid,
      targetUid: widget.targetPlayer.id,
    );
    if (mounted) Navigator.pop(context);
  }

  void _goToStore(BuildContext ctx) {
    Navigator.pop(ctx);
    ScaffoldMessenger.of(ctx)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('החנות זמינה בין משחקים 🛍️', textDirection: TextDirection.rtl),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final hasAny = widget.guessBlock5Count > 0 ||
        widget.guessBlock10Count > 0 ||
        widget.blackoutCardCount > 0;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF07101F),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: const Color(0xFF8B4FBF).withOpacity(0.35), width: 1),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).viewPadding.bottom +
            24,
        top: 8,
        left: 20,
        right: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(
            'פעולות על ${widget.targetPlayer.name}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 16),
          if (!hasAny) ...[
            const Text('🃏', style: TextStyle(fontSize: 36)),
            const SizedBox(height: 8),
            Text(
              'אין לך כרטיסים כרגע',
              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              'ניתן לרכוש בחנות',
              style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 13),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => _goToStore(context),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF8B4FBF),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('פתח חנות', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ] else ...[
            if (widget.guessBlock5Count > 0)
              _CardActionButton(
                icon: '⏱️',
                label: 'חסום ניחוש 5 שניות',
                count: widget.guessBlock5Count,
                color: const Color(0xFF1A6CB0),
                busy: _busy,
                onTap: () => _useGuessBlock(false),
              ),
            if (widget.guessBlock10Count > 0) ...[
              const SizedBox(height: 10),
              _CardActionButton(
                icon: '⏱️',
                label: 'חסום ניחוש 10 שניות',
                count: widget.guessBlock10Count,
                color: const Color(0xFF0A4A8A),
                busy: _busy,
                onTap: () => _useGuessBlock(true),
              ),
            ],
            if (widget.blackoutCardCount > 0) ...[
              const SizedBox(height: 10),
              _CardActionButton(
                icon: '🌑',
                label: 'השחר מסך 5 שניות',
                count: widget.blackoutCardCount,
                color: const Color(0xFF1A0A2E),
                busy: _busy,
                onTap: _useBlackout,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _CardActionButton extends StatelessWidget {
  final String icon;
  final String label;
  final int count;
  final Color color;
  final bool busy;
  final VoidCallback onTap;

  const _CardActionButton({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: busy ? null : onTap,
      child: AnimatedOpacity(
        opacity: busy ? 0.5 : 1.0,
        duration: const Duration(milliseconds: 180),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.75),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.15), width: 0.8),
          ),
          child: Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'x$count',
                  style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Discovered micro badge ────────────────────────────────────────────────────

class _DiscoveredMicroBadge extends StatelessWidget {
  final int count;
  const _DiscoveredMicroBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: const Color(0xFF04101E),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF4A8BAA).withOpacity(0.5), width: 0.7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🌍', style: TextStyle(fontSize: 7)),
          const SizedBox(width: 1),
          Text(
            '$count',
            style: const TextStyle(
              color: Color(0xFF87CEEB),
              fontSize: 8,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Pot chip ──────────────────────────────────────────────────────────────────

class _PotChip extends StatelessWidget {
  final int potTotal;
  const _PotChip({required this.potTotal});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1000).withOpacity(0.85),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFFB300).withOpacity(0.75), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🏆', style: TextStyle(fontSize: 11)),
          const SizedBox(width: 3),
          Text(
            '$potTotal',
            style: const TextStyle(
              color: Color(0xFFFFE14D),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Prize potential chip ──────────────────────────────────────────────────────

class _BonusPreviewChip extends StatefulWidget {
  final bool isSolo;
  final int revealedCount;
  final int totalTiles;

  const _BonusPreviewChip({
    required this.isSolo,
    required this.revealedCount,
    required this.totalTiles,
  });

  @override
  State<_BonusPreviewChip> createState() => _BonusPreviewChipState();
}

class _BonusPreviewChipState extends State<_BonusPreviewChip>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  late Animation<double> _scale;
  late Animation<double> _flashOpacity;
  late Animation<double> _shake;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 480));
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.84), weight: 28),
      TweenSequenceItem(tween: Tween(begin: 0.84, end: 1.0), weight: 72),
    ]).animate(CurvedAnimation(parent: _anim, curve: Curves.easeInOut));
    _flashOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.36), weight: 22),
      TweenSequenceItem(tween: Tween(begin: 0.36, end: 0.0), weight: 78),
    ]).animate(_anim);
    _shake = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -3.0), weight: 18),
      TweenSequenceItem(tween: Tween(begin: -3.0, end: 3.0), weight: 44),
      TweenSequenceItem(tween: Tween(begin: 3.0, end: 0.0), weight: 38),
    ]).animate(_anim);
  }

  @override
  void didUpdateWidget(_BonusPreviewChip old) {
    super.didUpdateWidget(old);
    if (widget.revealedCount > old.revealedCount) _anim.forward(from: 0.0);
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final coins = RewardCalculator.calculateCurrentPrizePotential(
      isSolo: widget.isSolo,
      revealedCount: widget.revealedCount,
      totalTiles: widget.totalTiles,
    );
    final maxCoins = RewardCalculator.calculateCurrentPrizePotential(
      isSolo: widget.isSolo,
      revealedCount: 0,
      totalTiles: widget.totalTiles,
    );
    final coinRatio = maxCoins > 0 ? coins / maxCoins : 0.0;
    final ratio = widget.totalTiles > 0 ? widget.revealedCount / widget.totalTiles : 0.0;
    final pressureLabel = _prizePressureLabel(ratio);

    final Color valueColor;
    if (coinRatio >= 0.70) {
      valueColor = const Color(0xFF4CAF50);
    } else if (coinRatio >= 0.45) {
      valueColor = const Color(0xFFD4AF37);
    } else if (coinRatio >= 0.33) {
      valueColor = const Color(0xFFFF9F43);
    } else {
      valueColor = const Color(0xFFFF3B30);
    }

    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) => Transform.translate(
        offset: Offset(_shake.value, 0),
        child: Transform.scale(
          scale: _scale.value,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: _flashOpacity.value > 0.01
                  ? const Color(0xFFFF6B35).withOpacity(_flashOpacity.value)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(5),
            ),
            child: child,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (pressureLabel != null)
            Text(pressureLabel,
                style: const TextStyle(
                    color: Color(0xFFFF3B30),
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    height: 1.1)),
          Text('+$coins 🔥',
              style: TextStyle(color: valueColor, fontSize: 10, fontWeight: FontWeight.w900, height: 1)),
        ],
      ),
    );
  }
}
