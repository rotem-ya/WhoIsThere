import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/game_categories.dart';
import '../../../core/constants/game_constants.dart';
import '../../../models/friend_models.dart';
import '../../../providers/providers.dart';
import '../../../widgets/chat/chat_sheet.dart';

/// טאב "קבוצות" — קבוצות חברים קבועות: פתיחת משחק לכל החבורה בלחיצה (הזמנות
/// פוש לכולם), טבלת ניקוד מצטברת לקבוצה, וצ'אט קבוצתי קבוע.
class GroupsTab extends ConsumerWidget {
  final void Function(String) onToast;
  const GroupsTab({super.key, required this.onToast});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(myGroupsProvider).valueOrNull ?? const [];
    final me = ref.watch(currentUserProvider).valueOrNull;
    // חובה watch (ולא read בזמן הלחיצה): הפרוביידר autoDispose ומתאפס כשאף
    // אחד לא צופה בו — קריאה קרה מהטאב הזה החזירה רשימה ריקה למרות שיש חברים.
    final friends = ref.watch(friendsListProvider).valueOrNull;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: me == null
                ? null
                : () => _openCreateSheet(context, ref, friends),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1A6CB0),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.group_add_rounded),
            label: const Text('קבוצה חדשה',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
          ),
        ),
        const SizedBox(height: 12),
        if (groups.isEmpty)
          const Padding(
            padding: EdgeInsets.all(28),
            child: Center(
              child: Text(
                'צרו קבוצה קבועה של חברים —\nמשחק לכל החבורה בלחיצה אחת! 🎮',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 15),
              ),
            ),
          )
        else
          for (final g in groups) _GroupCard(group: g, onToast: onToast),
      ],
    );
  }

  // ── יצירת קבוצה: שם + בחירת חברים ─────────────────────────────────────────
  void _openCreateSheet(
      BuildContext context, WidgetRef ref, List<FriendModel>? friends) {
    if (friends == null) {
      onToast('רשימת החברים עוד נטענת — נסו שוב רגע');
      return;
    }
    if (friends.isEmpty) {
      onToast('קודם הוסיפו חברים (בטאב "הוסף חבר")');
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreateGroupSheet(friends: friends, onToast: onToast),
    );
  }
}

class CreateGroupSheet extends ConsumerStatefulWidget {
  final List<FriendModel> friends;
  final void Function(String) onToast;
  const CreateGroupSheet({super.key, required this.friends, required this.onToast});

  @override
  ConsumerState<CreateGroupSheet> createState() => CreateGroupSheetState();
}

