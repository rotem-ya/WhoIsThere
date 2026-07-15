import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/utils/share_util.dart';

import '../../core/constants/ad_constants.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/economy_config.dart';
import '../../core/constants/game_constants.dart';
// player_rank removed — using discoveredCount badge instead;
import '../../core/theme/app_styles.dart';
import '../../providers/providers.dart';
import '../../models/player_model.dart';
import '../../models/room_model.dart';
import '../../models/friend_models.dart';
import '../../core/constants/game_categories.dart';
import '../../core/utils/chat_filter.dart';
import '../../widgets/chat/chat_sheet.dart';
import '../friends/widgets/groups_tab.dart';
import '../../services/analytics_service.dart';
import '../../services/qa_logger_service.dart';
import '../../services/settings_service.dart';
import '../../services/content_manifest_service.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../widgets/common/app_feedback.dart';
import '../../widgets/common/player_avatar.dart';
import '../../widgets/common/player_name_text.dart';
import '../../widgets/common/pressable_scale.dart';
import '../../widgets/common/banner_ad_widget.dart';
import '../../widgets/economy/coin_icon.dart';

class LobbyScreen extends ConsumerStatefulWidget {
  final String roomId;
  const LobbyScreen({super.key, required this.roomId});

  @override
  ConsumerState<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends ConsumerState<LobbyScreen> {
  bool _isStarting = false;
  bool _codeCopied = false;
  bool _lobbyLogged = false;
  bool _autoInvitePrompted = false;
  int _lastPlayerCount = 0;
  static final AudioPlayer _joinPlayer = AudioPlayer(playerId: 'player-join');
  static final AssetSource _joinSound = AssetSource('sounds/player_join.wav');

  @override
  void initState() {
    super.initState();
    QaLoggerService.instance.log('LOBBY', 'LOBBY_SCREEN_OPENED roomId=${widget.roomId.substring(0, widget.roomId.length.clamp(0, 6))}');
  }

  Future<void> _copyCode(String code) async {
    if (_codeCopied) return;
    QaLoggerService.instance.log('LOBBY', 'COPY_ROOM_CODE_TAPPED code=$code');
    AppFeedback.success();
    await Clipboard.setData(ClipboardData(text: code));
    setState(() => _codeCopied = true);
    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted) setState(() => _codeCopied = false);
  }

