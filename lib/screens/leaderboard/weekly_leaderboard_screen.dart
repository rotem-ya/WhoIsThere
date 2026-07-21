import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/candy_theme.dart';
import '../../core/ui/app_scaffold.dart';
import '../../providers/providers.dart';
import '../../services/sfx_service.dart';
import '../../services/weekly_leaderboard_service.dart';
import '../../widgets/common/app_header.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/player_avatar.dart';
import '../../widgets/common/skeleton.dart';
import '../../widgets/economy/coin_fly.dart';

class WeeklyLeaderboardScreen extends ConsumerStatefulWidget {
  const WeeklyLeaderboardScreen({super.key});

  @override
  ConsumerState<WeeklyLeaderboardScreen> createState() =>
      _WeeklyLeaderboardScreenState();
}

class _WeeklyLeaderboardScreenState
    extends ConsumerState<WeeklyLeaderboardScreen> {
  int? _myRank;
  ({int place, int reward})? _prize;
  bool _claiming = false;
  bool _prizeClaimed = false;
  final GlobalKey _prizeKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadExtras();
  }

  Future<void> _loadExtras() async {
    final uid = ref.read(firebaseUserProvider).valueOrNull?.uid;
    if (uid == null) return;
    final svc = ref.read(weeklyLeaderboardServiceProvider);
    final rank = await svc.myRank(uid);
    final prize = await svc.lastWeekPrizeStatus(uid);
    if (mounted) setState(() {
      _myRank = rank;
      _prize = prize;
    });
  }

  Future<void> _claimPrize() async {
    if (_claiming) return;
    final uid = ref.read(firebaseUserProvider).valueOrNull?.uid;
    if (uid == null) return;
    setState(() => _claiming = true);
    try {
      final res =
          await ref.read(weeklyLeaderboardServiceProvider).claimLastWeekPrize(uid);
      if (!mounted) return;
      setState(() {
        _claiming = false;
        _prizeClaimed = true;
      });
      if (res != null) {
        HapticFeedback.mediumImpact();
        SfxService.instance.coinGain();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final box = _prizeKey.currentContext?.findRenderObject() as RenderBox?;
          if (box == null || !box.hasSize) return;
          final from = box.localToGlobal(box.size.center(Offset.zero));
          CoinFly.burst(context, from: from, count: (res.coins ~/ 6).clamp(8, 18));
        });
      }
    } catch (_) {
      if (mounted) setState(() => _claiming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final topAsync = ref.watch(weeklyTopProvider);
    final myUid = ref.watch(firebaseUserProvider).valueOrNull?.uid;

    return AppScaffold(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
            child: AppHeader(
              title: '🏆 טבלה שבועית',
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/home');
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'המנצחים מתאפסים בכל שבוע. שחקו כדי לטפס!',
            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
          ),
          const SizedBox(height: 10),
          if (_prize != null && !_prizeClaimed) _prizeCard(),
          Expanded(
            child: topAsync.when(
              loading: () => const SingleChildScrollView(
                  child: SkeletonList(rows: 8)),
              error: (_, __) => const Center(
                child: Text('שגיאה בטעינת הטבלה',
                    style: TextStyle(color: Colors.white54)),
              ),
              data: (rows) {
                if (rows.isEmpty) {
                  return const EmptyState(
                    emoji: '🏆',
                    title: 'הטבלה השבועית ריקה',
                    subtitle: 'שחקו משחק כדי להיות הראשונים על הלוח',
                    accent: Candy.gold,
                  );
                }
                final inTop = rows.any((e) => e.uid == myUid);
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
                  itemCount: rows.length + (inTop || _myRank == null ? 0 : 1),
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    if (i >= rows.length) {
                      // A trailing "you" row when outside the top N.
                      return _MyRow(rank: _myRank!);
                    }
                    return _Row(
                      rank: i + 1,
                      entry: rows[i],
                      isMe: rows[i].uid == myUid,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _prizeCard() {
    final p = _prize!;
    final medal = p.place == 1 ? '🥇' : p.place == 2 ? '🥈' : '🥉';
    return Container(
      key: _prizeKey,
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          Candy.gold.withOpacity(0.24),
          Candy.tangerine.withOpacity(0.14),
        ]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Candy.gold.withOpacity(0.5)),
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Text(medal, style: const TextStyle(fontSize: 30)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'סיימתם במקום $medal בשבוע שעבר!\nפרס: ${p.reward} מטבעות',
              textDirection: TextDirection.rtl,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  height: 1.3),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _claiming ? null : _claimPrize,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFFFFE082), Candy.gold]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: _claiming
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Color(0xFF07101F)))
                  : const Text('אסוף',
                      style: TextStyle(
                          color: Color(0xFF07101F),
                          fontSize: 14,
                          fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final int rank;
  final WeeklyEntry entry;
  final bool isMe;
  const _Row({required this.rank, required this.entry, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final medal = rank == 1
        ? '🥇'
        : rank == 2
            ? '🥈'
            : rank == 3
                ? '🥉'
                : '$rank';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: isMe
            ? Candy.teal.withOpacity(0.18)
            : Candy.surfaceLow.withOpacity(0.45),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isMe ? Candy.teal.withOpacity(0.7) : Colors.white.withOpacity(0.08),
          width: isMe ? 1.6 : 1,
        ),
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          SizedBox(
            width: 34,
            child: Text(medal,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: rank <= 3 ? Candy.gold : Colors.white70,
                    fontSize: rank <= 3 ? 20 : 15,
                    fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 6),
          PlayerAvatar(name: entry.name, photoUrl: entry.photoUrl, radius: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isMe ? '${entry.name} (את/ה)' : entry.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isMe ? Candy.teal : Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text.rich(
            TextSpan(text: '${entry.points} ', children: const [
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Icon(Icons.star_rounded, color: Candy.gold, size: 15),
              ),
            ]),
            style: const TextStyle(
                color: Candy.gold, fontSize: 15, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _MyRow extends ConsumerWidget {
  final int rank;
  const _MyRow({required this.rank});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider).valueOrNull;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: Candy.teal.withOpacity(0.18),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Candy.teal.withOpacity(0.7), width: 1.6),
        ),
        child: Row(
          textDirection: TextDirection.rtl,
          children: [
            SizedBox(
              width: 34,
              child: Text('$rank',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Candy.teal,
                      fontSize: 15,
                      fontWeight: FontWeight.w900)),
            ),
            const SizedBox(width: 6),
            PlayerAvatar(name: me?.name ?? 'אני', photoUrl: me?.photoUrl, radius: 16),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('המיקום שלך',
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                      color: Candy.teal,
                      fontSize: 15,
                      fontWeight: FontWeight.w800)),
            ),
            const Icon(Icons.expand_less_rounded, color: Candy.teal, size: 20),
          ],
        ),
      ),
    );
  }
}
