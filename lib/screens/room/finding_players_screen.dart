import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_styles.dart';
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
  static const int _firstBotDelayMs = 10000;
  static const int _botIntervalMs = 5000;
  static const int _maxWaitMs = 60000;

  late final AnimationController _dotAnim;
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
    final humanCount = currentRoom.players.values.where((p) => !p.isBot).length;
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
    } catch (_) {
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
        backgroundColor: AppStyles.navyTop,
        body: Stack(
          children: [
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(gradient: AppStyles.backgroundGradient),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Pulsing search icon
                    Center(
                      child: AnimatedBuilder(
                        animation: _dotAnim,
                        builder: (context, _) => Opacity(
                          opacity: 0.6 + _dotAnim.value * 0.4,
                          child: const Icon(
                            Icons.search_rounded,
                            size: 72,
                            color: AppStyles.bananaYellow,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Title
                    const Text(
                      'מחפש שחקנים...',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Player count progress
                    Text(
                      '$playerCount / $target שחקנים',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppStyles.cyanGlow.withOpacity(0.85),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 24),

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
