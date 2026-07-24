import 'dart:io' show Platform;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:flutter_animate/flutter_animate.dart';

import '../../core/constants/ad_constants.dart';
import '../../core/constants/build_info.dart';
import '../../core/theme/candy_theme.dart';
import '../../core/constants/economy_config.dart';
import '../../core/constants/game_categories.dart';
import '../../core/constants/game_constants.dart';
import '../../core/theme/app_styles.dart';
import '../../providers/providers.dart';
import '../../services/app_update_service.dart';
import '../../widgets/common/banner_ad_widget.dart';
import '../../widgets/common/pressable.dart';
import '../../services/feedback_service.dart';
import '../../services/settings_service.dart';
import '../../services/rewards_config_service.dart';
import '../../services/qa_logger_service.dart';
import '../../widgets/common/pressable_scale.dart';
import '../../widgets/common/tilt_card.dart';
import '../../widgets/economy/coin_display.dart';
import '../../widgets/economy/coin_fly.dart';
import '../../widgets/economy/coin_icon.dart';
import '../../widgets/common/candy_particles.dart';
import '../../widgets/economy/daily_spin_sheet.dart';
import '../../widgets/economy/rewards_hub_sheet.dart';
import '../../models/room_model.dart';

enum _GameKind { places, heat, letters, proverbs }

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
  bool _loadingLetters = false;
  DateTime? _lastBackPressedAt;
  // Test branch: difficulty chosen for the next quick game (picker below).
  Difficulty _quickDifficulty = Difficulty.easy;
  // True when the pending quick game is 'זהו את הפתגם' (fixed proverbs heat).
  bool _quickProverbs = false;

  @override
  void initState() {
    super.initState();
    _doIntro = !HomeScreen._introPlayed;
    HomeScreen._introPlayed = true;
    QaLoggerService.instance.log('HOME', 'HOME_SCREEN_OPENED');
    // Instantiate the ad service early so rewarded + interstitial ads are
    // preloaded and ready before the player taps (avoids a failed first tap).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(adServiceProvider);
      // Cold start via a friend-invite link: jump to the friends screen, which
      // auto-sends the request. (Warm start is handled by the deep-link router.)
      if (mounted && ref.read(pendingFriendCodeProvider) != null) {
        context.push('/friends');
      }
      _maybeShowUpdateNotice();
    });
  }

  // Shows the in-app update notice at most once per app session.
  static bool _updateChecked = false;

  /// Checks the remote update config and, if this build is older than the
  /// advertised one, shows a notice. A build below `minBuild` gets a blocking
  /// (forced) dialog; a build below `latestBuild` gets a dismissible one that
  /// won't nag again for the same version. Entirely fail-safe — any error or a
  /// missing/disabled config simply shows nothing.
  Future<void> _maybeShowUpdateNotice() async {
    if (_HomeScreenState._updateChecked) return;
    _HomeScreenState._updateChecked = true;

    final AppUpdateInfo? info =
        await ref.read(appUpdateServiceProvider).fetch();
    if (!mounted || info == null || !info.enabled) return;

    final forced = kBuildNumber < info.minBuild;
    final soft = kBuildNumber < info.latestBuild;
    if (!forced && !soft) return;

    if (!forced) {
      // Respect a previous "later" tap for this same version.
      final prefs = await SharedPreferences.getInstance();
      final dismissed = prefs.getInt('update_dismissed_build') ?? 0;
      if (dismissed >= info.latestBuild) return;
    }
    if (!mounted) return;

    final storeUrl = Platform.isIOS ? info.iosUrl : info.androidUrl;
    QaLoggerService.instance
        .log('UPDATE', 'NOTICE_SHOWN forced=$forced latest=${info.latestBuild}');

    await showDialog<void>(
      context: context,
      barrierDismissible: !forced,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: PopScope(
          canPop: !forced,
          child: AlertDialog(
            backgroundColor: const Color(0xFF0D1E30),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            title: Text(forced ? 'נדרש עדכון' : 'יש גרסה חדשה 🎉',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900)),
            content: Text(info.message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 15)),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              if (!forced)
                TextButton(
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setInt(
                        'update_dismissed_build', info.latestBuild);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('אחר כך',
                      style: TextStyle(color: Colors.white54, fontSize: 15)),
                ),
              FilledButton(
                onPressed: storeUrl.isEmpty
                    ? null
                    : () async {
                        final uri = Uri.tryParse(storeUrl);
                        if (uri != null) {
                          await launchUrl(uri,
                              mode: LaunchMode.externalApplication);
                        }
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: AppStyles.cyanGlow,
                  foregroundColor: const Color(0xFF07101F),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('עדכן עכשיו',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Quick-game sheet: choose the topic (places / חי-צומח-דומם) AND the number
  /// of players in one place, then launch. Replaces the old two-step popup.
  /// Unified "how do you want to play <game>?" sheet. Same layout for every
  /// game so the choice — random opponent vs friends — is always in the same
  /// place. Adapts the random section per game (player count for the image
  /// games, 1v1 for letters).
  void _showPlaySheet(_GameKind kind) {
    FeedbackService.click();
    final name = kind == _GameKind.places
        ? 'זיהוי מקומות'
        : kind == _GameKind.heat
            ? 'חי צומח דומם'
            : kind == _GameKind.proverbs
                ? 'זהו את הפתגם'
                : 'משחק האותיות';
    final desc = kind == _GameKind.letters
        ? 'נחשו את המילה הנסתרת מאחורי התמונה'
        : kind == _GameKind.proverbs
            ? 'התמונה רומזת על פתגם, מי יפענח ראשון?'
            : 'מי יזהה את התמונה ראשון';
    const fee = EconomyConfig.gameEntryFee;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          padding: EdgeInsets.fromLTRB(
              20, 12, 20, 16 + MediaQuery.paddingOf(ctx).bottom),
          decoration: const BoxDecoration(
            color: Color(0xFF0D1E30),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(desc,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 13)),
                const SizedBox(height: 18),
                _sheetLabel('🎲 שחקנים אקראיים'),
                const SizedBox(height: 8),
                if (kind == _GameKind.letters)
                  _FriendsSheetOption(
                    icon: Icons.casino_rounded,
                    iconColor: const Color(0xFF4A9EFF),
                    title: 'התחל משחק',
                    subtitle: '1 על 1 · נגד יריב אקראי',
                    onTap: () {
                      Navigator.pop(ctx);
                      _startLettersRandom();
                    },
                  )
                else
                  for (final n in const [2, 3, 4]) ...[
                    _FriendsSheetOption(
                      icon: Icons.groups_rounded,
                      iconColor: const Color(0xFF4A9EFF),
                      title: n == 2 ? '1 על 1' : '$n שחקנים',
                      subtitle: 'כניסה $fee · קופה ${fee * n} מטבעות',
                      onTap: () {
                        _quickDifficulty = kind == _GameKind.heat ||
                                kind == _GameKind.proverbs
                            ? Difficulty.giant
                            : Difficulty.easy;
                        _quickProverbs = kind == _GameKind.proverbs;
                        Navigator.pop(ctx);
                        _startQuickGame(n);
                      },
                    ),
                    if (n != 4) const SizedBox(height: 8),
                  ],
                const SizedBox(height: 18),
                _sheetLabel('👥 חברים'),
                const SizedBox(height: 8),
                _FriendsSheetOption(
                  icon: Icons.add_circle_outline_rounded,
                  iconColor: const Color(0xFF3DCCAA),
                  title: 'פתח חדר',
                  subtitle: 'חינם · שתפו קוד עם חבר',
                  onTap: () {
                    Navigator.pop(ctx);
                    if (kind == _GameKind.letters) {
                      _startLettersFriends();
                    } else if (kind == _GameKind.proverbs) {
                      _createPrivateRoom(
                          gameType: Difficulty.giant,
                          category: GameCategories.proverbs);
                    } else {
                      _createPrivateRoom(
                          gameType: kind == _GameKind.heat
                              ? Difficulty.giant
                              : Difficulty.easy);
                    }
                  },
                ),
                const SizedBox(height: 8),
                _FriendsSheetOption(
                  icon: Icons.key_rounded,
                  iconColor: const Color(0xFF81C784),
                  title: 'יש לי קוד',
                  subtitle: 'הצטרפו לחדר של חבר',
                  onTap: () {
                    Navigator.pop(ctx);
                    _showJoinDialog();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sheetLabel(String text) => Align(
        alignment: Alignment.centerRight,
        child: Text(text,
            style: const TextStyle(
                color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w800)),
      );

  /// Topic picker for the friends flow (places / חי-צומח-דומם). Returns the
  /// chosen content, or null if dismissed.
  Future<Difficulty?> _pickContent() {
    const options = [Difficulty.easy, Difficulty.giant];
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
              const Text('בחרו נושא',
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
                          Text(d == Difficulty.giant ? '⚡' : '📍',
                              style: const TextStyle(fontSize: 22)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                                d == Difficulty.giant
                                    ? 'חי צומח דומם'
                                    : 'זיהוי מקומות',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800)),
                          ),
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

    // Content type (places / חי-צומח-דומם) is chosen in the quick-game sheet and
    // stored in [_quickDifficulty] before this runs.

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

      RoomModel? existingRoom =
          await roomSvc.findMatchRoom(myExposure, proverbs: _quickProverbs);
      if (existingRoom == null) {
        await Future.delayed(const Duration(seconds: 2));
        if (!mounted) return;
        existingRoom =
            await roomSvc.findMatchRoom(myExposure, proverbs: _quickProverbs);
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
          category: _quickProverbs
              ? GameCategories.proverbs
              : GameCategories.israelPlaces,
          // Fast game: rounds = max(players, 3), so a 4-player quick game has 4
          // topics. Only matters for the giant (חי-צומח-דומם) heat.
          heatRounds: targetPlayers,
          // Proverbs quick-match: a single round is enough (per Rotem) — the
          // friends game is where multiple rounds make sense, since there the
          // host picks a round count.
          heatTopics: _quickProverbs
              ? List.filled(1, GameCategories.proverbs)
              : null,
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
        });
      }
    }
  }

  /// Letters game vs a RANDOM player: join a waiting opponent if one exists,
  /// otherwise open a public room (a bot fills in if nobody joins shortly).
  Future<void> _startLettersRandom() async {
    if (_isCreating || _loadingLetters) return;
    QaLoggerService.instance.log('HOME', 'TAP_LETTERS_RANDOM');
    FeedbackService.click();
    setState(() => _loadingLetters = true);
    try {
      final user = await ref.read(currentUserProvider.future);
      if (user == null) return;
      final svc = ref.read(roomServiceProvider);
      final match = await svc.findLettersMatch(user.id);
      String roomId;
      if (match != null) {
        await svc.joinRoom(
          code: match.code,
          userId: user.id,
          userName: user.name,
          userPhotoUrl: user.photoUrl,
        );
        roomId = match.id;
      } else {
        final room = await svc.createLettersRoom(
          hostId: user.id,
          hostName: user.name,
          hostPhotoUrl: user.photoUrl,
          solo: false,
          isPublicRoom: true,
        );
        roomId = room.id;
      }
      ref.read(currentRoomIdProvider.notifier).state = roomId;
      if (mounted) context.go('/letters/$roomId');
    } catch (e) {
      final msg = e.toString();
      QaLoggerService.instance.log('HOME', 'LETTERS_RANDOM_ERROR ${msg.length > 60 ? msg.substring(0, 60) : msg}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('יצירת המשחק נכשלה: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingLetters = false);
    }
  }

  /// Letters game with a FRIEND: open a private room and show its code; the
  /// friend joins via "יש לי קוד" and the game starts when they arrive.
  Future<void> _startLettersFriends() async {
    if (_isCreating || _loadingLetters) return;
    QaLoggerService.instance.log('HOME', 'TAP_LETTERS_FRIENDS');
    FeedbackService.click();
    setState(() => _loadingLetters = true);
    try {
      final user = await ref.read(currentUserProvider.future);
      if (user == null) return;
      final room = await ref.read(roomServiceProvider).createLettersRoom(
            hostId: user.id,
            hostName: user.name,
            hostPhotoUrl: user.photoUrl,
            solo: false,
            isPublicRoom: false,
          );
      ref.read(currentRoomIdProvider.notifier).state = room.id;
      if (mounted) context.go('/letters/${room.id}');
    } catch (e) {
      final msg = e.toString();
      QaLoggerService.instance.log('HOME', 'LETTERS_FRIENDS_ERROR ${msg.length > 60 ? msg.substring(0, 60) : msg}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('יצירת המשחק נכשלה: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingLetters = false);
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

  Future<void> _createPrivateRoom(
      {Difficulty? gameType, String? category}) async {
    if (_isCreating) return;
    QaLoggerService.instance.log('HOME', 'TAP_CREATE_ROOM');
    FeedbackService.click();

    // Pick the game type once (זיהוי מקומות / חי צומח דומם).
    // Friends games are FREE — no entry fee, no coin check.
    final difficulty = gameType ?? await _pickContent();
    if (difficulty == null) return; // dismissed

    setState(() {
      _isCreating = true;
    });

    try {
      final user = await ref.read(currentUserProvider.future);
      if (user == null) return;

      QaLoggerService.instance.log('HOME', 'CREATE_ROOM_ATTEMPT playerCount=default');
      final room = await ref.read(roomServiceProvider).createRoom(
            hostId: user.id,
            hostName: user.name,
            hostPhotoUrl: user.photoUrl,
            entryFee: 0,
            difficulty: difficulty,
            category: category ?? GameCategories.israelPlaces,
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
                  const SnackBar(content: Text('לא ניתן כרגע, נסה דרך אחרת')),
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
                  if (AdConstants.adsEnabled && adsAvailable)
                    optBtn('📺 צפה בפרסומת (+${EconomyConfig.adRewardCoins})', const [Color(0xFF20A8E0), Color(0xFF0868A8)],
                        () => run(() async {
                          final watched =
                              await ref.read(adServiceProvider).showRewarded(placement: 'home_coins');
                          if (!watched) return false;
                          return economy.applyAdReward(uid!);
                        }, proceed: true)),

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
    // Rebuild live when the admin changes content (active topics / labels).
    ref.watch(contentManifestRevisionProvider);
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
          backgroundColor: Candy.bgVariantBottom(ref.watch(bgVariantProvider)),
          body: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                      gradient: Candy.bgVariant(ref.watch(bgVariantProvider))),
                ),
              ),
              const Positioned.fill(child: CandyParticles()),
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
                          // Row 1: nav icons (left) + daily reward (right).
                          _step(
                            Row(
                              textDirection: TextDirection.ltr,
                              children: const [
                                _ProfileIconButton(),
                                SizedBox(width: 8),
                                _StoreIconButton(),
                                SizedBox(width: 8),
                                _FriendsIconButton(),
                                Spacer(),
                                _DailySpinButton(),
                                SizedBox(width: 8),
                                _DailyRewardButton(),
                              ],
                            ),
                            delayMs: 0, durationMs: 380, dy: -10,
                          ),
                          // Tip of the day — bubble just under the top row.
                          const SizedBox(height: 8),
                          _step(const _TipOfDayCard(),
                              delayMs: 60, durationMs: 340, dy: -6),
                          // Row 2: coins on its own line — keeps the top bar from
                          // overflowing (which had hidden the daily-reward button)
                          // and the wide coins capsule from overlapping the icons.
                          const SizedBox(height: 8),
                          _step(
                            Center(child: CoinDisplay(key: walletAnchorKey)),
                            delayMs: 40, durationMs: 380, dy: -10,
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
                                    Shadow(color: Candy.pink, blurRadius: 18),
                                    Shadow(color: Colors.black45, offset: Offset(0, 4), blurRadius: 8),
                                    Shadow(color: Color(0x66FFD84D), blurRadius: 44, offset: Offset(0, 8)),
                                  ],
                                ),
                              ),
                            )
                                // A light sweep glints across the title every
                                // few seconds so the hero feels alive.
                                .animate(onPlay: (c) => c.repeat())
                                .shimmer(
                                    delay: 2800.ms,
                                    duration: 1500.ms,
                                    color: Colors.white.withOpacity(0.55)),
                            delayMs: 200, durationMs: 380, dy: 8,
                          ),
                          const SizedBox(height: 6),
                          _step(
                            Text(
                              'בחרו סוג משחק',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Candy.gold,
                                fontSize: verySmall ? 15 : compact ? 17 : 19,
                                fontWeight: FontWeight.w800,
                                height: 1.2,
                              ),
                            ),
                            delayMs: 300, durationMs: 320,
                          ),
                          const _WinStreakBanner(),
                          const _HappyHourHomeBanner(),
                          SizedBox(height: verySmall ? 10 : compact ? 14 : 20),
                          _step(
                            Column(
                              children: [
                                _GameTypeCard(
                                  icon: '🏞️',
                                  title: 'זיהוי מקומות',
                                  subtitle: 'מצאו את המקום בתמונה',
                                  gradientColors: const [Candy.blue],
                                  glowColor: Candy.blue,
                                  isLoading: _isCreating,
                                  onTap: _isCreating
                                      ? null
                                      : () => _showPlaySheet(_GameKind.places),
                                ),
                                SizedBox(height: verySmall ? 8 : 10),
                                _GameTypeCard(
                                  icon: '🐢',
                                  title: 'חי צומח דומם',
                                  subtitle: 'חיות · צמחים · חפצים ועוד',
                                  gradientColors: const [Candy.teal],
                                  glowColor: Candy.teal,
                                  isLoading: _isCreating,
                                  onTap: _isCreating
                                      ? null
                                      : () => _showPlaySheet(_GameKind.heat),
                                ),
                                SizedBox(height: verySmall ? 8 : 10),
                                _GameTypeCard(
                                  icon: '🧩',
                                  title: 'זהו את הפתגם',
                                  subtitle: 'התמונה רומזת על פתגם עברי',
                                  gradientColors: const [Candy.tangerine],
                                  glowColor: Candy.tangerine,
                                  isLoading: _isCreating,
                                  onTap: _isCreating
                                      ? null
                                      : () => _showPlaySheet(_GameKind.proverbs),
                                ),
                                SizedBox(height: verySmall ? 8 : 10),
                                _GameTypeCard(
                                  icon: '🔤',
                                  title: 'משחק האותיות',
                                  subtitle: 'נחשו את המילה הנסתרת',
                                  gradientColors: const [Candy.pink],
                                  glowColor: Candy.pink,
                                  isLoading: _loadingLetters,
                                  onTap: (_isCreating || _loadingLetters)
                                      ? null
                                      : () => _showPlaySheet(_GameKind.letters),
                                ),
                              ],
                            ),
                            delayMs: 460, durationMs: 260, dy: 5,
                          ),
                          SizedBox(height: verySmall ? 6 : 10),
                          _RecentGamesStrip(onReplay: _showPlaySheet),
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

// ── Recent games quick-replay strip ───────────────────────────────────────

class _RecentGamesStrip extends StatelessWidget {
  final void Function(_GameKind) onReplay;
  const _RecentGamesStrip({required this.onReplay});

  static const Map<String, ({_GameKind kind, String emoji, String label})> _map = {
    'places': (kind: _GameKind.places, emoji: '🏞️', label: 'זיהוי מקומות'),
    'heat': (kind: _GameKind.heat, emoji: '🐢', label: 'חי צומח דומם'),
    'proverbs': (kind: _GameKind.proverbs, emoji: '🧩', label: 'זהו את הפתגם'),
    'letters': (kind: _GameKind.letters, emoji: '🔤', label: 'משחק האותיות'),
  };

  @override
  Widget build(BuildContext context) {
    final recent = SettingsService.instance.recentGames
        .where((g) => _map.containsKey(g.kind))
        .toList();
    if (recent.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 4, bottom: 6),
            child: Text(
              'המשך לשחק',
              style: TextStyle(
                color: Colors.white.withOpacity(0.85),
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: recent.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final g = recent[i];
                final m = _map[g.kind]!;
                return Pressable(
                  onTap: () => onReplay(m.kind),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: Candy.jellyFill(Candy.surface),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: (g.won ? Candy.gold : Colors.white)
                            .withOpacity(0.22),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(m.emoji, style: const TextStyle(fontSize: 18)),
                        const SizedBox(width: 6),
                        Text(
                          m.label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(g.won ? '🏆' : '↻',
                            style: TextStyle(
                                fontSize: 13,
                                color: g.won
                                    ? Candy.gold
                                    : Colors.white.withOpacity(0.5))),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Happy Hour banner (admin-scheduled coin multiplier) ───────────────────

class _HappyHourHomeBanner extends ConsumerWidget {
  const _HappyHourHomeBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(rewardsRevisionProvider);
    if (!RewardsConfigService.instance.happyHourActive) {
      return const SizedBox.shrink();
    }
    final mult = RewardsConfigService.instance.happyHourMultiplier;
    final label = RewardsConfigService.instance.happyHourLabel;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFFFF7A1A), Color(0xFFFFB03A)]),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFFFF7A1A).withOpacity(0.45),
                blurRadius: 16,
                spreadRadius: 1),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('⚡', style: TextStyle(fontSize: 17))
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scaleXY(begin: 0.9, end: 1.15, duration: 600.ms),
            const SizedBox(width: 8),
            Flexible(
              child: Text('$label כל המטבעות ×$mult',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 260.ms);
  }
}

// ── Win streak banner ─────────────────────────────────────────────────────

class _WinStreakBanner extends ConsumerWidget {
  const _WinStreakBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streak = ref.watch(walletProvider).valueOrNull?.winStreak ?? 0;
    if (streak < 2) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF7A1A), Color(0xFFFFB03A)],
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF7A1A).withOpacity(0.45),
              blurRadius: 16,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🔥', style: TextStyle(fontSize: 18))
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scaleXY(begin: 0.9, end: 1.15, duration: 620.ms),
            const SizedBox(width: 8),
            Text(
              '$streak ניצחונות ברצף!',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 260.ms).scaleXY(begin: 0.85, end: 1.0);
  }
}

