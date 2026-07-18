import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/candy_theme.dart';
import '../../core/ui/app_scaffold.dart';
import '../../core/ui/app_spacing.dart';
import '../../providers/providers.dart';
import '../../widgets/common/app_header.dart';
import '../game/game_board_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return AppScaffold(
      backgroundGradient: Candy.bg,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          AppHeader(
            title: 'הגדרות',
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.maybePop(context);
            },
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: Column(
              children: [
                _SoundSection(
                  icon: Icons.music_note_rounded,
                  label: 'מוזיקת רקע',
                  volume: settings.musicVolume,
                  onChanged: (v) =>
                      ref.read(settingsProvider.notifier).setMusicVolume(v),
                  onChangeEnd: (v) {
                    HapticFeedback.lightImpact();
                    GameBoardScreen.applyLiveMusicScale(v);
                  },
                  onMuteToggle: () =>
                      ref.read(settingsProvider.notifier).toggleMusicMute(),
                ),
                const SizedBox(height: AppSpacing.md),
                _SoundSection(
                  icon: Icons.volume_up_rounded,
                  label: 'אפקטים קוליים',
                  volume: settings.sfxVolume,
                  onChanged: (v) =>
                      ref.read(settingsProvider.notifier).setSfxVolume(v),
                  onChangeEnd: (v) {
                    HapticFeedback.lightImpact();
                    GameBoardScreen.playSfxPreview(v);
                  },
                  onMuteToggle: () =>
                      ref.read(settingsProvider.notifier).toggleSfxMute(),
                ),
                const SizedBox(height: AppSpacing.md),
                _VibrationSection(
                  enabled: settings.vibrationEnabled,
                  onChanged: (v) => ref
                      .read(settingsProvider.notifier)
                      .setVibrationEnabled(v),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sound section (slider + mute icon) ───────────────────────────────────────

class _SoundSection extends StatelessWidget {
  final IconData icon;
  final String label;
  final double volume;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;
  final VoidCallback onMuteToggle;

  const _SoundSection({
    required this.icon,
    required this.label,
    required this.volume,
    required this.onChanged,
    this.onChangeEnd,
    required this.onMuteToggle,
  });

  bool get _isMuted => volume == 0;

  @override
  Widget build(BuildContext context) {
    final pct = (volume * 100).round();

    return _SettingsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onMuteToggle();
                },
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: Icon(
                    _isMuted
                        ? (_getOffIcon(icon))
                        : icon,
                    key: ValueKey(_isMuted),
                    color: _isMuted
                        ? Colors.white30
                        : Candy.gold,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              Text(
                _isMuted ? 'מושתק' : '$pct%',
                style: TextStyle(
                  color:
                      _isMuted ? Colors.white30 : Candy.gold,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: _isMuted
                  ? Colors.white24
                  : Candy.gold,
              inactiveTrackColor: Colors.white12,
              thumbColor: _isMuted
                  ? Colors.white30
                  : Candy.gold,
              overlayColor: Candy.gold.withOpacity(0.12),
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            ),
            child: Slider(
              value: volume,
              min: 0,
              max: 1,
              divisions: 20,
              onChanged: onChanged,
              onChangeEnd: onChangeEnd,
            ),
          ),
        ],
      ),
    );
  }

  static IconData _getOffIcon(IconData on) {
    if (on == Icons.music_note_rounded) return Icons.music_off_rounded;
    return Icons.volume_off_rounded;
  }
}

// ── Vibration section (toggle) ────────────────────────────────────────────────

class _VibrationSection extends StatelessWidget {
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _VibrationSection({required this.enabled, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return _SettingsCard(
      child: Row(
        children: [
          Icon(
            enabled ? Icons.vibration_rounded : Icons.phonelink_erase_rounded,
            color: enabled ? Candy.gold : Colors.white30,
            size: 22,
          ),
          const SizedBox(width: AppSpacing.sm),
          const Expanded(
            child: Text(
              'רטט',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
          Switch(
            value: enabled,
            onChanged: (v) {
              if (v) HapticFeedback.mediumImpact();
              onChanged(v);
            },
            activeColor: Candy.gold,
            activeTrackColor: Candy.gold.withOpacity(0.35),
            inactiveThumbColor: Colors.white30,
            inactiveTrackColor: Colors.white12,
          ),
        ],
      ),
    );
  }
}

// ── Shared card wrapper ───────────────────────────────────────────────────────

class _SettingsCard extends StatelessWidget {
  final Widget child;
  const _SettingsCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: Candy.surfaceLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Candy.gold.withOpacity(0.18),
        ),
      ),
      child: child,
    );
  }
}
