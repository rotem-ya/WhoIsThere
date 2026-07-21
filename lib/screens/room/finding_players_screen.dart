import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'dart:math' as math;

import '../../core/theme/candy_theme.dart';
import '../../providers/providers.dart';
import '../../services/qa_logger_service.dart';
import '../../widgets/common/pressable_scale.dart';

/// Shown after quick-game creation while bots fill the remaining slots.
/// First bot joins after [_firstBotDelayMs] ms, then every [_botIntervalMs] ms.
class FindingPlayersScreen extends ConsumerStatefulWidget {
  final String roomId;
  final int targetPlayers;

  const FindingPlayersScreen({
    super.key,
    required this.roomId,
    required this.targetPlayers,
  });

  @override
  ConsumerState<FindingPlayersScreen> createState() =>
      _FindingPlayersScreenState();
}

class _FindingPlayersScreenState extends ConsumerState<FindingPlayersScreen>
    with TickerProviderStateMixin {
  // Keep a short real-player search window, then fill with bots quickly so a
  // quick game actually starts within a few seconds instead of feeling stuck.
  static const int _firstBotDelayMs = 2500;
  static const int _botIntervalMs = 1200;
  static const int _maxWaitMs = 60000;

  late final AnimationController _dotAnim;
  late final AnimationController _waveAnim;
  Timer? _timeoutTimer;
  final List<Timer> _timers = [];
  int _botsAdded = 0;
  final List<String> _joinedNames = [];
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    _dotAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    _waveAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();

    _scheduleNextBot(delay: _firstBotDelayMs);

    _timeoutTimer = Timer(const Duration(milliseconds: _maxWaitMs), () {
      if (!mounted || _starting) return;
      for (final t in _timers) t.cancel();
      context.go('/home');
    });
  }

  void _scheduleNextBot({required int delay}) {
    final t = Timer(Duration(milliseconds: delay), () async {
      if (!mounted) return;
      await _addNextBot();
    });
    _timers.add(t);
  }

  Future<void> _addNextBot() async {
    final currentRoom =
        await ref.read(roomStreamProvider(widget.roomId).future);
    if (currentRoom == null || !mounted) return;

    // Count how many humans joined since we created the room.
    final totalNeeded = widget.targetPlayers;
    final totalNow = currentRoom.players.length;

    if (totalNow >= totalNeeded) {
      _startGame();
      return;
    }

    _botsAdded++;
    final botIndex = _botsAdded + 1; // 2, 3, 4…
    QaLoggerService.instance.log(
        'HOME', 'FINDING_PLAYERS_BOT_JOIN botIndex=$botIndex roomId=${widget.roomId.substring(0, widget.roomId.length.clamp(0, 6))}');
    await ref.read(roomServiceProvider).addBotToRoom(widget.roomId, botIndex);

    if (!mounted) return;
    final name = 'שחקן $botIndex';
    setState(() => _joinedNames.add(name));
    HapticFeedback.lightImpact();

    // Fetch fresh room and check if we're done.
    final updatedRoom =
        await ref.read(roomStreamProvider(widget.roomId).future);
    if (updatedRoom == null || !mounted) return;

    if (updatedRoom.players.length >= totalNeeded) {
      _startGame();
    } else {
      _scheduleNextBot(delay: _botIntervalMs);
    }
  }

  Future<void> _startGame() async {
    if (_starting || !mounted) return;
    _starting = true;
    _timeoutTimer?.cancel();
    for (final t in _timers) {
      t.cancel();
    }
    try {
      await ref.read(roomServiceProvider).startGameDirectly(widget.roomId);
      ref.read(currentRoomIdProvider.notifier).state = widget.roomId;
      if (mounted) context.go('/game/${widget.roomId}');
    } catch (e) {
      QaLoggerService.instance
          .log('GAME', 'START_GAME_FAILED roomId=${widget.roomId.substring(0, widget.roomId.length.clamp(0, 6))} error=$e');
      if (mounted) context.go('/home');
    }
  }

  Future<void> _cancel() async {
    for (final t in _timers) {
      t.cancel();
    }
    final user = ref.read(currentUserProvider).value;
    if (user != null) {
      await ref.read(roomServiceProvider).leaveRoom(widget.roomId, user.id);
    }
    if (mounted) context.go('/home');
  }

  @override
  void dispose() {
    _dotAnim.dispose();
    _waveAnim.dispose();
    _timeoutTimer?.cancel();
    for (final t in _timers) {
      t.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final roomAsync = ref.watch(roomStreamProvider(widget.roomId));

    // If someone else started the game (e.g. host pressed start), follow.
    roomAsync.whenData((room) {
      if (room?.phase.name == 'playing' && !_starting) {
        _starting = true;
        ref.read(currentRoomIdProvider.notifier).state = widget.roomId;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) context.go('/game/${widget.roomId}');
        });
      }
    });

    final playerCount = roomAsync.valueOrNull?.players.length ?? 1;
    final target = widget.targetPlayers;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) _cancel();
      },
      child: Scaffold(
        backgroundColor: Candy.bgBottom,
        body: Stack(
          children: [
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(gradient: Candy.bg),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Branded hero: a mini board whose tiles reveal in a wave,
                    // echoing the game's core mechanic instead of a spinner.
                    Center(
                      child: _MatchmakingTiles(anim: _waveAnim),
                    ),
                    const SizedBox(height: 30),

                    // Title with an animated ellipsis.
                    AnimatedBuilder(
                      animation: _dotAnim,
                      builder: (context, _) {
                        final dots = '.' * (1 + (_dotAnim.value * 2.99).floor());
                        return Text(
                          'מחפש יריבים$dots',
                          textAlign: TextAlign.center,
                          textDirection: TextDirection.rtl,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    // Slot-fill row: one pip per needed player, filling in.
                    _SlotRow(filled: playerCount, total: target),
                    const SizedBox(height: 10),
                    Text(
                      '$playerCount מתוך $target',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Candy.teal.withOpacity(0.9),
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 22),

                    // Joined players list
                    if (_joinedNames.isNotEmpty)
                      ..._joinedNames.map(
                        (name) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_circle_rounded,
                                  color: Color(0xFF4CAF50), size: 18),
                              const SizedBox(width: 8),
                              Text(
                                '$name הצטרף',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    const SizedBox(height: 40),

                    // Cancel button
                    Center(
                      child: PressableScale(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _cancel();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 28, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.07),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.15)),
                          ),
                          child: const Text(
                            'ביטול',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A 3x3 mini board whose tiles brighten in a diagonal wave, cycling through
/// the Candy accents — a branded stand-in for a loading spinner that nods to
/// the game's tile-reveal mechanic.
class _MatchmakingTiles extends StatelessWidget {
  final Animation<double> anim;
  const _MatchmakingTiles({required this.anim});

  static const _accents = [
    Candy.teal,
    Candy.pink,
    Candy.tangerine,
    Candy.blue,
    Candy.gold,
  ];

  @override
  Widget build(BuildContext context) {
    const grid = 3;
    const tile = 34.0;
    const gap = 8.0;
    const side = grid * tile + (grid - 1) * gap;
    return SizedBox(
      width: side,
      height: side,
      child: AnimatedBuilder(
        animation: anim,
        builder: (context, _) {
          final phase = anim.value * 2 * math.pi;
          return Stack(
            children: [
              for (var r = 0; r < grid; r++)
                for (var c = 0; c < grid; c++)
                  Positioned(
                    left: c * (tile + gap),
                    top: r * (tile + gap),
                    width: tile,
                    height: tile,
                    child: _waveTile(r, c, phase),
                  ),
            ],
          );
        },
      ),
    );
  }

  Widget _waveTile(int r, int c, double phase) {
    // Diagonal wave: distance along the diagonal sets the phase offset.
    final d = (r + c) / 4.0; // 0..1
    final t = (math.sin(phase - d * 2 * math.pi) + 1) / 2; // 0..1
    final accent = _accents[(r * 3 + c) % _accents.length];
    final lit = Color.lerp(
        Colors.white.withOpacity(0.06), accent, Curves.easeInOut.transform(t))!;
    return Container(
      decoration: BoxDecoration(
        color: lit,
        borderRadius: BorderRadius.circular(9),
        boxShadow: t > 0.6
            ? [BoxShadow(color: accent.withOpacity(0.5 * t), blurRadius: 12)]
            : null,
      ),
    );
  }
}

/// One pip per needed player; pips fill (and pop) as players join.
class _SlotRow extends StatelessWidget {
  final int filled;
  final int total;
  const _SlotRow({required this.filled, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < total; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: AnimatedScale(
              scale: i < filled ? 1.0 : 0.7,
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutBack,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < filled ? Candy.teal : Colors.white.withOpacity(0.12),
                  border: Border.all(
                    color: i < filled
                        ? Candy.teal
                        : Colors.white.withOpacity(0.25),
                    width: 1.4,
                  ),
                  boxShadow: i < filled
                      ? [BoxShadow(color: Candy.teal.withOpacity(0.5), blurRadius: 8)]
                      : null,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
