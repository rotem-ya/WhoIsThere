import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_animate/flutter_animate.dart';

import '../../core/constants/economy_config.dart';
import '../../core/constants/game_constants.dart';
import '../../core/theme/app_styles.dart';
import '../../providers/providers.dart';
import '../../widgets/common/banner_ad_widget.dart';
import '../../services/feedback_service.dart';
import '../../services/qa_logger_service.dart';
import '../../widgets/common/ambient_background.dart';
import '../../widgets/common/pressable_scale.dart';
import '../../widgets/economy/coin_display.dart';
import '../../widgets/economy/coin_icon.dart';
import '../../widgets/economy/daily_reward_sheet.dart';
import '../../models/room_model.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  // Persists across route remounts — intro plays only on first visit per session.
  static bool _introPlayed = false;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late final bool _doIntro;
  bool _isCreating = false;
  int? _loadingPlayers;
  DateTime? _lastBackPressedAt;
  // Test branch: difficulty chosen for the next quick game (picker below).
  Difficulty _quickDifficulty = Difficulty.easy;

  @override
  void initState() {
    super.initState();
    _doIntro = !HomeScreen._introPlayed;
    HomeScreen._introPlayed = true;
    QaLoggerService.instance.log('HOME', 'HOME_SCREEN_OPENED');
  }

  /// Test-branch difficulty picker. Returns the chosen difficulty, or null if
  /// the player dismissed the sheet.
  Future<Difficulty?> _pickDifficulty() {
    // Two game types only: regular 6×6, and fast 15×15 (1 card/sec).
    const options = [
      Difficulty.easy,
      Difficulty.giant,
    ];
    return showModalBottomSheet<Difficulty>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          padding: EdgeInsets.fromLTRB(
              20, 16, 20, 20 + MediaQuery.paddingOf(ctx).bottom),
          decoration: const BoxDecoration(
            color: Color(0xFF0D1E30),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('בחר רמת קושי',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 14),
              for (final d in options)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GestureDetector(
                    onTap: () => Navigator.pop(ctx, d),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withOpacity(0.12)),
                      ),
                      child: Row(
                        children: [
                          Text(d == Difficulty.giant ? '⚡' : '🟦',
                              style: const TextStyle(fontSize: 22)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                                d == Difficulty.giant ? '15×15 מהיר' : 'רגיל',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800)),
                          ),
                          Text(
                              d == Difficulty.giant
                                  ? 'קלף/שנייה'
                                  : '${d.gridSize}×${d.gridSize}',
                              style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startQuickGame(int targetPlayers, {bool bypassCoinCheck = false}) async {
    if (_isCreating) return;
    QaLoggerService.instance.log('HOME', 'TAP_QUICK_GAME players=$targetPlayers');
    FeedbackService.click();

    // Test branch: let the player pick the difficulty before a quick game
    // (shown once; the insufficient-coins re-entry reuses the choice).
    if (!bypassCoinCheck) {
      final picked = await _pickDifficulty();
      if (picked == null) return; // cancelled
      _quickDifficulty = picked;
    }

    // Block entry if insufficient coins (skipped when re-entering after the
    // insufficient-coins dialog already topped the wallet up).
    if (!bypassCoinCheck) {
      final wallet = ref.read(walletProvider).valueOrNull;
      final coins = wallet?.coins ?? 0;
      if (coins < EconomyConfig.gameEntryFee) {
        QaLoggerService.instance.log('HOME', 'QUICK_GAME_BLOCKED_INSUFFICIENT_COINS coins=$coins');
        if (mounted) _showInsufficientCoinsDialog(() => _startQuickGame(targetPlayers, bypassCoinCheck: true));
        return;
      }
    }

    setState(() {
      _isCreating = true;
      _loadingPlayers = targetPlayers;
    });

    try {
      final user = await ref.read(currentUserProvider.future);
      if (user == null) return;

      QaLoggerService.instance.log('HOME', 'QUICK_GAME_ATTEMPT players=$targetPlayers');

      final roomSvc = ref.read(roomServiceProvider);

      // Quick-match against real players who have seen the candidate image the
      // SAME number of times. Try to find a compatible waiting room twice before
      // falling back to creating our own (bots then fill it on the waiting screen).
      final myExposure = await roomSvc.exposureCountsFor(user.id);
      QaLoggerService.instance.log('HOME', 'QUICK_GAME_MATCH_SEARCH images=${myExposure.length}');

      RoomModel? existingRoom = await roomSvc.findMatchRoom(myExposure);
      if (existingRoom == null) {
        await Future.delayed(const Duration(seconds: 2));
        if (!mounted) return;
        existingRoom = await roomSvc.findMatchRoom(myExposure);
      }

      String roomId;
      if (existingRoom != null) {
        // Join the found room
        QaLoggerService.instance.log('HOME', 'QUICK_GAME_JOIN_EXISTING id=${existingRoom.id}');
        await roomSvc.joinRoom(
          code: existingRoom.code,
          userId: user.id,
          userName: user.name,
          userPhotoUrl: user.photoUrl,
        );
        roomId = existingRoom.id;
      } else {
        // Create a new public room; bots join on the waiting screen
        final room = await roomSvc.createRoom(
          hostId: user.id,
          hostName: user.name,
          hostPhotoUrl: user.photoUrl,
          playerCount: 1,
          isPublicRoom: true,
          difficulty: _quickDifficulty,
        );
        roomId = room.id;
        QaLoggerService.instance.log('HOME', 'QUICK_GAME_SUCCESS code=${room.code}');
      }

      ref.read(currentRoomIdProvider.notifier).state = roomId;

      final shortId = roomId.substring(0, roomId.length.clamp(0, 6));
      QaLoggerService.instance.log('HOME', 'QUICK_GAME_NAVIGATED dest=/finding-players/$shortId target=$targetPlayers');
      if (mounted) context.go('/finding-players/$roomId?target=$targetPlayers');
    } catch (e) {
      final msg = e.toString();
      QaLoggerService.instance.log('HOME', 'QUICK_GAME_ERROR ${msg.length > 60 ? msg.substring(0, 60) : msg}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('יצירת המשחק נכשלה: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCreating = false;
          _loadingPlayers = null;
        });
      }
    }
  }

  void _showJoinDialog() {
    QaLoggerService.instance.log('HOME', 'TAP_JOIN_ROOM');
    QaLoggerService.instance.log('HOME', 'JOIN_ROOM_SCREEN_OPENED');
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => const _JoinCodeDialog(),
    );
  }

  void _showFriendsSheet() {
    QaLoggerService.instance.log('HOME', 'TAP_FRIENDS_SHEET');
    final navBarPadding = MediaQuery.paddingOf(context).bottom;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + navBarPadding),
          decoration: const BoxDecoration(
            color: Color(0xFF0D1E30),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'שחק עם חברים',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 16),
              _FriendsSheetOption(
                icon: Icons.add_circle_outline_rounded,
                iconColor: const Color(0xFF87CEEB),
                title: 'פתח חדר',
                subtitle: 'צור חדר וזמן חברים בקוד',
                onTap: () {
                  Navigator.of(ctx).pop();
                  _createPrivateRoom();
                },
              ),
              const SizedBox(height: 10),
              _FriendsSheetOption(
                icon: Icons.key_rounded,
                iconColor: const Color(0xFF81C784),
                title: 'יש לי קוד',
                subtitle: 'הצטרף לחדר של חבר',
                onTap: () {
                  Navigator.of(ctx).pop();
                  _showJoinDialog();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createPrivateRoom({bool bypassCoinCheck = false}) async {
    if (_isCreating) return;
    QaLoggerService.instance.log('HOME', 'TAP_CREATE_ROOM');
    FeedbackService.click();

    if (!bypassCoinCheck) {
      final wallet = ref.read(walletProvider).valueOrNull;
      final coins = wallet?.coins ?? 0;
      if (coins < EconomyConfig.gameEntryFee) {
        QaLoggerService.instance.log('HOME', 'CREATE_ROOM_BLOCKED_INSUFFICIENT_COINS coins=$coins');
        if (mounted) _showInsufficientCoinsDialog(() => _createPrivateRoom(bypassCoinCheck: true));
        return;
      }
    }

    setState(() {
      _isCreating = true;
      _loadingPlayers = null;
    });

    try {
      final user = await ref.read(currentUserProvider.future);
      if (user == null) return;

      QaLoggerService.instance.log('HOME', 'CREATE_ROOM_ATTEMPT playerCount=default');
      final room = await ref.read(roomServiceProvider).createRoom(
            hostId: user.id,
            hostName: user.name,
            hostPhotoUrl: user.photoUrl,
          );

      final shortId = room.id.substring(0, room.id.length.clamp(0, 6));
      QaLoggerService.instance.log('HOME', 'CREATE_ROOM_SUCCESS code=${room.code} id=$shortId');
      ref.read(currentRoomIdProvider.notifier).state = room.id;
      if (mounted) context.go('/lobby/${room.id}');
    } catch (e) {
      final msg = e.toString();
      QaLoggerService.instance.log('HOME', 'CREATE_ROOM_ERROR ${msg.length > 60 ? msg.substring(0, 60) : msg}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('יצירת החדר נכשלה: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCreating = false;
          _loadingPlayers = null;
        });
      }
    }
  }

  /// Out-of-coins recovery sheet. Offers the free, in-app ways to get back into
  /// a game — daily reward, a rewarded ad, and one free game per day — plus the
  /// store. [onProceed] re-attempts the blocked action once the wallet has been
  /// topped up (it bypasses the coin check to avoid a stream-update race).
  void _showInsufficientCoinsDialog(VoidCallback onProceed) {
    final navBarPadding = MediaQuery.paddingOf(context).bottom;
    final wallet = ref.read(walletProvider).valueOrNull;
    final coins = wallet?.coins ?? 0;
    final nowUtc = DateTime.now().toUtc();

    bool sameUtcDay(DateTime? d) =>
        d != null && d.year == nowUtc.year && d.month == nowUtc.month && d.day == nowUtc.day;

    final dailyAvailable = !sameUtcDay(wallet?.lastDailyRewardAt);
    final adsUsedToday = sameUtcDay(wallet?.adRewardWindowStart) ? (wallet?.adRewardsTodayCount ?? 0) : 0;
    final adsAvailable = adsUsedToday < EconomyConfig.maxAdRewardsPerDay;
    final freeGameAvailable = !sameUtcDay(wallet?.lastFreeEntryAt);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) {
        bool busy = false;
        return StatefulBuilder(
          builder: (sheetCtx, setSheet) {
            final uid = ref.read(firebaseUserProvider).valueOrNull?.uid;

            Future<void> run(Future<bool> Function() action, {required bool proceed}) async {
              if (busy || uid == null) return;
              setSheet(() => busy = true);
              bool ok = false;
              try { ok = await action(); } catch (_) { ok = false; }
              if (!mounted) return;
              if (ok) {
                if (Navigator.canPop(sheetCtx)) Navigator.of(sheetCtx).pop();
                if (proceed) onProceed();
              } else {
                setSheet(() => busy = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('לא ניתן כרגע — נסה דרך אחרת')),
                );
              }
            }

            Widget optBtn(String label, List<Color> grad, VoidCallback onTap) {
              return Padding(
                padding: const EdgeInsets.only(top: 10),
                child: GestureDetector(
                  onTap: busy ? null : onTap,
                  child: Opacity(
                    opacity: busy ? 0.5 : 1,
                    child: Container(
                      width: double.infinity,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: grad, begin: Alignment.topCenter, end: Alignment.bottomCenter),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Text(label,
                            textDirection: TextDirection.rtl,
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
                      ),
                    ),
                  ),
                ),
              );
            }

            final economy = ref.read(economyServiceProvider);

            return Container(
              padding: EdgeInsets.fromLTRB(24, 18, 24, 22 + navBarPadding),
              decoration: const BoxDecoration(
                color: Color(0xFF0D1E30),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CoinIcon(size: 38),
                  const SizedBox(height: 10),
                  const Text('אין מספיק מטבעות',
                      style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
                      textDirection: TextDirection.rtl),
                  const SizedBox(height: 4),
                  Text.rich(
                    TextSpan(text: 'יש לך $coins · כניסה עולה ${EconomyConfig.gameEntryFee} ', children: [coinSpan(size: 13)]),
                    style: const TextStyle(color: Colors.white60, fontSize: 13.5),
                    textDirection: TextDirection.rtl,
                  ),
                  const SizedBox(height: 14),

                  if (freeGameAvailable)
                    optBtn('🎮 שחק עכשיו חינם (פעם ביום)', const [Color(0xFF2EBd6B), Color(0xFF1B8F4D)],
                        () => run(() => economy.claimFreeEntry(uid!), proceed: true)),
                  if (dailyAvailable)
                    optBtn('🎁 קבל פרס יומי', const [Color(0xFFE0A020), Color(0xFFB47800)],
                        () => run(() async => (await economy.claimDailyReward(uid!)) != null, proceed: true)),
                  if (adsAvailable)
                    optBtn('📺 צפה בפרסומת (+${EconomyConfig.adRewardCoins})', const [Color(0xFF20A8E0), Color(0xFF0868A8)],
                        () => run(() => economy.applyAdReward(uid!), proceed: true)),

                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: GestureDetector(
                      onTap: () { if (Navigator.canPop(sheetCtx)) Navigator.of(sheetCtx).pop(); context.push('/store'); },
                      child: Container(
                        width: double.infinity,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: const Center(
                          child: Text('💎 לחנות המטבעות',
                              textDirection: TextDirection.rtl,
                              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Wraps [w] with a fade+rise entrance only on first visit.
  Widget _step(Widget w, {required int delayMs, required int durationMs, double dy = 0}) {
    if (!_doIntro) return w;
    var a = w.animate().fadeIn(
      delay: Duration(milliseconds: delayMs),
      duration: Duration(milliseconds: durationMs),
      curve: Curves.easeOut,
    );
    if (dy != 0) {
      a = a.moveY(
        begin: dy,
        end: 0,
        delay: Duration(milliseconds: delayMs),
        duration: Duration(milliseconds: durationMs),
        curve: Curves.easeOut,
      );
    }
    return a;
  }

  void _handleHomeBack() {
    final now = DateTime.now();
    final shouldExit = _lastBackPressedAt != null &&
        now.difference(_lastBackPressedAt!) < const Duration(seconds: 2);

    if (shouldExit) {
      SystemNavigator.pop();
      return;
    }

    _lastBackPressedAt = now;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('לחיצה נוספת ליציאה מהמשחק'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(firstTimeBonusProvider, (_, next) {
      if (!next || !mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 קיבלת 100 מטבעות כמתנת כניסה!'),
          duration: Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Color(0xFF1B5E20),
        ),
      );
    });

    return Directionality(
      textDirection: TextDirection.rtl,
      child: PopScope(
        canPop: false,
        onPopInvoked: (didPop) {
          if (didPop) return;
          _handleHomeBack();
        },
        child: Scaffold(
          backgroundColor: AppStyles.navyTop,
          body: Stack(
            children: [
              const Positioned.fill(child: _VaultBackground()),
              const Positioned.fill(
                child: RepaintBoundary(
                  child: AmbientBackground(
                    showGrid: false,
                    showOrbits: false,
                    showParticles: true,
                    goldAccent: true,
                    intensity: 0.28,
                  ),
                ),
              ),
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final verySmall = constraints.maxHeight < 640;
                    final compact = constraints.maxHeight < 760;
                    final iconSize = verySmall ? 140.0 : compact ? 170.0 : 200.0;
                    return Padding(
                      padding: EdgeInsets.symmetric(horizontal: compact ? 20 : 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(height: verySmall ? 4 : 8),
                          // ── Top bar ──────────────────────────────────
                          _step(
                            Row(
                              textDirection: TextDirection.ltr,
                              children: [
                                const _ProfileIconButton(),
                                const SizedBox(width: 8),
                                const _StoreIconButton(),
                                const SizedBox(width: 8),
                                const _SettingsIconButton(),
                                const SizedBox(width: 8),
                                const CoinDisplay(),
                                const Spacer(),
                                const _DailyRewardButton(),
                              ],
                            ),
                            delayMs: 0, durationMs: 380, dy: -10,
                          ),
                          // ── Hero grid takes all remaining vertical space ──
                          Expanded(
                            child: Center(
                              child: _step(
                                RepaintBoundary(child: _HomeHeroPeekGrid(size: iconSize)),
                                delayMs: 80, durationMs: 500, dy: 14,
                              ),
                            ),
                          ),
                          _step(
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'מה בתמונה?',
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 52,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -1.7,
                                  height: 1,
                                  shadows: const [
                                    Shadow(color: Color(0xFFD4AF37), blurRadius: 16),
                                    Shadow(color: Colors.black87, offset: Offset(0, 4), blurRadius: 10),
                                    Shadow(color: Color(0x55D4AF37), blurRadius: 48, offset: Offset(0, 8)),
                                  ],
                                ),
                              ),
                            ),
                            delayMs: 200, durationMs: 380, dy: 8,
                          ),
                          const SizedBox(height: 6),
                          _step(
                            Text(
                              'מי יזהה את המקום ראשון?',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: const Color(0xFF87CEEB).withOpacity(0.86),
                                fontSize: verySmall ? 15 : compact ? 17 : 19,
                                fontWeight: FontWeight.w800,
                                height: 1.2,
                              ),
                            ),
                            delayMs: 300, durationMs: 320,
                          ),
                          SizedBox(height: verySmall ? 10 : compact ? 14 : 20),
                          _step(
                            Column(
                              children: [
                                _QuickGameButton(
                                  players: 2,
                                  isLoading: _isCreating && _loadingPlayers == 2,
                                  onTap: _isCreating ? null : () => _startQuickGame(2),
                                ),
                                const SizedBox(height: 8),
                                _QuickGameButton(
                                  players: 3,
                                  isLoading: _isCreating && _loadingPlayers == 3,
                                  onTap: _isCreating ? null : () => _startQuickGame(3),
                                ),
                                const SizedBox(height: 8),
                                _QuickGameButton(
                                  players: 4,
                                  isLoading: _isCreating && _loadingPlayers == 4,
                                  onTap: _isCreating ? null : () => _startQuickGame(4),
                                ),
                              ],
                            ),
                            delayMs: 460, durationMs: 260, dy: 5,
                          ),
                          SizedBox(height: verySmall ? 8 : 12),
                          _step(
                            _FriendsButton(
                              isLoading: _isCreating && _loadingPlayers == null,
                              onTap: _isCreating ? null : _showFriendsSheet,
                            ),
                            delayMs: 600, durationMs: 240,
                          ),
                          SizedBox(height: verySmall ? 6 : 10),
                          const BannerAdWidget(),
                          SizedBox(height: verySmall ? 4 : 8),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VaultBackground extends StatelessWidget {
  const _VaultBackground();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: AppStyles.backgroundGradient,
      ),
      child: Stack(
        children: [
          Positioned(top: -110, right: -80, child: _Glow(color: Color(0xFFD4AF37), size: 310, opacity: 0.12)),
          Positioned(bottom: -95, left: -80, child: _Glow(color: Color(0xFF87CEEB), size: 285, opacity: 0.14)),
          Positioned(top: 190, left: 26, child: _Dot(size: 5, opacity: 0.40)),
          Positioned(top: 270, right: 34, child: _Dot(size: 4, opacity: 0.28)),
          Positioned(bottom: 190, right: 52, child: _Dot(size: 6, opacity: 0.24)),
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  final Color color;
  final double size;
  final double opacity;

  const _Glow({required this.color, required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color.withOpacity(opacity), blurRadius: 120, spreadRadius: 48)],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final double size;
  final double opacity;

  const _Dot({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(opacity)),
    );
  }
}

// ── Equal quick-game button for 2/3/4 players ─────────────────────────────

class _QuickGameButton extends StatelessWidget {
  final int players;
  final bool isLoading;
  final VoidCallback? onTap;

  const _QuickGameButton({
    required this.players,
    required this.isLoading,
    required this.onTap,
  });

  static const _configs = {
    2: (
      icon: '⚔️',
      label: '1 על 1',
      gradientColors: [Color(0xFF1A4A8A), Color(0xFF0A2356)],
      borderColor: Color(0xFF4A9EFF),
      glowColor: Color(0xFF2266CC),
    ),
    3: (
      icon: '🎯',
      label: '3 שחקנים',
      gradientColors: [Color(0xFF1A5A4A), Color(0xFF0A2E26)],
      borderColor: Color(0xFF3DCCAA),
      glowColor: Color(0xFF1A8866),
    ),
    4: (
      icon: '🏆',
      label: '4 שחקנים',
      gradientColors: [Color(0xFF3A1A6A), Color(0xFF1E0A3C)],
      borderColor: Color(0xFF9966FF),
      glowColor: Color(0xFF6633BB),
    ),
  };

  @override
  Widget build(BuildContext context) {
    final cfg = _configs[players]!;

    return PressableScale(
      onTap: onTap == null ? null : () {
        HapticFeedback.mediumImpact();
        onTap!();
      },
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 160),
        opacity: onTap == null ? 0.55 : 1,
        child: Container(
          height: 68,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: cfg.gradientColors,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: cfg.borderColor.withOpacity(0.7), width: 1.5),
            boxShadow: [
              BoxShadow(color: cfg.glowColor.withOpacity(0.35), blurRadius: 14, spreadRadius: 0, offset: const Offset(0, 4)),
            ],
          ),
          child: isLoading
              ? const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4)))
              : Row(
                  children: [
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cfg.label,
                            style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900, height: 1.1),
                          ),
                          const SizedBox(height: 3),
                          Text.rich(
                            TextSpan(
                              text: 'כניסה ${EconomyConfig.gameEntryFee} ',
                              children: [coinSpan(size: 12)],
                            ),
                            style: TextStyle(color: Colors.white.withOpacity(0.60), fontSize: 11.5, fontWeight: FontWeight.w600, height: 1),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: cfg.borderColor.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: cfg.borderColor.withOpacity(0.38), width: 1),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'קופה',
                            style: TextStyle(color: cfg.borderColor.withOpacity(0.70), fontSize: 9, fontWeight: FontWeight.w700, height: 1.1),
                          ),
                          Text.rich(
                            TextSpan(
                              text: '${EconomyConfig.gameEntryFee * players} ',
                              children: [coinSpan(size: 13)],
                            ),
                            style: TextStyle(color: cfg.borderColor, fontSize: 13, fontWeight: FontWeight.w900, height: 1.1),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                  ],
                ),
        ),
      ),
    );
  }
}

class _FriendsButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback? onTap;

  const _FriendsButton({required this.isLoading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: PressableScale(
        onTap: onTap == null ? null : () {
          HapticFeedback.lightImpact();
          onTap!();
        },
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 160),
          opacity: onTap == null ? 0.58 : 1,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
            decoration: BoxDecoration(
              color: const Color(0xFF050A14).withOpacity(0.50),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFF87CEEB).withOpacity(0.26)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isLoading)
                  const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Color(0xFF87CEEB), strokeWidth: 2))
                else
                  const Icon(Icons.people_rounded, color: Color(0xFF87CEEB), size: 19),
                const SizedBox(width: 10),
                const Text('שחק עם חברים', style: TextStyle(color: Color(0xFF87CEEB), fontSize: 16, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FriendsSheetOption extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _FriendsSheetOption({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: iconColor.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 26),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: iconColor, fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w500)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Daily reward button (top-right corner) ────────────────────────────────

class _DailyRewardButton extends ConsumerWidget {
  const _DailyRewardButton();

  static bool _isDailyRewardAvailable(DateTime? lastDailyRewardAt) {
    if (lastDailyRewardAt == null) return true;
    final now = DateTime.now().toUtc();
    final lastDay = DateTime.utc(lastDailyRewardAt.year, lastDailyRewardAt.month, lastDailyRewardAt.day);
    final today = DateTime.utc(now.year, now.month, now.day);
    return lastDay.isBefore(today);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(walletProvider).valueOrNull;
    final isAvailable = _isDailyRewardAvailable(wallet?.lastDailyRewardAt);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        if (isAvailable) {
          showDailyRewardSheet(context, ref);
        } else {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(
                content: Text('הפרס היומי כבר נאסף'),
                duration: Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
        }
      },
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: isAvailable ? 1.0 : 0.38,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF050A14).withOpacity(0.60),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isAvailable
                      ? const Color(0xFFD4AF37).withOpacity(0.70)
                      : Colors.white.withOpacity(0.15),
                  width: isAvailable ? 1.5 : 1.0,
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.card_giftcard_rounded,
                  color: Color(0xFFD4AF37),
                  size: 20,
                ),
              ),
            ),
            if (isAvailable)
              Positioned(
                top: -5,
                right: -5,
                child: Container(
                  width: 17,
                  height: 17,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4AF37),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppStyles.navyTop, width: 1.5),
                  ),
                  child: const Center(
                    child: Text(
                      '1',
                      style: TextStyle(
                        color: Color(0xFF07101F),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Profile icon button (top-left, QA access) ─────────────────────────────

class _ProfileIconButton extends ConsumerWidget {
  const _ProfileIconButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final isGuest = user?.isGuest ?? true;
    final provider = user?.provider ?? 'anonymous';
    final isGoogle = provider == 'google.com';
    final isApple = provider == 'apple.com';
    final connected = !isGuest && (isGoogle || isApple);

    final borderColor = connected
        ? const Color(0xFF35C759).withOpacity(0.65) // green when linked
        : const Color(0xFFFFB020).withOpacity(0.75); // amber when guest

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          HapticFeedback.lightImpact();
          QaLoggerService.instance.log('HOME', 'TAP_PROFILE');
          context.push('/profile');
        },
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF050A14).withOpacity(0.60),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderColor, width: 1.4),
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    color: Colors.white70,
                    size: 20,
                  ),
                ),
                Positioned(
                  right: -4,
                  bottom: -4,
                  child: _AccountStatusBadge(
                    connected: connected,
                    isGoogle: isGoogle,
                    isApple: isApple,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Account connection badge on the profile icon ──────────────────────────
// Amber "!" = guest (not linked), white "G" = Google, white  = Apple.
class _AccountStatusBadge extends StatelessWidget {
  final bool connected;
  final bool isGoogle;
  final bool isApple;
  const _AccountStatusBadge({
    required this.connected,
    required this.isGoogle,
    required this.isApple,
  });

  @override
  Widget build(BuildContext context) {
    late final Color bg;
    late final Widget glyph;
    if (!connected) {
      bg = const Color(0xFFFFB020); // amber — attention, not backed up
      glyph = const Icon(Icons.priority_high_rounded,
          size: 11, color: Color(0xFF1A1206));
    } else if (isApple) {
      bg = Colors.white;
      glyph = const Icon(Icons.apple_rounded, size: 11, color: Colors.black87);
    } else {
      bg = Colors.white;
      glyph = const Text('G',
          style: TextStyle(
              color: Color(0xFF4285F4),
              fontSize: 10,
              fontWeight: FontWeight.w900,
              height: 1));
    }
    return Container(
      width: 17,
      height: 17,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF0A1420), width: 1.5),
      ),
      child: glyph,
    );
  }
}