// ── Tip of the day ────────────────────────────────────────────────────────

class _TipOfDayCard extends StatelessWidget {
  const _TipOfDayCard();

  static const List<String> _tips = [
    'נחשו מוקדם ככל האפשר, ככה תרוויחו יותר מטבעות.',
    'רצף כניסה יומי מגדיל את הבונוס במטבעות בכל יום.',
    'שחקו עם חברים בחדר פרטי, בלי תשלום כניסה.',
    'אספו מטבעות ופתחו רקעים חדשים ללוח בחנות.',
    'כרטיס החשכה מסתיר את הלוח מהיריב לכמה שניות.',
    'כרטיס עצור עוצר את היריב לתור שלם.',
    'גלו עוד מקומות כדי לפתוח כרטיסי פעולה חדשים.',
    'בחי צומח דומם אפשר להצביע להחליף פריט כשאף אחד לא יודע.',
    'סובבו את גלגל המזל פעם ביום לסיבוב חינם.',
    'השלימו את המשימה היומית ואספו פרס נוסף.',
  ];

  @override
  Widget build(BuildContext context) {
    // Rotate by day so the tip is stable within a day and changes daily.
    final dayIndex =
        DateTime.now().difference(DateTime(2026, 1, 1)).inDays.abs();
    final tip = _tips[dayIndex % _tips.length];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Candy.grape.withOpacity(0.35),
            Candy.bgMid.withOpacity(0.55),
          ],
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Candy.gold.withOpacity(0.28), width: 1),
      ),
      child: Row(
        children: [
          const Text('💡', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'טיפ היום',
                  style: TextStyle(
                    color: Candy.gold,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  tip,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Equal quick-game button for 2/3/4 players ─────────────────────────────

class _GameTypeCard extends StatelessWidget {
  final String icon;
  final String title;
  final String subtitle;
  final List<Color> gradientColors;
  final Color glowColor;
  final bool isLoading;
  final VoidCallback? onTap;

  const _GameTypeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradientColors,
    required this.glowColor,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TiltCard(
      onTap: onTap == null
          ? null
          : () {
              HapticFeedback.mediumImpact();
              onTap!();
            },
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 160),
        opacity: onTap == null ? 0.55 : 1,
        child: Container(
          height: 74,
          decoration: BoxDecoration(
            gradient: Candy.jellyFill(gradientColors.first),
            borderRadius: BorderRadius.circular(22),
            border: Candy.rim(),
            boxShadow: Candy.jellyShadow(gradientColors.first),
          ),
          child: isLoading
              ? const Center(
                  child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.4)))
              : Row(
                  children: [
                    const SizedBox(width: 14),
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Candy.bevel(glowColor).withOpacity(0.55),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.55), width: 1.5),
                      ),
                      child: Text(icon, style: const TextStyle(fontSize: 24)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Shrink-to-fit (instead of truncating with "…") so the
                          // full caption shows even at large device text scales.
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: AlignmentDirectional.centerStart,
                            child: Text(
                              title,
                              maxLines: 1,
                              softWrap: false,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  height: 1.1),
                            ),
                          ),
                          const SizedBox(height: 3),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: AlignmentDirectional.centerStart,
                            child: Text(
                              subtitle,
                              maxLines: 1,
                              softWrap: false,
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.62),
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  height: 1),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.chevron_left_rounded,
                        color: Colors.white.withOpacity(0.92), size: 26),
                    const SizedBox(width: 10),
                  ],
                ),
        ),
      ),
    );
  }
}