class CreateGroupSheetState extends ConsumerState<CreateGroupSheet> {
  final _name = TextEditingController();
  final Set<String> _selected = {};
  bool _creating = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final me = ref.read(currentUserProvider).valueOrNull;
    if (me == null || _creating) return;
    final name = _name.text.trim();
    if (name.isEmpty) {
      widget.onToast('תנו שם לקבוצה');
      return;
    }
    if (_selected.isEmpty) {
      widget.onToast('בחרו לפחות חבר אחד');
      return;
    }
    setState(() => _creating = true);
    try {
      await ref.read(groupsServiceProvider).createGroup(
            name: name,
            myUid: me.id,
            myName: me.name,
            members: widget.friends
                .where((f) => _selected.contains(f.uid))
                .toList(),
          );
      if (mounted) Navigator.pop(context);
      widget.onToast('הקבוצה "$name" נוצרה 🎉');
    } catch (_) {
      widget.onToast('שגיאה ביצירת הקבוצה');
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 14,
          // גם המקלדת (viewInsets) וגם פס הניווט של אנדרואיד / ה-home
          // indicator של iOS (viewPadding) — אחרת כפתור "צור קבוצה" מוסתר.
          bottom: 16 +
              MediaQuery.of(context).viewInsets.bottom +
              MediaQuery.of(context).viewPadding.bottom,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFF0D1E30),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('קבוצה חדשה',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              maxLength: 20,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                counterText: '',
                hintText: 'שם הקבוצה (למשל: המשפחה 🏆)',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.white.withOpacity(0.06),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            const Text('מי בקבוצה?',
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final f in widget.friends)
                    CheckboxListTile(
                      value: _selected.contains(f.uid),
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      activeColor: const Color(0xFF34D399),
                      title: Text(f.name,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 15)),
                      onChanged: (v) => setState(() =>
                          v == true
                              ? _selected.add(f.uid)
                              : _selected.remove(f.uid)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: _creating ? null : _create,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF34D399),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(_creating ? 'יוצר…' : 'צור קבוצה',
                  style: const TextStyle(
                      color: Color(0xFF06281C),
                      fontWeight: FontWeight.w900,
                      fontSize: 15)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── כרטיס קבוצה ───────────────────────────────────────────────────────────────

class _GroupCard extends ConsumerWidget {
  final GroupModel group;
  final void Function(String) onToast;
  const _GroupCard({required this.group, required this.onToast});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider).valueOrNull;
    final standings = group.memberUids.toList()
      ..sort((a, b) => group.pointsOf(b).compareTo(group.pointsOf(a)));
    const medals = ['🥇', '🥈', '🥉'];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1E30),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1A6CB0).withOpacity(0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '👥 ${group.name}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w900),
                ),
              ),
              if (me != null)
                PopupMenuButton<String>(
                  color: const Color(0xFF13253C),
                  icon: const Icon(Icons.more_vert_rounded,
                      color: Colors.white54, size: 20),
                  onSelected: (v) => v == 'delete'
                      ? _confirmDelete(context, ref)
                      : _confirmLeave(context, ref, me.id),
                  itemBuilder: (_) => [
                    if (group.ownerUid == me.id)
                      const PopupMenuItem(
                          value: 'delete',
                          child: Text('מחק קבוצה',
                              style: TextStyle(color: Colors.white)))
                    else
                      const PopupMenuItem(
                          value: 'leave',
                          child: Text('עזוב קבוצה',
                              style: TextStyle(color: Colors.white))),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 6),
          // טבלת הניקוד המצטבר של הקבוצה
          for (var i = 0; i < standings.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    child: Text(i < medals.length ? medals[i] : '${i + 1}.',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13)),
                  ),
                  Expanded(
                    child: Text(
                      group.nameOf(standings[i]) +
                          (standings[i] == me?.id ? ' (אני)' : ''),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: standings[i] == me?.id
                            ? const Color(0xFFFFE082)
                            : Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text('${group.pointsOf(standings[i])}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: me == null
                      ? null
                      : () => _openPlaySheet(context, ref),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF34D399),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.sports_esports_rounded,
                      color: Color(0xFF06281C), size: 20),
                  label: const Text('שחק עכשיו',
                      style: TextStyle(
                          color: Color(0xFF06281C),
                          fontWeight: FontWeight.w900)),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed:
                    me == null ? null : () => _openChat(context, ref, me.id),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                      color: const Color(0xFF4A9EFF).withOpacity(0.6)),
                  padding: const EdgeInsets.symmetric(
                      vertical: 10, horizontal: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Text('💬', style: TextStyle(fontSize: 16)),
                label: const Text('צ\'אט',
                    style: TextStyle(
                        color: Color(0xFF4A9EFF),
                        fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── משחק לכל הקבוצה בלחיצה: בחירת סוג משחק → חדר + הזמנות פוש לכולם ───────
  void _openPlaySheet(BuildContext context, WidgetRef ref) {
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0D1E30),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('באיזה משחק נשחק?',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900)),
              ),
              for (final opt in const [
                ('🏞️', 'זיהוי מקומות', Difficulty.easy, ''),
                ('🐢', 'חי צומח דומם', Difficulty.giant, ''),
                ('🧩', 'זהו את הפתגם', Difficulty.giant,
                    GameCategories.proverbs),
              ])
                ListTile(
                  leading: Text(opt.$1, style: const TextStyle(fontSize: 24)),
                  title: Text(opt.$2,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w800)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _openMemberPicker(context, ref,
                        difficulty: opt.$3, category: opt.$4);
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  /// את מי להזמין? כולם מסומנים כברירת מחדל — אפשר להוריד מוזמנים ספציפיים.
  void _openMemberPicker(
    BuildContext context,
    WidgetRef ref, {
    required Difficulty difficulty,
    required String category,
  }) {
    final me = ref.read(currentUserProvider).valueOrNull;
    if (me == null) return;
    final others =
        group.memberUids.where((u) => u != me.id).toList(growable: false);
    if (others.isEmpty) {
      onToast('אין עוד חברים בקבוצה');
      return;
    }
    final selected = {...others};
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0D1E30),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text('את מי להזמין?',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w900)),
                      ),
                      TextButton(
                        onPressed: () => setSheet(() =>
                            selected.length == others.length
                                ? selected.clear()
                                : selected.addAll(others)),
                        child: Text(
                            selected.length == others.length
                                ? 'נקה הכל'
                                : 'בחר הכל',
                            style: const TextStyle(
                                color: Color(0xFF4A9EFF),
                                fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 260),
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final uid in others)
                          CheckboxListTile(
                            value: selected.contains(uid),
                            dense: true,
                            controlAffinity: ListTileControlAffinity.leading,
                            activeColor: const Color(0xFF34D399),
                            title: Text(group.nameOf(uid),
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 15)),
                            onChanged: (v) => setSheet(() => v == true
                                ? selected.add(uid)
                                : selected.remove(uid)),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  FilledButton(
                    onPressed: selected.isEmpty
                        ? null
                        : () {
                            Navigator.pop(ctx);
                            _startGroupGame(context, ref,
                                difficulty: difficulty,
                                category: category,
                                inviteUids: selected.toList());
                          },
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF34D399),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                        selected.length == others.length
                            ? 'הזמן את כולם (${selected.length}) 🎮'
                            : 'הזמן ${selected.length} נבחרים 🎮',
                        style: const TextStyle(
                            color: Color(0xFF06281C),
                            fontWeight: FontWeight.w900,
                            fontSize: 15)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _startGroupGame(
    BuildContext context,
    WidgetRef ref, {
    required Difficulty difficulty,
    required String category,
    required List<String> inviteUids,
  }) async {
    final me = ref.read(currentUserProvider).valueOrNull;
    if (me == null) return;
    onToast('פותח חדר ושולח הזמנות… 🎮');
    try {
      final room = await ref.read(roomServiceProvider).createRoom(
            hostId: me.id,
            hostName: me.name,
            hostPhotoUrl: me.photoUrl,
            entryFee: 0, // friends games are free
            difficulty: difficulty,
            category: category.isEmpty
                ? GameCategories.israelPlaces
                : category,
            groupId: group.id,
          );
      await ref.read(groupsServiceProvider).inviteGroupToRoom(
            group: group,
            room: room,
            myUid: me.id,
            myName: me.name,
            toUids: inviteUids,
          );
      ref.read(currentRoomIdProvider.notifier).state = room.id;
      if (context.mounted) context.go('/lobby/${room.id}');
    } catch (_) {
      onToast('שגיאה בפתיחת המשחק');
    }
  }

  void _openChat(BuildContext context, WidgetRef ref, String myUid) {
    final myName = ref.read(currentUserProvider).valueOrNull?.name ?? 'אני';
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChatSheet(
        stream: ref.read(groupsServiceProvider).messages(group.id),
        myUid: myUid,
        onSend: (text) => ref.read(groupsServiceProvider).sendMessage(
              groupId: group.id,
              senderUid: myUid,
              senderName: myName,
              text: text,
            ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await _confirm(context, 'למחוק את הקבוצה "${group.name}"?');
    if (ok == true) {
      await ref.read(groupsServiceProvider).deleteGroup(group.id);
      onToast('הקבוצה נמחקה');
    }
  }

  Future<void> _confirmLeave(
      BuildContext context, WidgetRef ref, String myUid) async {
    final ok = await _confirm(context, 'לעזוב את הקבוצה "${group.name}"?');
    if (ok == true) {
      await ref
          .read(groupsServiceProvider)
          .leaveGroup(groupId: group.id, myUid: myUid);
      onToast('עזבת את הקבוצה');
    }
  }

  Future<bool?> _confirm(BuildContext context, String message) =>
      showDialog<bool>(
        context: context,
        builder: (ctx) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: const Color(0xFF0D1E30),
            content: Text(message,
                style: const TextStyle(color: Colors.white, fontSize: 15)),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('ביטול',
                      style: TextStyle(color: Colors.white54))),
              TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('אישור',
                      style: TextStyle(
                          color: Color(0xFFFF6B6B),
                          fontWeight: FontWeight.w800))),
            ],
          ),
        ),
      );
}