// ── Store icon button (top-left, next to profile) ─────────────────────────

class _StoreIconButton extends StatelessWidget {
  const _StoreIconButton();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          HapticFeedback.lightImpact();
          QaLoggerService.instance.log('HOME', 'TAP_STORE');
          context.push('/store');
        },
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF050A14).withOpacity(0.60),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withOpacity(0.15),
                  width: 1.0,
                ),
              ),
              child: const Icon(
                Icons.store_rounded,
                color: Colors.white70,
                size: 20,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Settings icon button (top-left, next to store) ───────────────────────

class _SettingsIconButton extends StatelessWidget {
  const _SettingsIconButton();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          HapticFeedback.lightImpact();
          context.push('/settings');
        },
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF050A14).withOpacity(0.60),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withOpacity(0.15),
                  width: 1.0,
                ),
              ),
              child: const Icon(
                Icons.settings_rounded,
                color: Colors.white70,
                size: 20,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Join-by-code dialog ────────────────────────────────────────────────────

class _JoinCodeDialog extends ConsumerStatefulWidget {
  const _JoinCodeDialog();

  @override
  ConsumerState<_JoinCodeDialog> createState() => _JoinCodeDialogState();
}

class _JoinCodeDialogState extends ConsumerState<_JoinCodeDialog> {
  final _controller = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final raw = _controller.text.trim();
    final code = raw.toUpperCase();
    if (code.isEmpty) {
      setState(() => _error = 'נא להזין קוד חדר');
      return;
    }

    QaLoggerService.instance.log('HOME', 'JOIN_ROOM_ATTEMPT raw=$raw code=$code');
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = await ref.read(currentUserProvider.future);
      if (user == null) return;

      final found = await ref.read(roomServiceProvider).findRoomByCode(code);
      if (found == null) {
        QaLoggerService.instance.log('HOME', 'JOIN_ROOM_ERROR reason=not_found code=$code');
        setState(() => _error = 'לא נמצא חדר עם הקוד הזה');
        return;
      }
      if (found.phase == GamePhase.playing) {
        if (found.players.containsKey(user.id)) {
          final shortId = found.id.substring(0, found.id.length.clamp(0, 6));
          QaLoggerService.instance.log('HOME',
              'JOIN_ROOM_REJOIN_ACTIVE_ALLOWED code=$code roomId=$shortId uid=${user.id}');
          QaLoggerService.instance.log('GAME',
              'GAME_REJOIN_ACTIVE_ROOM roomId=$shortId phase=playing turnPhase=${found.turnPhase.name}');
          ref.read(currentRoomIdProvider.notifier).state = found.id;
          if (mounted) {
            Navigator.of(context).pop();
            context.go('/game/${found.id}');
          }
        } else {
          QaLoggerService.instance.log('HOME',
              'JOIN_ROOM_REJOIN_ACTIVE_DENIED_NOT_PLAYER code=$code uid=${user.id}');
          setState(() => _error = 'המשחק כבר התחיל');
        }
        return;
      }
      if (found.phase != GamePhase.waiting) {
        QaLoggerService.instance.log('HOME', 'JOIN_ROOM_ERROR reason=already_started code=$code');
        setState(() => _error = 'המשחק כבר התחיל');
        return;
      }
      if (found.players.length >= GameConstants.maxPlayers) {
        QaLoggerService.instance.log('HOME', 'JOIN_ROOM_ERROR reason=room_full code=$code');
        setState(() => _error = 'חדר מלא\nניתן להצטרף לעד ${GameConstants.maxPlayers} שחקנים');
        return;
      }

      final room = await ref.read(roomServiceProvider).joinRoom(
            code: code,
            userId: user.id,
            userName: user.name,
            userPhotoUrl: user.photoUrl,
          );

      if (room == null) {
        QaLoggerService.instance.log('HOME', 'JOIN_ROOM_ERROR reason=join_failed code=$code');
        setState(() => _error = 'לא ניתן להצטרף לחדר');
        return;
      }

      final shortId = room.id.substring(0, room.id.length.clamp(0, 6));
      QaLoggerService.instance.log('HOME', 'JOIN_ROOM_SUCCESS code=${room.code} id=$shortId');
      ref.read(currentRoomIdProvider.notifier).state = room.id;
      if (mounted) {
        Navigator.of(context).pop();
        context.go('/lobby/${room.id}');
      }
    } catch (e) {
      final msg = e.toString();
      QaLoggerService.instance.log('HOME', 'JOIN_ROOM_ERROR reason=exception msg=${msg.length > 50 ? msg.substring(0, 50) : msg}');
      setState(() => _error = 'שגיאה: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: const Color(0xFF07101F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'הצטרפות לחדר',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _controller,
                textAlign: TextAlign.center,
                textCapitalization: TextCapitalization.characters,
                maxLength: 6,
                autofocus: true,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 8,
                ),
                decoration: InputDecoration(
                  hintText: 'XXXXXX',
                  hintStyle: const TextStyle(color: Colors.white24, letterSpacing: 8),
                  counterText: '',
                  errorText: _error,
                  errorMaxLines: 2,
                  errorStyle: const TextStyle(fontSize: 13, height: 1.4),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white24),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF81C784), width: 1.5),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.redAccent),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
                  ),
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                ],
                onSubmitted: (_) => _join(),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white54,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      child: const Text('ביטול', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _join,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF81C784),
                        foregroundColor: const Color(0xFF07101F),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: Color(0xFF07101F)))
                          : const Text('הצטרף', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Home screen hero — peek grid ─────────────────────────────────────────────
//
// 3×3 dark tile grid over a real landmark image.
// Tiles at indices 1, 3, 7 are "open" (transparent → image shows through).
// Tile 5 breathes slowly, suggesting imminent reveal.
// No board code, no ApertureTile, no image slicing math.

class _HomeHeroPeekGrid extends StatefulWidget {
  final double size;
  const _HomeHeroPeekGrid({required this.size});

  @override
  State<_HomeHeroPeekGrid> createState() => _HomeHeroPeekGridState();
}

class _HomeHeroPeekGridState extends State<_HomeHeroPeekGrid>
    with TickerProviderStateMixin {
  late final AnimationController _breath;
  late final AnimationController _float;
  late final Animation<double> _floatAnim;

  // Tile indices where the image shows through
  static const Set<int> _open = {1, 3, 7};
  // Tile that breathes (opacity pulse), hinting imminent reveal
  static const int _breathIdx = 5;
  // Landmark image shown behind the grid
  static const String _image = 'assets/game_places/images/masada.jpg';

  @override
  void initState() {
    super.initState();
    _breath = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2700),
    )..repeat(reverse: true);

    _float = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat(reverse: true);
    _floatAnim = Tween<double>(begin: -5, end: 5).animate(
      CurvedAnimation(parent: _float, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _breath.dispose();
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    final r = s * 0.115;
    final gap = s * 0.030;

    return AnimatedBuilder(
      animation: _floatAnim,
      builder: (_, child) => Transform.translate(
        offset: Offset(0, _floatAnim.value),
        child: child,
      ),
      child: Container(
      width: s,
      height: s,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(r),
        border: Border.all(
          color: const Color(0xFFD4AF37).withOpacity(0.58),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD4AF37).withOpacity(0.20),
            blurRadius: 30,
            spreadRadius: 3,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.65),
            blurRadius: 20,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(r - 1.5),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Real landmark image — masada.jpg (local asset, 1024×1024)
            Image.asset(_image, fit: BoxFit.cover),
            // Dark gradient so closed tiles read clearly against bright areas
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.08),
                    Colors.black.withOpacity(0.48),
                  ],
                ),
              ),
            ),
            // Tile grid
            Padding(
              padding: EdgeInsets.all(gap),
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: gap,
                  mainAxisSpacing: gap,
                  childAspectRatio: 1.0,
                ),
                itemCount: 9,
                itemBuilder: (_, idx) => _buildCell(idx),
              ),
            ),
          ],
        ),
      ),
    ),   // end Container (child of AnimatedBuilder)
    );   // end AnimatedBuilder
  }

  Widget _buildCell(int idx) {
    if (_open.contains(idx)) {
      // Transparent — image shows through; thin cyan border marks the opening
      return DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: const Color(0xFF87CEEB).withOpacity(0.52),
            width: 1.0,
          ),
        ),
      );
    }

    final Widget tile = const _ClosedTile();

    if (idx == _breathIdx) {
      return AnimatedBuilder(
        animation: _breath,
        builder: (_, child) => Opacity(
          opacity: 0.52 + 0.48 * Curves.easeInOut.transform(_breath.value),
          child: child,
        ),
        child: tile,
      );
    }

    return tile;
  }
}

class _ClosedTile extends StatelessWidget {
  const _ClosedTile();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0E1C30), Color(0xFF040C18)],
        ),
        border: Border.all(
          color: const Color(0xFFD4AF37).withOpacity(0.42),
          width: 0.9,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.55),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
    );
  }
}
