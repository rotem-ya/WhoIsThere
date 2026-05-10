import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/game_constants.dart';
import '../../core/theme/app_styles.dart';
import '../../providers/providers.dart';
import '../../models/player_model.dart';
import '../../widgets/common/app_feedback.dart';
import '../../widgets/common/player_avatar.dart';

class LobbyScreen extends ConsumerStatefulWidget {
  final String roomId;
  const LobbyScreen({super.key, required this.roomId});

  @override
  ConsumerState<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends ConsumerState<LobbyScreen> {
  bool _isStarting = false;
  bool _codeCopied = false;

  Future<void> _copyCode(String code) async {
    if (_codeCopied) return;
    AppFeedback.success();
    await Clipboard.setData(ClipboardData(text: code));
    setState(() => _codeCopied = true);
    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted) setState(() => _codeCopied = false);
  }

  void _shareToWhatsApp(String code) {
    Share.share(
      'בואו לגלות מה בתמונה 📸\n\nקוד חדר:\n$code\n\nהצטרפו דרך האפליקציה והזינו את הקוד.',
    );
  }
