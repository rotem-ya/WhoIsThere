import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/player_rank.dart';
import '../../core/utils/app_router.dart';
import '../../models/user_model.dart';
import '../../providers/providers.dart';
import '../../services/settings_service.dart';
import '../../services/sfx_service.dart';

/// Global celebration when the player crosses into a new rank tier. Watches the
/// user's lifetime `totalPoints`; when the derived [PlayerRank] increases, it
/// shows a one-off animated badge in the rank's color, with a jingle and a
/// haptic.
///
/// The first user emission only seeds the baseline (no celebration on launch).
/// A rank-up detected during gameplay is held until the player lands on a
/// non-gameplay screen, so it never covers the board or the win view.
class RankUpBanner extends ConsumerStatefulWidget {
  const RankUpBanner({super.key});

  @override
  ConsumerState<RankUpBanner> createState() => _RankUpBannerState();
}

class _RankUpBannerState extends ConsumerState<RankUpBanner> {
  PlayerRank? _lastRank; // baseline; null until the first user load
  PlayerRank? _celebrating; // the rank being celebrated (queued or showing)
  bool _shown = false; // has the current celebration actually appeared yet?
  Timer? _dismiss;

  static bool _suppressedPath(String path) =>
      path == '/' ||
      path == '/auth' ||
      path.startsWith('/splash') ||
      path.startsWith('/game/') ||
      path.startsWith('/letters/') ||
      path.startsWith('/lobby/') ||
      path.startsWith('/vote-') ||
      path.startsWith('/win/') ||
      path.startsWith('/finding-players/');

  @override
  void dispose() {
    _dismiss?.cancel();
    super.dispose();
  }

  void _onUser(
      AsyncValue<UserModel?>? prev, AsyncValue<UserModel?> next) {
    final user = next.valueOrNull;
    if (user == null) return;
    final rank = PlayerRankX.fromPoints(user.totalPoints);
    if (_lastRank == null) {
      _lastRank = rank; // seed baseline — never celebrate the first load
      return;
    }
    if (rank.index > _lastRank!.index) {
      _lastRank = rank;
      setState(() {
        _celebrating = rank;
        _shown = false;
      });
    } else if (rank.index < _lastRank!.index) {
      _lastRank = rank; // shouldn't happen, but keep the baseline honest
    }
  }

  void _clear() {
    _dismiss?.cancel();
    if (mounted) {
      setState(() {
        _celebrating = null;
        _shown = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<UserModel?>>(currentUserProvider, _onUser);

    final celebrating = _celebrating;
    if (celebrating == null) return const SizedBox.shrink();

    final router = ref.watch(routerProvider);
    return AnimatedBuilder(
      animation: router.routeInformationProvider,
      builder: (context, _) {
        final path = router.routeInformationProvider.value.uri.path;
        if (_suppressedPath(path)) return const SizedBox.shrink();

        // First time this celebration reaches a visible screen: fire the
        // jingle + haptic and arm the auto-dismiss.
        if (!_shown) {
          _shown = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            SfxService.instance.rankUp();
            if (SettingsService.instance.vibrationEnabled) {
              HapticFeedback.heavyImpact();
            }
          });
          _dismiss?.cancel();
          _dismiss =
              Timer(const Duration(milliseconds: 4500), _clear);
        }

        return SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: _RankUpCard(rank: celebrating, onDismiss: _clear),
          ),
        );
      },
    );
  }
}

class _RankUpCard extends StatelessWidget {
  final PlayerRank rank;
  final VoidCallback onDismiss;
  const _RankUpCard({required this.rank, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final color = rank.color;
    return TweenAnimationBuilder<double>(
      key: ValueKey(rank),
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutBack,
      builder: (context, t, child) {
        final tt = t.clamp(0.0, 1.0);
        return Transform.translate(
          offset: Offset(0, -30 * (1 - tt)),
          child: Transform.scale(
            scale: 0.85 + 0.15 * tt,
            child: Opacity(opacity: tt, child: child),
          ),
        );
      },
      child: GestureDetector(
        onTap: onDismiss,
        child: Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF07101F), color.withOpacity(0.28)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: color.withOpacity(0.75), width: 1.4),
              boxShadow: [
                BoxShadow(
                    color: color.withOpacity(0.35),
                    blurRadius: 26,
                    spreadRadius: 1),
                BoxShadow(
                    color: Colors.black.withOpacity(0.45),
                    blurRadius: 14,
                    offset: const Offset(0, 6)),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(rank.emoji, style: const TextStyle(fontSize: 30)),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'עלית לדרגה חדשה!',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      rank.label,
                      style: TextStyle(
                        color: color,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