  // Opt-in rewarded ad in the lobby: only ever runs when the player taps this
  // button — never automatic. Grants the daily-capped coin reward.
  Future<void> _watchAdForCoins() async {
    final uid = ref.read(firebaseUserProvider).valueOrNull?.uid;
    if (uid == null) return;
    final watched = await ref.read(adServiceProvider).showRewarded(placement: 'lobby_coins');
    if (!mounted) return;
    if (!watched) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('הפרסומת לא זמינה כרגע, נסה שוב בעוד רגע')),
      );
      return;
    }
    final granted = await ref.read(economyServiceProvider).applyAdReward(uid);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(granted
            ? '+${EconomyConfig.adRewardCoins} מטבעות הופקדו!'
            : 'המכסה היומית הושלמה'),
        backgroundColor: const Color(0xFF0A3880),
      ),
    );
  }

  /// "Watch a video for coins" lobby button. Hidden when ads are off or the
  /// player has used today's rewarded-ad quota.
  Widget _buildLobbyAdButton() {
    if (!AdConstants.adsEnabled) return const SizedBox.shrink();
    final wallet = ref.watch(walletProvider).valueOrNull;
    final adsToday = wallet?.adRewardsTodayCount ?? 0;
    final remaining = (EconomyConfig.maxAdRewardsPerDay - adsToday)
        .clamp(0, EconomyConfig.maxAdRewardsPerDay);
    if (remaining <= 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: PressableScale(
        onTap: _watchAdForCoins,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF20A8E0), Color(0xFF0868A8)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: Text.rich(
              TextSpan(
                text: '🎬 צפה בסרטון וקבל ${EconomyConfig.adRewardCoins} ',
                children: [coinSpan(size: 15)],
              ),
              textDirection: TextDirection.rtl,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openChat() {
    final user = ref.read(currentUserProvider).value;
    QaLoggerService.instance.log('LOBBY', 'LOBBY_CHAT_OPENED');
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChatSheet(
        stream: ref.read(roomServiceProvider).chatMessagesStream(widget.roomId),
        myUid: user?.id ?? '',
        onSend: (text) {
          final uid = user?.id;
          if (uid == null) return;
          final clean = ChatFilter.clean(text);
          if (clean.isEmpty) return;
          ref.read(roomServiceProvider).sendChatMessage(
              widget.roomId, uid, user?.name ?? 'אני', clean);
        },
      ),
    );
  }

  // ── Heat topic picker (חי צומח דומם friends game) ──────────────────────────

  /// Rounds for the heat = max(players, 3).
  /// Minimum topics a participant must pick to be "ready": exactly one — for
  /// everyone. The host may pick MORE (see [_topicChip]) to add heat rounds;
  /// the extra picks are optional, so the required count stays 1.
  /// EXCEPT when the picks already cover every heat round (e.g. the host
  /// selected topics for the whole group) — then nobody else is required to
  /// pick and the quota drops to 0.
  int _topicQuota(RoomModel room, String playerId) =>
      _picksCoverHeat(room) ? 0 : 1;

  /// Whether the topics picked so far already fill every heat round. Counts
  /// picks the same way [_buildFriendsHeat] consumes them — the host keeps all
  /// of theirs, every other player contributes at most one — against the
  /// round floor of max(players, 3).
  bool _picksCoverHeat(RoomModel room) {
    var total = 0;
    room.topicChoices.forEach((pid, picks) {
      total += pid == room.hostId ? picks.length : min(picks.length, 1);
    });
    return total >= max(room.players.length, 3);
  }

  Widget _buildHeatSetup(RoomModel room, dynamic currentUser) {
    final myId = currentUser?.id as String?;
    final isHost = myId != null && myId == room.hostId;
    // A topic chosen by ANY participant shows as selected to everyone. The
    // first chooser owns the slot (the picker never double-books a topic).
    final chosenBy = <String, String>{};
    for (final entry in room.topicChoices.entries) {
      for (final cat in entry.value) {
        chosenBy.putIfAbsent(cat, () => entry.key);
      }
    }
    // Non-host picks exactly one; the host may pick several to lengthen the heat.
    // When the picks already cover every round, the others' pick is optional.
    final covered = _picksCoverHeat(room);
    final title = isHost
        ? 'בחרו נושא, אפשר כמה שתרצו'
        : (covered
            ? 'הנושאים למקצה כבר נבחרו, אפשר להוסיף עוד'
            : 'בחרו נושא למקצה');
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: AppStyles.glassCard(radius: 16, opacity: 0.12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14)),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              // Topics the admin hid via the manifest `topicsActive` map are
              // dropped from the picker (absent = active, backward compatible).
              for (final catId in GameCategories.fastHeat)
                if (ContentManifestService.instance.isCategoryActive(catId))
                  _topicChip(catId,
                      selected: chosenBy.containsKey(catId),
                      ownerName: room.players[chosenBy[catId]]?.name),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final p in room.players.values)
                _pickStatusChip(p, room.topicChoices[p.id] ?? const [],
                    _topicQuota(room, p.id)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _topicChip(String catId,
      {required bool selected, String? ownerName}) {
    final cat = GameCategories.byId(catId);
    // Admin display-name override from the content manifest, else built-in name.
    final label = ContentManifestService.instance.topicLabel(catId) ?? cat.nameHe;
    final owner = (ownerName != null && ownerName.trim().isNotEmpty)
        ? ownerName.trim().split(' ').first
        : null;
    return GestureDetector(
      onTap: () => _onTopicTap(catId),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppStyles.cyanGlow.withOpacity(0.22)
              : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? AppStyles.cyanGlow
                : Colors.white.withOpacity(0.15),
            width: selected ? 1.6 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(cat.emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: selected ? AppStyles.cyanGlow : Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
            if (selected && owner != null) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: AppStyles.cyanGlow.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(owner,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Tap handler for a topic chip. A chosen topic is visible to everyone and
  /// can only be cancelled by the host (with a confirmation). Participants pick
  /// exactly one and can't swap it themselves afterwards; the host may pick
  /// several (each adds a heat round) and can cancel anyone's pick.
  void _onTopicTap(String catId) {
    final myId = ref.read(currentUserProvider).value?.id;
    if (myId == null) return;
    final room = ref.read(roomStreamProvider(widget.roomId)).valueOrNull;
    if (room == null) return;
    final isHost = myId == room.hostId;
    final svc = ref.read(roomServiceProvider);

    // Find the current owner of this topic (first chooser), if any.
    String? ownerId;
    for (final e in room.topicChoices.entries) {
      if (e.value.contains(catId)) {
        ownerId = e.key;
        break;
      }
    }

    // ── Topic already chosen ────────────────────────────────────────────────
    if (ownerId != null) {
      if (!isHost) {
        // Participants can't cancel — neither their own pick nor anyone else's.
        _showOnlyHostCanCancel(alreadyPicked: ownerId == myId);
        return;
      }
      if (ownerId == myId) {
        // Host drops one of their own extra picks freely (no confirmation).
        HapticFeedback.selectionClick();
        final list = [...?room.topicChoices[myId]]..remove(catId);
        svc.setTopicChoices(widget.roomId, myId, list);
      } else {
        // Host cancels a participant's pick — confirm first.
        _confirmCancelChoice(room.players[ownerId], catId, ownerId);
      }
      return;
    }

    // ── Topic is free ───────────────────────────────────────────────────────
    if (isHost) {
      HapticFeedback.selectionClick();
      final list = [...?room.topicChoices[myId], catId];
      svc.setTopicChoices(widget.roomId, myId, list);
      return;
    }
    // Non-host picks exactly one; once picked they can't change it themselves.
    final mine = room.topicChoices[myId] ?? const <String>[];
    if (mine.isNotEmpty) {
      _showOnlyHostCanCancel(alreadyPicked: true);
      return;
    }
    HapticFeedback.selectionClick();
    svc.setTopicChoices(widget.roomId, myId, [catId]);
  }

  void _showOnlyHostCanCancel({bool alreadyPicked = false}) {
    HapticFeedback.lightImpact();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      duration: const Duration(seconds: 2),
      content: Text(alreadyPicked
          ? 'כבר בחרת נושא, רק המארח יכול לבטל את הבחירה'
          : 'רק המארח יכול לבטל בחירת נושא'),
    ));
  }

  Future<void> _confirmCancelChoice(
      PlayerModel? owner, String catId, String ownerId) async {
    final cat = GameCategories.byId(catId);
    final name = (owner?.name.isNotEmpty ?? false) ? owner!.name : 'השחקן';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF0D1E30),
          title: const Text('לבטל בחירת נושא?',
              style: TextStyle(color: Colors.white, fontSize: 17)),
          content: Text('לבטל את "${cat.nameHe}" שבחר $name?',
              style: const TextStyle(color: Colors.white70, fontSize: 14)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child:
                  const Text('השאר', style: TextStyle(color: Colors.white54)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('בטל בחירה',
                  style: TextStyle(
                      color: Color(0xFFFF6B6B), fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
    if (ok == true) {
      HapticFeedback.mediumImpact();
      final room = ref.read(roomStreamProvider(widget.roomId)).valueOrNull;
      final list = [...?room?.topicChoices[ownerId]]..remove(catId);
      await ref
          .read(roomServiceProvider)
          .setTopicChoices(widget.roomId, ownerId, list);
    }
  }

  Widget _pickStatusChip(PlayerModel p, List<String> choices, int quota) {
    final name = p.name.isNotEmpty ? p.name : 'שחקן';
    final complete = choices.length >= quota;
    final emojis =
        choices.map((c) => GameCategories.byId(c).emoji).join(' ');
    final label = choices.isNotEmpty
        ? '$name $emojis${complete ? '' : ' …'}'
        : (p.isBot ? '$name 🎲' : (complete ? name : '$name …'));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: complete
            ? Colors.greenAccent.withOpacity(0.12)
            : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: complete
              ? Colors.greenAccent.withOpacity(0.4)
              : Colors.white.withOpacity(0.12),
          width: 0.8,
        ),
      ),
      child: Text(label,
          style: TextStyle(
              color: complete ? Colors.greenAccent : Colors.white54,
              fontSize: 11,
              fontWeight: FontWeight.w600)),
    );
  }

  Future<bool?> _confirmStartWithUnchosen(List<PlayerModel> unchosen) {
    final names = unchosen
        .map((p) => p.name.isNotEmpty ? p.name : 'שחקן')
        .join(', ');
    return showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF0D1E30),
          title: const Text('לא כולם בחרו נושא',
              style: TextStyle(color: Colors.white, fontSize: 17)),
          content: Text(
            'השחקנים הבאים עדיין לא בחרו נושא:\n$names\n\nאפשר להשלים את הסבבים מהנושאים שכבר נבחרו ולהתחיל, או להמתין שיבחרו.',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('המתן',
                  style: TextStyle(color: Colors.white54)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('השלם והתחל',
                  style: TextStyle(
                      color: Color(0xFF22D3EE), fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }

  void _shareToWhatsApp(String code) {
    HapticFeedback.lightImpact();
    QaLoggerService.instance.log('LOBBY', 'SHARE_ROOM_TAPPED code=$code');
    final msg = StringBuffer();
    msg.writeln('בואו לגלות מה בתמונה 📸');
    msg.writeln();
    msg.writeln('קוד חדר: $code');
    msg.writeln();
    msg.writeln('🎮 הצטרפות ישירה לחדר:');
    msg.write(AppConstants.joinUrlForCode(code));
    AnalyticsService.instance.inviteSent(kind: 'room');
    shareText(context, msg.toString());
  }

  /// Opens the "invite a friend" picker (friends list + search) for this room.
  void _openInviteFriends(RoomModel room) {
    HapticFeedback.lightImpact();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _InviteFriendsSheet(
        roomId: room.id,
        code: room.code,
        existingPlayerIds: room.players.keys.toSet(),
        onShareCode: () => _shareToWhatsApp(room.code),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final roomAsync = ref.watch(roomStreamProvider(widget.roomId));
    final currentUser = ref.watch(currentUserProvider).value;
    // Rebuild the topic picker live when the admin hides a topic / edits labels.
    ref.watch(contentManifestRevisionProvider);

    ref.listen(roomStreamProvider(widget.roomId), (prev, next) {
      final prevCount = prev?.valueOrNull?.players.length ?? 0;
      final nextCount = next.valueOrNull?.players.length ?? 0;
      if (nextCount > prevCount && nextCount > _lastPlayerCount) {
        _lastPlayerCount = nextCount;
        final sfxScale = SettingsService.instance.sfxVolume;
        _joinPlayer.stop().then((_) async {
          await _joinPlayer.setVolume(sfxScale);
          await _joinPlayer.play(_joinSound);
        }).ignore();
      }
    });

    return roomAsync.when(
      data: (room) {
        if (room == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/home'));
          return const SizedBox();
        }

        if (!_lobbyLogged) {
          _lobbyLogged = true;
          QaLoggerService.instance.log(
              'LOBBY', 'LOBBY_ROOM_DATA code=${room.code} players=${room.players.length}');
        }

        if (room.phase == GamePhase.playing) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) context.go('/game/${room.id}');
          });
          return const SizedBox.shrink();
        }

        final isHost = currentUser?.id == room.hostId;
        // נגישות מקסימלית להזמנת חברים: חדר חברים שנפתח ריק קופץ למארח
        // מרכז ההזמנות אוטומטית (פעם אחת), במקום לחכות שיגלה את הכפתור.
        if (isHost &&
            room.isFriendsGame &&
            room.players.length <= 1 &&
            !_autoInvitePrompted) {
          _autoInvitePrompted = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _openInviteFriends(room);
          });
        }
        // Prefer the live currentUser name so the greeting is always up to date.
        final rawHostName = isHost
            ? (currentUser?.name ?? room.players[room.hostId]?.name ?? '')
            : (room.players[room.hostId]?.name ?? '');
        final hostName = rawHostName.isEmpty ? 'המארח' : rawHostName;
        final canStart = room.players.length >= GameConstants.minPlayers;

        return PopScope(
          canPop: false,
          onPopInvoked: (didPop) async {
            if (didPop) return;
            // Mirror the on-screen exit button: leave the room so the player
            // isn't left behind as a ghost in the room document.
            if (currentUser != null) {
              await ref
                  .read(roomServiceProvider)
                  .leaveRoom(widget.roomId, currentUser.id);
            }
            if (context.mounted) context.go('/home');
          },
          child: Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: AppStyles.backgroundGradient,
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Column(
                  children: [
                    // ── Header ──────────────────────────────────────
                    _buildHeader(context, currentUser, hostName),

                    const SizedBox(height: 12),

                    // ── Room Code Card ───────────────────────────────
                    _GlossyRoomCode(
                      code: room.code,
                      isCopied: _codeCopied,
                      onCopy: () => _copyCode(room.code),
                      onShare: () => _shareToWhatsApp(room.code),
                    ),

                    const SizedBox(height: 12),

                    // ── Section label ─────────────────────────────────
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'שחקנים בסטודיו',
                        style: AppStyles.heading3.copyWith(
                          shadows: [
                            Shadow(
                              color: AppStyles.cyanGlow.withOpacity(0.8),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 6),

                    // ── Players grid + topic picker (both scroll so the
                    //    start button stays pinned above the Android system
                    //    bar even with the full 11-topic picker) ───────────
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            // כפתור הזמנה בולט — לא רק המשבצת הריקה בגריד.
                            if (room.isFriendsGame) ...[
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: () => _openInviteFriends(room),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF34D399),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(14)),
                                  ),
                                  icon: const Icon(Icons.person_add_alt_1_rounded,
                                      color: Color(0xFF06281C)),
                                  label: const Text('הזמן חברים למשחק',
                                      style: TextStyle(
                                          color: Color(0xFF06281C),
                                          fontWeight: FontWeight.w900,
                                          fontSize: 15)),
                                ),
                              ),
                              // בדיקות: מארח יכול למלא סלוטים בבוט, כדי לשחק
                              // משחק חברים מלא לבד בלי לחכות לחבר אמיתי.
                              if (isHost &&
                                  room.players.length <
                                      GameConstants.maxPlayers) ...[
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: () => ref
                                        .read(roomServiceProvider)
                                        .addBotToRoom(widget.roomId,
                                            room.players.length + 1),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.white70,
                                      side: BorderSide(
                                          color: Colors.white.withOpacity(0.25)),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 10),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(14)),
                                    ),
                                    icon: const Icon(Icons.smart_toy_outlined,
                                        size: 18),
                                    label: const Text('הוסף בוט (לבדיקה)',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13)),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 10),
                            ],
                            _PlayerGrid(
                              players: room.players.values.toList(),
                              currentUserId: currentUser?.id,
                              // Friends games only — invite friends into open slots.
                              onInviteTap: room.isFriendsGame
                                  ? () => _openInviteFriends(room)
                                  : null,
                            ),
                            if (room.selectedDifficulty == Difficulty.giant &&
                                !room.isProverbs) ...[
                              const SizedBox(height: 8),
                              _buildHeatSetup(room, currentUser),
                            ],
                            if (room.isProverbs && room.isFriendsGame) ...[
                              const SizedBox(height: 8),
                              _ProverbsRoundsRow(
                                rounds: room.proverbsRounds,
                                isHost: isHost,
                                onChanged: isHost
                                    ? (v) => ref
                                        .read(roomServiceProvider)
                                        .setProverbsRounds(widget.roomId, v)
                                    : null,
                              ),
                            ],
                            // תחבולות: בחירת מארח למשחק חברים קלאסי (בהיט
                            // הכרטיסים ממילא כבויים). כולם רואים את המצב; רק
                            // המארח יכול לשנות.
                            if (room.isFriendsGame &&
                                room.selectedDifficulty !=
                                    Difficulty.giant) ...[
                              const SizedBox(height: 8),
                              _TricksToggleRow(
                                enabled: room.tricksEnabled,
                                isHost: isHost,
                                onChanged: isHost
                                    ? (v) => ref
                                        .read(roomServiceProvider)
                                        .setTricksEnabled(widget.roomId, v)
                                    : null,
                              ),
                            ],
                            if (room.isFriendsGame) ...[
                              const SizedBox(height: 8),
                              _LetterTurnToggleRow(
                                enabled: room.letterTurnEnabled,
                                isHost: isHost,
                                onChanged: isHost
                                    ? (v) => ref
                                        .read(roomServiceProvider)
                                        .setLetterTurnEnabled(widget.roomId, v)
                                    : null,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // ── Min-players hint (host only, when not enough players) ──
                    if (isHost && !canStart)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          'צריך לפחות 2 שחקנים כדי להתחיל',
                          textAlign: TextAlign.center,
                          style: AppStyles.bodySmall.copyWith(
                            color: const Color(0xFFFFE082).withOpacity(0.85),
                          ),
                        ),
                      ),

                    // ── Action button / waiting footer ─────────────────
                    SizedBox(
                      height: 52,
                      width: double.infinity,
                      child: isHost
                          ? GestureDetector(
                              onTap: !canStart
                                  ? () => QaLoggerService.instance.log(
                                      'LOBBY', 'START_GAME_BLOCKED_MIN_PLAYERS players=${room.players.length}')
                                  : null,
                              child: _GlossyActionButton(
                              label: _isStarting ? 'מכין צמצמים...' : 'התחל משחק',
                              enabled: canStart && !_isStarting,
                              onTap: () async {
                                HapticFeedback.mediumImpact();
                                QaLoggerService.instance.log('LOBBY',
                                    'START_GAME_TAPPED roomId=${widget.roomId}');
                                // Heat friends game: if some players haven't
                                // picked a topic, ask the host how to proceed.
                                if (room.selectedDifficulty == Difficulty.giant &&
                                    !room.isProverbs) {
                                  final unchosen = room.players.values
                                      .where((p) =>
                                          !p.isBot &&
                                          (room.topicChoices[p.id]?.length ??
                                                  0) <
                                              _topicQuota(room, p.id))
                                      .toList();
                                  if (unchosen.isNotEmpty) {
                                    final proceed =
                                        await _confirmStartWithUnchosen(unchosen);
                                    if (proceed != true) return;
                                  }
                                }
                                setState(() => _isStarting = true);
                                try {
                                  await ref
                                      .read(roomServiceProvider)
                                      .startGameDirectly(widget.roomId);
                                  QaLoggerService.instance
                                      .log('LOBBY', 'START_GAME_SUCCESS');
                                } catch (e) {
                                  QaLoggerService.instance
                                      .log('LOBBY', 'START_GAME_ERROR error=$e');
                                  if (mounted) {
                                    setState(() => _isStarting = false);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('לא ניתן להתחיל משחק: $e')),
                                    );
                                  }
                                }
                              },
                            ),
                            )
                          : const _WaitingFooter(),
                    ),
                    const SizedBox(height: 8),
                    _buildLobbyAdButton(),
                    const BannerAdWidget(),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            ),
          ),
        ), // Scaffold
        ); // PopScope
      },
      loading: () => const Scaffold(
        backgroundColor: AppStyles.navyTop,
        body: Center(
          child: CircularProgressIndicator(color: AppStyles.bananaYellow),
        ),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: AppStyles.navyTop,
        body: Center(
          child: Text('שגיאה: $e', style: AppStyles.bodyLarge),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, dynamic currentUser, String hostName) {
    return Row(
      textDirection: TextDirection.rtl,
      children: [
        // Back / leave button
        GestureDetector(
          onTap: () async {
            HapticFeedback.lightImpact();
            if (currentUser != null) {
              await ref
                  .read(roomServiceProvider)
                  .leaveRoom(widget.roomId, currentUser.id);
            }
            if (context.mounted) context.go('/home');
          },
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white38),
              boxShadow: AppStyles.cyanGlowShadow(intensity: 0.3),
            ),
            child: const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),

        const SizedBox(width: 8),

        // Title block — Expanded gives maximum available width
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'ברוכים הבאים לחדר של $hostName',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppStyles.bodySmall.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 2),
              Text(
                'לובי הסטודיו',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppStyles.heading1.copyWith(fontSize: 22),
              ),
            ],
          ),
        ),

        const SizedBox(width: 8),

        // Chat button — opens the room chat from the lobby (balances the back
        // button so the title stays centered).
        GestureDetector(
          onTap: _openChat,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white38),
              boxShadow: AppStyles.cyanGlowShadow(intensity: 0.3),
            ),
            child: const Text('💬', style: TextStyle(fontSize: 18)),
          ),
        ),
      ],
    );
  }
}

