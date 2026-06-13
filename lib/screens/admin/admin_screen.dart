import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/card_skin.dart';
import '../../models/user_model.dart';
import '../../providers/providers.dart';

/// Admin panel — look up a user by their login email and grant coins, skins,
/// or action cards. Gated by [isAdminProvider] (route is only shown to admins,
/// and Firestore rules enforce the same on the server).
class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> {
  final _emailCtrl = TextEditingController();
  final _coinsCtrl = TextEditingController();

  bool _busy = false;
  String? _error;
  UserModel? _user;
  int _coins = 0;
  String _selectedSkin = kAvailableCardSkins.first.id;

  static const _navy = Color(0xFF0D1E30);
  static const _card = Color(0xFF12283F);
  static const _accent = Color(0xFF20A8E0);

  @override
  void dispose() {
    _emailCtrl.dispose();
    _coinsCtrl.dispose();
    super.dispose();
  }

  Future<void> _lookup() async {
    FocusScope.of(context).unfocus();
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
      _user = null;
    });
    try {
      final user = await ref.read(adminServiceProvider).findUserByEmail(email);
      if (user == null) {
        setState(() => _error = 'לא נמצא משתמש עם המייל הזה');
      } else {
        final wallet = await ref.read(adminServiceProvider).getWallet(user.id);
        setState(() {
          _user = user;
          _coins = wallet.coins;
        });
      }
    } catch (e) {
      setState(() => _error = 'שגיאה: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refreshWallet() async {
    final u = _user;
    if (u == null) return;
    final wallet = await ref.read(adminServiceProvider).getWallet(u.id);
    if (mounted) setState(() => _coins = wallet.coins);
  }

  Future<void> _run(Future<void> Function() action, String okMsg) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(okMsg)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('שגיאה: $e'), backgroundColor: Colors.red.shade800),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _grantCoins(int amount) async {
    final u = _user;
    if (u == null) return;
    final adminEmail =
        ref.read(firebaseUserProvider).valueOrNull?.email ?? 'admin';
    await _run(() async {
      await ref
          .read(adminServiceProvider)
          .grantCoins(uid: u.id, amount: amount, adminEmail: adminEmail);
      await _refreshWallet();
    }, 'הוענקו $amount מטבעות');
  }

  Future<void> _grantSkin() async {
    final u = _user;
    if (u == null) return;
    await _run(
      () => ref
          .read(adminServiceProvider)
          .grantSkin(uid: u.id, skinId: _selectedSkin),
      'הוענק סקין: $_selectedSkin',
    );
  }

  Future<void> _grantCard(String field, int count, String label) async {
    final u = _user;
    if (u == null) return;
    await _run(
      () => ref
          .read(adminServiceProvider)
          .grantCard(uid: u.id, field: field, count: count),
      'הוענק $label ×$count',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _navy,
        appBar: AppBar(
          backgroundColor: _navy,
          foregroundColor: Colors.white,
          title: const Text('ניהול משתמשים',
              style: TextStyle(fontWeight: FontWeight.w900)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/home');
              }
            },
          ),
        ),
        body: AbsorbPointer(
          absorbing: _busy,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _lookupSection(),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style: TextStyle(color: Colors.red.shade300, fontSize: 14)),
              ],
              if (_user != null) ...[
                const SizedBox(height: 16),
                _userCard(),
                const SizedBox(height: 16),
                _coinsSection(),
                const SizedBox(height: 16),
                _skinSection(),
                const SizedBox(height: 16),
                _cardsSection(),
              ],
              if (_busy) ...[
                const SizedBox(height: 24),
                const Center(
                    child: CircularProgressIndicator(color: _accent)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _section({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _lookupSection() {
    return _section(
      title: '🔍 חיפוש משתמש לפי מייל',
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              textDirection: TextDirection.ltr,
              style: const TextStyle(color: Colors.white),
              onSubmitted: (_) => _lookup(),
              decoration: InputDecoration(
                hintText: 'user@example.com',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.black.withOpacity(0.25),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _lookup,
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            ),
            child: const Text('חפש', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  Widget _userCard() {
    final u = _user!;
    return _section(
      title: '👤 ${u.name}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _kv('מייל', u.email ?? '—'),
          _kv('UID', u.id),
          _kv('מטבעות', '$_coins 🪙'),
          _kv('נקודות', '${u.totalPoints}'),
          _kv('כרטיסים',
              'עצור ${u.stunCardCount} · חסימה5 ${u.guessBlock5Count} · חסימה10 ${u.guessBlock10Count} · החשכה ${u.blackoutCardCount}'),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(k,
                style: const TextStyle(color: Colors.white54, fontSize: 13)),
          ),
          Expanded(
            child: Text(v,
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.right,
                style: const TextStyle(
                    color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _coinsSection() {
    return _section(
      title: '🪙 הוספת מטבעות',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final amt in [100, 500, 1000, 5000])
                _chip('+$amt', () => _grantCoins(amt)),
              _chip('-100', () => _grantCoins(-100), danger: true),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _coinsCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'כמות מותאמת',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.black.withOpacity(0.25),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  final amt = int.tryParse(_coinsCtrl.text.trim());
                  if (amt != null && amt != 0) {
                    _coinsCtrl.clear();
                    _grantCoins(amt);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                ),
                child: const Text('הוסף',
                    style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _skinSection() {
    return _section(
      title: '🎨 הענקת סקין',
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _selectedSkin,
              isExpanded: true,
              dropdownColor: _card,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.black.withOpacity(0.25),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              ),
              items: [
                for (final s in kAvailableCardSkins)
                  DropdownMenuItem(
                    value: s.id,
                    child: Text('${s.name} (${s.id})',
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _selectedSkin = v);
              },
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _grantSkin,
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            ),
            child:
                const Text('הענק', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  Widget _cardsSection() {
    return _section(
      title: '🃏 הענקת כרטיסים',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _chip('עצור +1', () => _grantCard('stunCardCount', 1, 'כרטיס עצור')),
          _chip('חסימה 5s +1',
              () => _grantCard('guessBlock5Count', 1, 'חסימת 5 שניות')),
          _chip('חסימה 10s +1',
              () => _grantCard('guessBlock10Count', 1, 'חסימת 10 שניות')),
          _chip('החשכה +1',
              () => _grantCard('blackoutCardCount', 1, 'החשכה')),
        ],
      ),
    );
  }

  Widget _chip(String label, VoidCallback onTap, {bool danger = false}) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: (danger ? Colors.red : _accent).withOpacity(0.18),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: (danger ? Colors.red : _accent).withOpacity(0.5)),
        ),
        child: Text(label,
            style: TextStyle(
                color: danger ? Colors.red.shade200 : Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800)),
      ),
    );
  }
}
