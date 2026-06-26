import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_styles.dart';
import '../../models/friend_models.dart';
import '../../providers/providers.dart';
import '../../services/friends_service.dart';

/// Friends hub: a cumulative leaderboard, the friends list with pending
/// requests, and an "add friend" tab (personal code + WhatsApp invite).
class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> {
  final _codeController = TextEditingController();
  String? _myCode;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadMyCode();
    _maybeAutoAddFromInvite();
  }

  /// If we arrived here from a friend-invite deep link, send the request to the
  /// inviter automatically (no manual code entry needed).
  void _maybeAutoAddFromInvite() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final code = ref.read(pendingFriendCodeProvider);
      if (code == null) return;
      final me = ref.read(currentUserProvider).valueOrNull;
      if (me == null) return; // not ready yet — keep the code for a later retry
      ref.read(pendingFriendCodeProvider.notifier).state = null; // consume once
      try {
        await ref.read(friendsServiceProvider).sendRequestByCode(
              myUid: me.id,
              myName: me.name,
              code: code,
            );
        _toast('בקשת החברות נשלחה אוטומטית 🎉');
      } on FriendException catch (e) {
        _toast(e.message);
      } catch (_) {
        _toast('שגיאה בהוספת החבר');
      }
    });
  }

  Future<void> _loadMyCode() async {
    final uid = ref.read(firebaseUserProvider).valueOrNull?.uid;
    if (uid == null) return;
    try {
      final code = await ref.read(friendsServiceProvider).ensureFriendCode(uid);
      if (mounted) setState(() => _myCode = code);
    } catch (_) {}
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _sendRequest() async {
    final me = ref.read(currentUserProvider).valueOrNull;
    if (me == null) return;
    FocusScope.of(context).unfocus();
    setState(() => _sending = true);
    try {
      await ref.read(friendsServiceProvider).sendRequestByCode(
            myUid: me.id,
            myName: me.name,
            code: _codeController.text,
          );
      _codeController.clear();
      _toast('הבקשה נשלחה! 🎉');
    } on FriendException catch (e) {
      _toast(e.message);
    } catch (_) {
      _toast('שגיאה בשליחת הבקשה');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _shareInvite() {
    final code = _myCode;
    if (code == null) return;
    HapticFeedback.lightImpact();
    final msg = StringBuffer()
      ..writeln('בוא נשחק "מה בתמונה?" יחד 📸')
      ..writeln()
      ..writeln('הוסיפו אותי כחבר בלחיצה אחת:')
      ..writeln(AppConstants.friendInviteUrl(code))
      ..writeln()
      ..writeln('אין אפליקציה? הקוד שלי: $code');
    Share.share(msg.toString());
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: Container(
            decoration: const BoxDecoration(gradient: AppStyles.backgroundGradient),
            child: SafeArea(
              child: Column(
                children: [
                  _header(context),
                  const TabBar(
                    labelColor: AppStyles.cyanGlow,
                    unselectedLabelColor: Colors.white54,
                    indicatorColor: AppStyles.cyanGlow,
                    labelStyle:
                        TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                    tabs: [
                      Tab(text: 'טבלת ניקוד'),
                      Tab(text: 'חברים'),
                      Tab(text: 'הוסף חבר'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _LeaderboardTab(),
                        _FriendsTab(onToast: _toast),
                        _addFriendTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white),
              onPressed: () =>
                  context.canPop() ? context.pop() : context.go('/home'),
            ),
            const Expanded(
              child: Text('חברים',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900)),
            ),
            const SizedBox(width: 48),
          ],
        ),
      );

  Widget _addFriendTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── My code card ──────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: AppStyles.glassCard(radius: 18, opacity: 0.14),
            child: Column(
              children: [
                const Text('הקוד שלי',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () {
                    if (_myCode == null) return;
                    Clipboard.setData(ClipboardData(text: _myCode!));
                    _toast('הקוד הועתק');
                  },
                  child: Text(
                    _myCode ?? '· · · · · ·',
                    style: const TextStyle(
                      color: AppStyles.bananaYellow,
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 6,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _myCode == null ? null : _shareInvite,
                    icon: const Icon(Icons.share_rounded, size: 20),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    label: const Text('הזמן חבר',
                        style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Add by code ───────────────────────────────────────────────
          const Text('הוספת חבר לפי קוד',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          TextField(
            controller: _codeController,
            textCapitalization: TextCapitalization.characters,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 4),
            decoration: InputDecoration(
              hintText: 'קוד החבר',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: Colors.white.withOpacity(0.06),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: _sending ? null : _sendRequest,
              style: FilledButton.styleFrom(
                backgroundColor: AppStyles.cyanGlow,
                foregroundColor: const Color(0xFF07101F),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: _sending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Color(0xFF07101F)))
                  : const Text('שלח בקשת חברות',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Leaderboard tab ───────────────────────────────────────────────────────────

class _LeaderboardTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boardAsync = ref.watch(friendsLeaderboardProvider);
    final games = ref.watch(friendGamesProvider).valueOrNull ?? const [];

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(friendsLeaderboardProvider),
      child: boardAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: AppStyles.cyanGlow)),
        error: (e, _) => ListView(children: const [
          SizedBox(height: 80),
          Center(child: Text('שגיאה בטעינה', style: TextStyle(color: Colors.white54))),
        ]),
        data: (rows) {
          if (rows.length <= 1) {
            return ListView(children: const [
              SizedBox(height: 80),
              Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'עדיין אין חברים בטבלה.\nהוסיפו חברים ושחקו יחד כדי לראות מי מוביל!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54, fontSize: 15),
                  ),
                ),
              ),
            ]);
          }
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              for (var i = 0; i < rows.length; i++) _scoreRow(i + 1, rows[i]),
              if (games.isNotEmpty) ...[
                const SizedBox(height: 18),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  child: Text('משחקים אחרונים',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800)),
                ),
                for (final g in games) _gameRow(g),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _scoreRow(int rank, FriendScore s) {
    final medal = rank == 1
        ? '🥇'
        : rank == 2
            ? '🥈'
            : rank == 3
                ? '🥉'
                : '$rank';
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: s.isMe
            ? AppStyles.cyanGlow.withOpacity(0.14)
            : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: s.isMe
              ? AppStyles.cyanGlow.withOpacity(0.5)
              : Colors.white.withOpacity(0.10),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
              width: 34,
              child: Text(medal,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900))),
          const SizedBox(width: 8),
          Expanded(
            child: Text(s.isMe ? '${s.name} (אני)' : s.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: s.isMe ? AppStyles.cyanGlow : Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800)),
          ),
          Text('${s.points}',
              style: const TextStyle(
                  color: AppStyles.bananaYellow,
                  fontSize: 18,
                  fontWeight: FontWeight.w900)),
          const SizedBox(width: 4),
          const Text('נק׳', style: TextStyle(color: Colors.white38, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _gameRow(FriendGameRecord g) {
    final summary = g.scores
        .map((e) => '${e.name} ${e.score}')
        .join(' · ');
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🏆 ', style: TextStyle(fontSize: 13)),
              Expanded(
                child: Text(
                    g.winnerName.isEmpty ? 'משחק חברים' : 'ניצח/ה: ${g.winnerName}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(summary,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ],
      ),
    );
  }
}

// ── Friends + requests tab ────────────────────────────────────────────────────

class _FriendsTab extends ConsumerWidget {
  final void Function(String) onToast;
  const _FriendsTab({required this.onToast});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(friendRequestsProvider).valueOrNull ?? const [];
    final friends = ref.watch(friendsListProvider).valueOrNull ?? const [];
    final me = ref.watch(currentUserProvider).valueOrNull;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (requests.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Text('בקשות חברות',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800)),
          ),
          for (final r in requests)
            _requestRow(context, ref, r, me?.name ?? 'אני'),
          const SizedBox(height: 14),
        ],
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Text('החברים שלי',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800)),
        ),
        if (friends.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: Text('עדיין אין חברים.\nעברו ל"הוסף חבר" כדי להתחיל.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, fontSize: 15)),
            ),
          )
        else
          for (final f in friends) _friendRow(context, ref, f, me?.id),
      ],
    );
  }

  Widget _requestRow(BuildContext context, WidgetRef ref,
      FriendRequestModel r, String myName) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppStyles.cyanGlow.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppStyles.cyanGlow.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(r.fromName.isEmpty ? 'שחקן' : r.fromName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
          ),
          IconButton(
            icon: const Icon(Icons.check_circle, color: Color(0xFF34D399)),
            onPressed: () async {
              try {
                await ref
                    .read(friendsServiceProvider)
                    .acceptRequest(r, myName);
                onToast('נוסף לרשימת החברים 🎉');
              } catch (_) {
                onToast('שגיאה');
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.cancel, color: Color(0xFFFF6B6B)),
            onPressed: () async {
              try {
                await ref.read(friendsServiceProvider).declineRequest(r);
              } catch (_) {}
            },
          ),
        ],
      ),
    );
  }

  Widget _friendRow(
      BuildContext context, WidgetRef ref, FriendModel f, String? myUid) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 16,
            backgroundColor: Color(0xFF13243B),
            child: Icon(Icons.person, color: Colors.white70, size: 18),
          ),
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
          IconButton(
            icon: const Icon(Icons.person_remove_rounded,
                color: Colors.white38, size: 20),
            onPressed: myUid == null
                ? null
                : () => _confirmRemove(context, ref, f, myUid),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRemove(
      BuildContext context, WidgetRef ref, FriendModel f, String myUid) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF0D1E30),
          title: const Text('להסיר חבר?',
              style: TextStyle(color: Colors.white, fontSize: 17)),
          content: Text('להסיר את ${f.name} מרשימת החברים?',
              style: const TextStyle(color: Colors.white70, fontSize: 14)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('ביטול', style: TextStyle(color: Colors.white54)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('הסר',
                  style: TextStyle(
                      color: Color(0xFFFF6B6B), fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
    if (ok == true) {
      try {
        await ref.read(friendsServiceProvider).removeFriend(myUid, f.uid);
        onToast('הוסר מהחברים');
      } catch (_) {
        onToast('שגיאה');
      }
    }
  }
}