// ── Room Code Card ─────────────────────────────────────────────────────────

class _GlossyRoomCode extends StatelessWidget {
  final String code;
  final bool isCopied;
  final VoidCallback onCopy;
  final VoidCallback onShare;

  const _GlossyRoomCode({
    required this.code,
    required this.isCopied,
    required this.onCopy,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: AppStyles.glassCard(radius: 24, opacity: 0.20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // WhatsApp share
                PressableScale(
                  onTap: onShare,
                  scale: 0.88,
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(
                      Icons.share_rounded,
                      color: Color(0xFF25D366),
                      size: 26,
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Room code — tap to copy
                GestureDetector(
                  onTap: onCopy,
                  child: Text(
                    code,
                    style: AppStyles.cyanLabelLarge.copyWith(
                      fontSize: 44,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 5,
                      shadows: AppStyles.cyanGlowShadow(intensity: 0.6)
                          .map((s) => Shadow(
                                color: s.color,
                                blurRadius: s.blurRadius,
                              ))
                          .toList(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Copy status icon
                Icon(
                  isCopied ? Icons.check_circle_rounded : Icons.copy_rounded,
                  color: isCopied ? Colors.greenAccent : Colors.white54,
                  size: 22,
                ),
              ],
            ),
          ),
          Text(
            'לחץ להעתקה או שתף לחברים',
            style: AppStyles.bodySmall.copyWith(color: Colors.white54),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 350.ms, curve: Curves.easeOut)
        .scaleXY(begin: 0.94, end: 1.0, duration: 350.ms, curve: Curves.easeOut);
  }
}

// ── Players Grid (fixed 2 × 4 = 8 slots) ──────────────────────────────────

class _PlayerGrid extends StatelessWidget {
  final List<PlayerModel> players;
  final String? currentUserId;
  // Tapping an empty slot opens the "invite a friend" picker (null = disabled).
  final VoidCallback? onInviteTap;

  const _PlayerGrid(
      {required this.players, this.currentUserId, this.onInviteTap});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 8,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 8,
        childAspectRatio: 2.0,
      ),
      itemBuilder: (context, index) {
        if (index < players.length) {
          return _PlayerAvatarTile(
            player: players[index],
            isMe: players[index].id == currentUserId,
            delay: Duration(milliseconds: 120 + index * 55),
          );
        }
        return _EmptyPlayerTile(onTap: onInviteTap);
      },
    );
  }
}

// ── Filled player slot ─────────────────────────────────────────────────────

class _PlayerAvatarTile extends StatelessWidget {
  final PlayerModel player;
  final bool isMe;
  final Duration delay;

  const _PlayerAvatarTile({
    required this.player,
    required this.isMe,
    this.delay = Duration.zero,
  });

  @override
  Widget build(BuildContext context) {
    final base = isMe ? 'אני' : (player.name.isNotEmpty ? player.name : 'שחקן');
    final label = player.isHost ? '$base ⭐' : base;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: AppStyles.glassCard(radius: 16, opacity: 0.18).copyWith(
            boxShadow: isMe ? AppStyles.cyanGlowShadow(intensity: 0.7) : null,
            border: Border.all(
              color: isMe
                  ? AppStyles.cyanGlow.withOpacity(0.7)
                  : Colors.white.withOpacity(0.20),
              width: isMe ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              // Avatar with cyan ring for current user
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isMe ? AppStyles.cyanGlow : Colors.white38,
                    width: 2,
                  ),
                  boxShadow: isMe ? AppStyles.cyanGlowShadow(intensity: 0.5) : null,
                ),
                child: PlayerAvatar(
                    name: player.name,
                    radius: 14,
                    frameId: player.frameId,
                    avatarId: player.avatarId),
              ),
              const SizedBox(width: 8),

              // Name + round badge
              Expanded(
                child: PlayerNameText(
                  text: label,
                  styleId: player.nameStyleId,
                  base: AppStyles.bodyMedium.copyWith(
                    color: isMe ? AppStyles.cyanGlow : Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (player.playerRound > 0)
                Container(
                  margin: const EdgeInsets.only(right: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.withOpacity(0.5), width: 0.8),
                  ),
                  child: Text(
                    'סבב ${player.playerRound + 1}',
                    style: const TextStyle(
                      fontSize: 9,
                      color: Colors.amber,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
        // Discovered count badge — top-left corner (RTL = top-start)
        Positioned(
          top: -6,
          left: -6,
          child: _DiscoveredBadge(count: player.discoveredCount),
        ),
      ],
    )
        .animate()
        .fadeIn(delay: delay, duration: 280.ms, curve: Curves.easeOut)
        .slideX(begin: -0.06, end: 0, delay: delay, duration: 280.ms, curve: Curves.easeOut);
  }
}

// ── Persistent share/code row — always visible, no friends-list dependency ──

class _ShareCodeRow extends StatefulWidget {
  final String code;
  final VoidCallback onShare;
  const _ShareCodeRow({required this.code, required this.onShare});

  @override
  State<_ShareCodeRow> createState() => _ShareCodeRowState();
}

class _ShareCodeRowState extends State<_ShareCodeRow> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    HapticFeedback.lightImpact();
    if (!mounted) return;
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: _copy,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.14)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                      _copied
                          ? Icons.check_rounded
                          : Icons.copy_rounded,
                      color: _copied
                          ? const Color(0xFF34D399)
                          : Colors.white54,
                      size: 16),
                  const SizedBox(width: 6),
                  Text(
                    _copied ? 'הועתק!' : widget.code,
                    style: TextStyle(
                      color: _copied ? const Color(0xFF34D399) : Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FilledButton.icon(
            onPressed: widget.onShare,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.share_rounded, size: 17, color: Colors.white),
            label: const Text('שתף קישור',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900)),
          ),
        ),
      ],
    );
  }
}