// ── Topic chip for the quick-game sheet ─────────────────────────────────────

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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: iconColor, fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w500)),
                ],
              ),
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
        // Opens the unified rewards hub (spin + daily reward + quests).
        showRewardsHub(context, ref);
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

// ── Daily spin-wheel button (top bar) ─────────────────────────────────────

class _DailySpinButton extends ConsumerWidget {
  const _DailySpinButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(walletProvider).valueOrNull;
    final isAvailable = isDailySpinAvailable(wallet?.lastDailySpinAt);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        // Always open the wheel; the sheet shows a "come back tomorrow" state
        // when today's free spin was already used.
        showDailySpinSheet(context, ref);
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
                      ? Candy.teal.withOpacity(0.80)
                      : Colors.white.withOpacity(0.15),
                  width: isAvailable ? 1.5 : 1.0,
                ),
              ),
              child: const Center(
                child: Icon(Icons.casino_rounded, color: Candy.teal, size: 20),
              ),
            ),
            if (isAvailable)
              Positioned(
                top: -5,
                right: -5,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Candy.teal,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppStyles.navyTop, width: 1.5),
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

// ── Friends icon button (top bar) — shows a dot when requests are pending ──

class _FriendsIconButton extends ConsumerWidget {
  const _FriendsIconButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasRequests =
        ref.watch(friendRequestsProvider).valueOrNull?.isNotEmpty ?? false;
    final hasInvites =
        ref.watch(gameInvitesProvider).valueOrNull?.isNotEmpty ?? false;
    final pending = hasRequests || hasInvites;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          HapticFeedback.lightImpact();
          QaLoggerService.instance.log('HOME', 'TAP_FRIENDS');
          context.push('/friends');
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
                    border: Border.all(
                      color: Colors.white.withOpacity(0.15),
                      width: 1.0,
                    ),
                  ),
                  child: const Icon(
                    Icons.group_rounded,
                    color: Colors.white70,
                    size: 20,
                  ),
                ),
                if (pending)
                  Positioned(
                    right: -1,
                    top: -1,
                    child: Container(
                      width: 11,
                      height: 11,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF5252),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: const Color(0xFF050A14), width: 1.5),
                      ),
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
            context.go(found.isLetters ? '/letters/${found.id}' : '/game/${found.id}');
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
        context.go(room.isLetters ? '/letters/${room.id}' : '/lobby/${room.id}');
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
