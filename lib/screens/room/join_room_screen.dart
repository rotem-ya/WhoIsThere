import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/candy_theme.dart';
import '../../core/constants/game_constants.dart';
import '../../core/ui/app_scaffold.dart';
import '../../core/ui/app_spacing.dart';
import '../../core/ui/app_text_styles.dart';
import '../../providers/providers.dart';
import '../../services/qa_logger_service.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_feedback.dart';
import '../../widgets/common/app_header.dart';

class JoinRoomScreen extends ConsumerStatefulWidget {
  final String? initialCode;
  const JoinRoomScreen({super.key, this.initialCode});

  @override
  ConsumerState<JoinRoomScreen> createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends ConsumerState<JoinRoomScreen> {
  final _codeController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    QaLoggerService.instance.log('ROOM', 'JOIN_ROOM_SCREEN_OPENED initialCode=${widget.initialCode ?? 'none'}');
    final raw = widget.initialCode;
    if (raw != null) {
      final code = raw.trim().toUpperCase();
      if (code.length == 6 && RegExp(r'^[A-Z0-9]{6}$').hasMatch(code)) {
        _codeController.text = code;
      }
      // Clear the provider regardless — it has been consumed
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(pendingJoinCodeProvider.notifier).state = null;
      });
    }
  }

  Future<void> _joinRoom() async {
    final raw = _codeController.text.trim();
    final code = raw.toUpperCase();
    if (code.length != 6) {
      AppFeedback.error();
      setState(() => _errorMessage = 'נא להזין קוד בן 6 תווים');
      return;
    }

    QaLoggerService.instance.log('ROOM', 'JOIN_ROOM_ATTEMPT raw=$raw code=$code');
    AppFeedback.confirm();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await ref.read(currentUserProvider.future);
      if (user == null) return;

      // Check for active-game rejoin before the standard waiting-room join path
      final found = await ref.read(roomServiceProvider).findRoomByCode(code);
      if (found != null && found.phase == GamePhase.playing) {
        if (found.players.containsKey(user.id)) {
          final shortId = found.id.substring(0, found.id.length.clamp(0, 6));
          QaLoggerService.instance.log('ROOM',
              'JOIN_ROOM_REJOIN_ACTIVE_ALLOWED code=$code roomId=$shortId uid=${user.id}');
          QaLoggerService.instance.log('GAME',
              'GAME_REJOIN_ACTIVE_ROOM roomId=$shortId phase=playing turnPhase=${found.turnPhase.name}');
          ref.read(currentRoomIdProvider.notifier).state = found.id;
          if (mounted) context.go('/game/${found.id}');
        } else {
          AppFeedback.error();
          QaLoggerService.instance.log('ROOM',
              'JOIN_ROOM_REJOIN_ACTIVE_DENIED_NOT_PLAYER code=$code uid=${user.id}');
          setState(() => _errorMessage = 'המשחק כבר התחיל');
        }
        return;
      }

      final room = await ref.read(roomServiceProvider).joinRoom(
            code: code,
            userId: user.id,
            userName: user.name,
            userPhotoUrl: user.photoUrl,
          );

      if (room == null) {
        AppFeedback.error();
        QaLoggerService.instance.log('ROOM', 'JOIN_ROOM_ERROR code=$code reason=not_found_or_started');
        setState(() => _errorMessage = 'החדר לא נמצא או כבר התחיל');
        return;
      }

      final shortId = room.id.substring(0, room.id.length.clamp(0, 6));
      QaLoggerService.instance.log('ROOM', 'JOIN_ROOM_SUCCESS code=${room.code} id=$shortId');
      ref.read(currentRoomIdProvider.notifier).state = room.id;
      if (mounted) context.go('/lobby/${room.id}');
    } catch (e) {
      final msg = e.toString();
      QaLoggerService.instance.log(
          'ROOM', 'JOIN_ROOM_ERROR ${msg.length > 80 ? msg.substring(0, 80) : msg}');
      setState(() => _errorMessage = 'ההצטרפות נכשלה: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pasteCode() async {
    HapticFeedback.lightImpact();
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final raw = (data?.text ?? '').trim();
    if (raw.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('לא נמצא קוד להדבקה')),
        );
      }
      return;
    }
    // Extract code from full deep link URI if the user copied the whole line
    String code;
    final uri = Uri.tryParse(raw);
    if (uri != null && uri.queryParameters.containsKey('code')) {
      code = uri.queryParameters['code']!.trim().toUpperCase();
    } else {
      code = raw.toUpperCase();
    }
    setState(() {
      _codeController.text = code.length > 6 ? code.substring(0, 6) : code;
      _codeController.selection = TextSelection.collapsed(
        offset: _codeController.text.length,
      );
      _errorMessage = null;
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const borderRadius = BorderRadius.all(Radius.circular(12));
    const codeTextStyle = TextStyle(
      fontSize: 34,
      fontWeight: FontWeight.w900,
      letterSpacing: 8,
      color: Colors.white,
    );

    return AppScaffold(
      backgroundGradient: Candy.bg,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          AppHeader(
            title: 'הצטרפות',
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () {
                HapticFeedback.lightImpact();
                context.pop();
              },
            ),
          ),
          Expanded(
            child: Center(
              child: AppCard(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('הכנס קוד חדר', style: AppTextStyles.titleDark),
                    const SizedBox(height: AppSpacing.sm),
                    Text('קוד בן 6 תווים מהמארח',
                        style: AppTextStyles.subtitleDark),
                    const SizedBox(height: AppSpacing.lg),
                    TextField(
                      controller: _codeController,
                      textAlign: TextAlign.center,
                      textCapitalization: TextCapitalization.characters,
                      maxLength: 6,
                      style: codeTextStyle,
                      onChanged: (_) => setState(() => _errorMessage = null),
                      decoration: InputDecoration(
                        hintText: 'XXXXXX',
                        hintStyle: codeTextStyle.copyWith(
                          color: Colors.white.withOpacity(0.25),
                        ),
                        counterText: '',
                        errorText: _errorMessage,
                        errorMaxLines: 2,
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.06),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: borderRadius,
                          borderSide: BorderSide(
                            color: Colors.white.withOpacity(0.30),
                            width: 0.8,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: borderRadius,
                          borderSide: BorderSide(
                            color: Colors.white.withOpacity(0.20),
                            width: 0.8,
                          ),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderRadius: borderRadius,
                          borderSide: BorderSide(
                            color: Candy.teal,
                            width: 2,
                          ),
                        ),
                        errorBorder: const OutlineInputBorder(
                          borderRadius: borderRadius,
                          borderSide: BorderSide(color: Colors.red, width: 1),
                        ),
                        focusedErrorBorder: const OutlineInputBorder(
                          borderRadius: borderRadius,
                          borderSide: BorderSide(color: Colors.red, width: 2),
                        ),
                      ),
                      onSubmitted: (_) => _joinRoom(),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextButton.icon(
                      onPressed: _pasteCode,
                      icon: const Icon(Icons.content_paste_rounded, size: 18),
                      label: const Text('הדבק קוד'),
                      style: TextButton.styleFrom(
                        foregroundColor: Candy.teal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          _isLoading
              ? const CircularProgressIndicator(color: Candy.teal)
              : AppButton(
                  label: 'הצטרף למשחק',
                  icon: Icons.login_rounded,
                  onPressed: _joinRoom,
                ),
        ],
      ),
    );
  }
}