// ── Invite-a-friend picker (friends list + search) ─────────────────────────

class _InviteFriendsSheet extends ConsumerStatefulWidget {
  final String roomId;
  final String code;
  final Set<String> existingPlayerIds;
  final VoidCallback onShareCode;

  const _InviteFriendsSheet({
    required this.roomId,
    required this.code,
    required this.existingPlayerIds,
    required this.onShareCode,
  });

  @override
  ConsumerState<_InviteFriendsSheet> createState() =>
      _InviteFriendsSheetState();
}

class _InviteFriendsSheetState extends ConsumerState<_InviteFriendsSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  final Set<String> _invited = {};
  String? _busyUid;
  String? _busyGroupId;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _invite(FriendModel f) async {
    final me = ref.read(currentUserProvider).valueOrNull;
    if (me == null || _busyUid != null) return;
    setState(() => _busyUid = f.uid);
    try {
      await ref.read(friendsServiceProvider).sendGameInvite(
            fromUid: me.id,
            fromName: me.name,
            toUid: f.uid,
            roomId: widget.roomId,
            code: widget.code,
          );
      if (mounted) setState(() => _invited.add(f.uid));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('שגיאה בשליחת ההזמנה')),
        );
      }
    } finally {
      if (mounted) setState(() => _busyUid = null);
    }
  }

  /// חברי הקבוצה שעדיין אפשר להזמין (לא אני, לא בחדר, לא הוזמנו כבר).
  List<String> _groupTargets(GroupModel g, String myUid) => g.memberUids
      .where((uid) =>
          uid != myUid &&
          !widget.existingPlayerIds.contains(uid) &&
          !_invited.contains(uid))
      .toList();

  Future<void> _inviteGroup(GroupModel g) async {
    final me = ref.read(currentUserProvider).valueOrNull;
    if (me == null || _busyGroupId != null) return;
    final targets = _groupTargets(g, me.id);
    if (targets.isEmpty) return;
    setState(() => _busyGroupId = g.id);
    HapticFeedback.lightImpact();
    var sent = 0;
    try {
      for (final uid in targets) {
        await ref.read(friendsServiceProvider).sendGameInvite(
              fromUid: me.id,
              fromName: me.name,
              toUid: uid,
              roomId: widget.roomId,
              code: widget.code,
            );
        sent++;
        if (mounted) setState(() => _invited.add(uid));
      }
      QaLoggerService.instance.log(
          'LOBBY', 'GROUP_INVITED group=${g.id} sent=$sent');
    } catch (_) {
      if (mounted && sent == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('שגיאה בשליחת ההזמנות')),
        );
      }
    } finally {
      if (mounted) setState(() => _busyGroupId = null);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  /// אין עדיין קבוצה קבועה — פותח את אותו יוצר-קבוצה מטאב "קבוצות", כדי
  /// שהיכולת תהיה נגישה גם למי שעוד לא הקים קבוצה.
  void _openCreateGroup(List<FriendModel> friends) {
    if (friends.isEmpty) {
      _toast('קודם הוסיפו חברים (בטאב "הוסף חבר")');
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreateGroupSheet(friends: friends, onToast: _toast),
    );
  }

  @override
  Widget build(BuildContext context) {
    final friends =
        ref.watch(friendsListProvider).valueOrNull ?? const <FriendModel>[];
    final me = ref.watch(currentUserProvider).valueOrNull;
    final groups = me == null
        ? const <GroupModel>[]
        : ref.watch(myGroupsProvider).valueOrNull ?? const <GroupModel>[];
    // חי, כדי שהמארח יראה כאן גם את בקרת התחבולות בלי לגלול/לסגור את
    // מרכז ההזמנות, שנפתח אוטומטית ומכסה את שאר מסך הלובי.
    final liveRoom = ref.watch(roomStreamProvider(widget.roomId)).valueOrNull;
    final isHost = liveRoom != null && me != null && liveRoom.hostId == me.id;
    final q = _query.trim();
    final filtered =
        q.isEmpty ? friends : friends.where((f) => f.name.contains(q)).toList();
    // מקלדת (viewInsets) וגם פס הניווט של אנדרואיד / ה-home indicator של
    // iOS (viewPadding) — אחרת רשימת החברים התחתונה מוסתרת מאחורי הפקדים.
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final navBarInset = MediaQuery.of(context).viewPadding.bottom;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.78,
          decoration: const BoxDecoration(
            color: Color(0xFF0D1E30),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + navBarInset),
          child: Column(
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 14),
              const Text('הזמן חברים למשחק',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              // ── שורת שיתוף קבועה — הדרך המהירה ביותר, בלי צורך ברשימת
              //    חברים בכלל (וואטסאפ / קישור / קוד להעתקה).
              _ShareCodeRow(code: widget.code, onShare: widget.onShareCode),
              if (liveRoom != null &&
                  liveRoom.isFriendsGame &&
                  liveRoom.selectedDifficulty != Difficulty.giant) ...[
                const SizedBox(height: 12),
                _TricksToggleRow(
                  enabled: liveRoom.tricksEnabled,
                  isHost: isHost,
                  onChanged: isHost
                      ? (v) => ref
                          .read(roomServiceProvider)
                          .setTricksEnabled(widget.roomId, v)
                      : null,
                ),
              ],
              if (liveRoom != null && liveRoom.isFriendsGame) ...[
                const SizedBox(height: 12),
                _LetterTurnToggleRow(
                  enabled: liveRoom.letterTurnEnabled,
                  isHost: isHost,
                  onChanged: isHost
                      ? (v) => ref
                          .read(roomServiceProvider)
                          .setLetterTurnEnabled(widget.roomId, v)
                      : null,
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _query = v),
                textDirection: TextDirection.rtl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'חיפוש חבר…',
                  hintStyle: const TextStyle(color: Colors.white38),
                  prefixIcon:
                      const Icon(Icons.search_rounded, color: Colors.white38),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.06),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 10),
              // כל השאר גולל כיחידה אחת (כולל "הקבוצות שלי") כדי שלרשימת
              // השמות יהיה שטח גלילה נוח — לא עוד Expanded דחוס מתחת לכל
              // הכותרות/הבקרים, שגדל עם כל פיצ'ר חדש שנוסף מעליו.
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (me != null) ...[
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text('הקבוצות שלי',
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.75),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(height: 8),
                        if (groups.isNotEmpty)
                          SizedBox(
                            height: 68,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              reverse: true,
                              itemCount: groups.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 8),
                              itemBuilder: (_, i) =>
                                  _groupChip(groups[i], me.id),
                            ),
                          )
                        else
                          InkWell(
                            onTap: () => _openCreateGroup(friends),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: Colors.white.withOpacity(0.12)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.group_add_rounded,
                                      color: Color(0xFF4A9EFF), size: 18),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                        'אין לך עדיין קבוצה קבועה, צרו אחת כדי להזמין בלחיצה',
                                        style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 13)),
                                  ),
                                  const Icon(Icons.chevron_left_rounded,
                                      color: Colors.white38, size: 18),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 14),
                      ],
                      friends.isEmpty
                          ? SizedBox(height: 260, child: _emptyState())
                          : (filtered.isEmpty
                              ? const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 40),
                                  child: Center(
                                    child: Text('לא נמצא חבר בשם הזה',
                                        style:
                                            TextStyle(color: Colors.white54)),
                                  ),
                                )
                              : ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: filtered.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 8),
                                  itemBuilder: (_, i) =>
                                      _friendRow(filtered[i]),
                                )),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _groupChip(GroupModel g, String myUid) {
    final targets = _groupTargets(g, myUid);
    final busy = _busyGroupId == g.id;
    final allDone = targets.isEmpty;
    return InkWell(
      onTap: (busy || allDone) ? null : () => _inviteGroup(g),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 132,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: allDone
              ? Colors.white.withOpacity(0.04)
              : const Color(0xFF34D399).withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: allDone
                ? Colors.white.withOpacity(0.10)
                : const Color(0xFF34D399).withOpacity(0.5),
            width: 1.2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(g.name.isEmpty ? 'קבוצה' : g.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textDirection: TextDirection.rtl,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            busy
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Color(0xFF34D399)))
                : Text(
                    allDone ? 'כולם הוזמנו' : 'הזמן ${targets.length} 👥',
                    style: TextStyle(
                        color: allDone
                            ? Colors.white38
                            : const Color(0xFF34D399),
                        fontSize: 12,
                        fontWeight: FontWeight.w700),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _friendRow(FriendModel f) {
    final inRoom = widget.existingPlayerIds.contains(f.uid);
    final invited = _invited.contains(f.uid);
    final busy = _busyUid == f.uid;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Row(
        children: [
          PlayerAvatar(name: f.name, photoUrl: f.photoUrl, radius: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(f.name.isEmpty ? 'שחקן' : f.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
          ),
          if (inRoom)
            const Text('בחדר',
                style: TextStyle(color: Colors.white38, fontSize: 13))
          else if (invited)
            const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.check_circle_rounded,
                  color: Color(0xFF34D399), size: 18),
              SizedBox(width: 4),
              Text('הוזמן',
                  style: TextStyle(
                      color: Color(0xFF34D399),
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ])
          else
            IconButton(
              onPressed: busy ? null : () => _invite(f),
              icon: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppStyles.cyanGlow))
                  : Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppStyles.cyanGlow.withOpacity(0.14),
                        border: Border.all(
                            color: AppStyles.cyanGlow.withOpacity(0.6),
                            width: 1.5),
                      ),
                      child: const Icon(Icons.add,
                          color: AppStyles.cyanGlow, size: 20),
                    ),
            ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('עדיין אין לך חברים',
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text('הוסיפו חברים במסך החברים, או שתפו קוד חדר',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, fontSize: 13)),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              widget.onShareCode();
            },
            icon: const Icon(Icons.share_rounded, size: 18),
            style: FilledButton.styleFrom(
              backgroundColor: AppStyles.cyanGlow,
              foregroundColor: const Color(0xFF07101F),
            ),
            label: const Text('שתף קוד חדר',
                style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }
}

