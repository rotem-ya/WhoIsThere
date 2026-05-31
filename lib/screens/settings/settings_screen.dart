import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/build_info.dart';
import '../../core/ui/app_scaffold.dart';
import '../../core/ui/app_spacing.dart';
import '../../providers/providers.dart';
import '../../services/qa_logger_service.dart';
import '../../widgets/common/app_header.dart';
import '../game/game_board_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return AppScaffold(
      backgroundGradient: AppColors.pageBackground,
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
                        : AppColors.primary,
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
                      _isMuted ? Colors.white30 : AppColors.primary,
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
                  : AppColors.primary,
              inactiveTrackColor: Colors.white12,
              thumbColor: _isMuted
                  ? Colors.white30
                  : AppColors.primary,
              overlayColor: AppColors.primary.withOpacity(0.12),
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

// ── Vibration section (toggle + hidden 10-tap QA trigger on icon) ────────────

class _VibrationSection extends StatefulWidget {
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _VibrationSection({required this.enabled, required this.onChanged});

  @override
  State<_VibrationSection> createState() => _VibrationSectionState();
}

class _VibrationSectionState extends State<_VibrationSection> {
  int _tapCount = 0;
  DateTime? _lastTap;

  void _onIconTap() {
    final now = DateTime.now();
    if (_lastTap != null && now.difference(_lastTap!) > const Duration(seconds: 3)) {
      _tapCount = 0;
    }
    _lastTap = now;
    _tapCount++;
    if (_tapCount >= 10) {
      _tapCount = 0;
      _showQaSheet();
    }
  }

  void _showQaSheet() {
    final logs = QaLoggerService.instance.exportText;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Directionality(
        textDirection: TextDirection.ltr,
        child: DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (ctx, scrollCtrl) => Container(
            decoration: const BoxDecoration(
              color: Color(0xFF060F1C),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 38, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      const Text(
                        'QA Logs',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        kBuildLabel,
                        style: const TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: () async {
                          await QaLoggerService.instance.copyToClipboard();
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                              content: Text(
                                'הועתקו ${QaLoggerService.instance.eventCount} אירועים',
                                style: const TextStyle(color: Colors.white),
                              ),
                              backgroundColor: Colors.green.shade800,
                              duration: const Duration(seconds: 2),
                            ));
                          }
                        },
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        label: const Text('העתק'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white12, height: 1),
                Expanded(
                  child: ListView(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.all(12),
                    children: [
                      SelectableText(
                        logs,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10.5,
                          fontFamily: 'monospace',
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsCard(
      child: Row(
        children: [
          GestureDetector(
            onTap: _onIconTap,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                widget.enabled
                    ? Icons.vibration_rounded
                    : Icons.phonelink_erase_rounded,
                color: widget.enabled ? AppColors.primary : Colors.white30,
                size: 22,
              ),
            ),
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
            value: widget.enabled,
            onChanged: (v) {
              if (v) HapticFeedback.mediumImpact();
              widget.onChanged(v);
            },
            activeColor: AppColors.primary,
            activeTrackColor: AppColors.primary.withOpacity(0.35),
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
        color: const Color(0xFF0A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.18),
        ),
      ),
      child: child,
    );
  }
}