// ── Empty waiting slot ─────────────────────────────────────────────────────

class _EmptyPlayerTile extends StatelessWidget {
  // When set, the slot is tappable and opens the invite-a-friend picker.
  final VoidCallback? onTap;
  const _EmptyPlayerTile({this.onTap});

  @override
  Widget build(BuildContext context) {
    final invitable = onTap != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white.withOpacity(0.04),
            border: Border.all(
              color: invitable
                  ? AppStyles.cyanGlow.withOpacity(0.30)
                  : Colors.white.withOpacity(0.08),
              width: 1,
            ),
          ),
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: invitable
                      ? AppStyles.cyanGlow.withOpacity(0.12)
                      : Colors.white.withOpacity(0.06),
                  border: Border.all(
                      color: invitable
                          ? AppStyles.cyanGlow.withOpacity(0.55)
                          : Colors.white12,
                      width: 1.5),
                ),
                child: Icon(Icons.add,
                    color: invitable ? AppStyles.cyanGlow : Colors.white24,
                    size: 20),
              ),
              const SizedBox(width: 10),
              if (invitable)
                Expanded(
                  child: Text(
                    'הזמן חבר',
                    style: AppStyles.bodySmall
                        .copyWith(color: AppStyles.cyanGlow, fontWeight: FontWeight.w700),
                  ),
                )
              else
                SoftPulse(
                  minOpacity: 0.35,
                  maxOpacity: 0.70,
                  child: Text(
                    'ממתין...',
                    style: AppStyles.bodySmall.copyWith(color: Colors.white24),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Start game button (host only) ──────────────────────────────────────────

class _GlossyActionButton extends StatefulWidget {
  final String label;
  final bool enabled;
  final VoidCallback onTap;
  const _GlossyActionButton({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  @override
  State<_GlossyActionButton> createState() => _GlossyActionButtonState();
}

class _GlossyActionButtonState extends State<_GlossyActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed && widget.enabled ? 0.97 : 1.0,
      duration: _pressed
          ? const Duration(milliseconds: 90)
          : const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: widget.enabled ? widget.onTap : null,
          onHighlightChanged:
              widget.enabled ? (h) => setState(() => _pressed = h) : null,
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            decoration: widget.enabled
                ? AppStyles.glossyButton(radius: 20)
                : BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: Colors.white10,
                    border: Border.all(color: Colors.white12),
                  ),
            child: Center(
              child: Text(
                widget.label,
                style: AppStyles.labelButton.copyWith(
                  fontSize: 20,
                  color: widget.enabled ? AppStyles.darkText : Colors.white24,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Discovered badge ───────────────────────────────────────────────────────

class _DiscoveredBadge extends StatelessWidget {
  final int count;
  const _DiscoveredBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF061422),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF4A8BAA).withOpacity(0.55), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🌍', style: TextStyle(fontSize: 9)),
          const SizedBox(width: 2),
          Text(
            '$count',
            style: const TextStyle(
              color: Color(0xFF87CEEB),
              fontSize: 10,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Non-host waiting message ───────────────────────────────────────────────

class _WaitingFooter extends StatelessWidget {
  const _WaitingFooter();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      alignment: Alignment.center,
      decoration: AppStyles.glassCard(radius: 20, opacity: 0.10),
      child: SoftPulse(
        minOpacity: 0.50,
        maxOpacity: 1.0,
        child: Text(
          'ממתין למארח שיתחיל...',
          style: AppStyles.bodyMedium.copyWith(color: Colors.white54),
        ),
      ),
    );
  }
}


/// שורת "עם/בלי תחבולות" בלובי חברים — טוגל למארח, תצוגה לשאר.
class _TricksToggleRow extends StatelessWidget {
  final bool enabled;
  final bool isHost;
  final ValueChanged<bool>? onChanged;

  const _TricksToggleRow({
    required this.enabled,
    required this.isHost,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1E30).withOpacity(0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          Text(enabled ? '🃏' : '🕊️', style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'תחבולות במשחק',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  enabled
                      ? 'כרטיסי חסימה, החשכה ועצירה פעילים'
                      : 'משחק נקי, בלי כרטיסי פעולה',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.55),
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: enabled,
            onChanged: onChanged,
            activeColor: const Color(0xFF8B4FBF),
          ),
        ],
      ),
    );
  }
}

/// Host-only round-count picker for "זהו את הפתגם" friends games (1-5).
/// Quick-match proverbs always plays a single fixed round instead.
class _ProverbsRoundsRow extends StatelessWidget {
  final int rounds;
  final bool isHost;
  final ValueChanged<int>? onChanged;

  const _ProverbsRoundsRow({
    required this.rounds,
    required this.isHost,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1E30).withOpacity(0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          const Text('🧩', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'מספר סבבים',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  isHost ? 'המארח בוחר בין 1 ל-5' : 'נבחר על ידי המארח',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.55),
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: (isHost && onChanged != null && rounds > 1)
                ? () => onChanged!(rounds - 1)
                : null,
            icon: const Icon(Icons.remove_circle_outline_rounded),
            color: const Color(0xFFFFE082),
            disabledColor: Colors.white24,
          ),
          SizedBox(
            width: 22,
            child: Text(
              '$rounds',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          IconButton(
            onPressed: (isHost && onChanged != null && rounds < 5)
                ? () => onChanged!(rounds + 1)
                : null,
            icon: const Icon(Icons.add_circle_outline_rounded),
            color: const Color(0xFFFFE082),
            disabledColor: Colors.white24,
          ),
        ],
      ),
    );
  }
}

/// Host-only toggle for the turn-based letter-guess hint layer (off by
/// default): each player's turn, guess one letter and every occurrence in the
/// answer reveals at once. Works alongside the normal reveal/guess race in
/// every game mode (places, heat, proverbs).
class _LetterTurnToggleRow extends StatelessWidget {
  final bool enabled;
  final bool isHost;
  final ValueChanged<bool>? onChanged;

  const _LetterTurnToggleRow({
    required this.enabled,
    required this.isHost,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1E30).withOpacity(0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          Text(enabled ? '🔤' : '🔠', style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ניחוש אותיות בתורות',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  enabled
                      ? 'כל שחקן מנחש אות בתורו, 5 שניות לבחירה'
                      : 'כבוי, המשחק נשאר כרגיל',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.55),
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: enabled,
            onChanged: onChanged,
            activeColor: const Color(0xFF8B4FBF),
          ),
        ],
      ),
    );
  }
}
