import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/display_name_sanitizer.dart';
import '../../../providers/providers.dart';
import '../../../services/qa_logger_service.dart';

class ClaudeAuthScreen extends ConsumerStatefulWidget {
  const ClaudeAuthScreen({super.key});

  @override
  ConsumerState<ClaudeAuthScreen> createState() => _ClaudeAuthScreenState();
}

class _ClaudeAuthScreenState extends ConsumerState<ClaudeAuthScreen> {
  static const _navy = Color(0xFF050A14);
  static const _steelLight = Color(0xFF1A2033);
  static const _cyan = Color(0xFF5DD9E8);
  static const _gold = Color(0xFFE8B923);
  static const _goldDark = Color(0xFFC4872E);

  final _nameController = TextEditingController();
  bool _isLoading = false;
  String? _nameError;

  @override
  void initState() {
    super.initState();
    QaLoggerService.instance.log('AUTH', 'CLAUDE_DESIGN_OPENED');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String? _resolvedName() {
    final raw = _nameController.text.trim();
    if (raw.isEmpty) return null;
    final sanitized = DisplayNameSanitizer.sanitize(raw);
    if (sanitized == null) {
      setState(() => _nameError = '2–16 תווים, אותיות ומספרים בלבד');
      return 'invalid';
    }
    return sanitized;
  }

  Future<void> _runAuth(
    Future<dynamic> Function() action, {
    String logTag = 'AUTH',
  }) async {
    setState(() => _isLoading = true);
    try {
      final user = await action();
      if (user != null && mounted) {
        QaLoggerService.instance.log('AUTH', '${logTag}_SUCCESS');
        context.go('/home');
      }
    } catch (e) {
      final msg = e.toString();
      QaLoggerService.instance.log(
          'AUTH', 'AUTH_ERROR [$logTag] ${msg.length > 80 ? msg.substring(0, 80) : msg}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ההתחברות נכשלה: ${e.toString()}'),
            backgroundColor: Colors.red.shade900,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInAnonymously() async {
    final name = _resolvedName();
    if (name == 'invalid') return;
    if (name != null) QaLoggerService.instance.log('AUTH', 'AUTH_NAME_PRESENT name=$name');
    QaLoggerService.instance.log('AUTH', 'CLAUDE_ANON_ATTEMPT');
    await _runAuth(
      () => ref.read(authServiceProvider).signInAnonymously(preferredName: name),
      logTag: 'CLAUDE_ANON',
    );
  }

  Future<void> _signInWithGoogle() async {
    QaLoggerService.instance.log('AUTH', 'CLAUDE_GOOGLE_ATTEMPT');
    await _runAuth(
      () => ref.read(authServiceProvider).signInWithGoogle(),
      logTag: 'CLAUDE_GOOGLE',
    );
  }

  Future<void> _signInWithApple() async {
    QaLoggerService.instance.log('AUTH', 'CLAUDE_APPLE_ATTEMPT');
    await _runAuth(
      () => ref.read(authServiceProvider).signInWithApple(),
      logTag: 'CLAUDE_APPLE',
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: _navy,
          resizeToAvoidBottomInset: true,
          body: Stack(
            children: [
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF0D1219),
                      Color(0xFF050A14),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: -80,
                right: -80,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF5DD9E8).withOpacity(0.06),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: MediaQuery.of(context).size.height -
                          MediaQuery.of(context).padding.top -
                          MediaQuery.of(context).padding.bottom,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 28),
                          const _ClaudeRevealGrid(),
                          const SizedBox(height: 40),
                          const _ClaudeTitleSection(),
                          const SizedBox(height: 56),
                          _ClaudeNameInput(
                            controller: _nameController,
                            hasError: _nameError != null,
                            onChanged: (_) => setState(() => _nameError = null),
                          ),
                          if (_nameError != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              _nameError!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.red.shade300,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ] else ...[
                            const SizedBox(height: 8),
                            Text(
                              'אתה יכול לשחק כאורח בלי להכניס שם',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.55),
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                          const SizedBox(height: 56),
                          if (_isLoading)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.only(bottom: 16),
                                child: CircularProgressIndicator(
                                  color: _gold,
                                  strokeWidth: 2.4,
                                ),
                              ),
                            )
                          else ...[
                            _ClaudeButton(
                              label: 'התחל לשחק',
                              isPrimary: true,
                              onTap: _signInAnonymously,
                            ),
                            const SizedBox(height: 14),
                            _ClaudeButton(
                              label: 'המשך עם Google',
                              isPrimary: false,
                              onTap: _signInWithGoogle,
                            ),
                            if (Platform.isIOS) ...[
                              const SizedBox(height: 14),
                              _ClaudeButton(
                                label: 'המשך עם Apple',
                                isPrimary: false,
                                onTap: _signInWithApple,
                              ),
                            ],
                          ],
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 16,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4AF37).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: const Color(0xFFD4AF37).withOpacity(0.35),
                      width: 0.9,
                    ),
                  ),
                  child: const Text(
                    'CLAUDE',
                    style: TextStyle(
                      color: Color(0xFFE8B923),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.7,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClaudeRevealGrid extends StatelessWidget {
  const _ClaudeRevealGrid();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 150,
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: 9,
        itemBuilder: (context, index) {
          final revealed = [1, 3, 4, 5, 7].contains(index);
          return _ClaudeTile(revealed: revealed, index: index);
        },
      ),
    );
  }
}

class _ClaudeTile extends StatelessWidget {
  final bool revealed;
  final int index;

  const _ClaudeTile({required this.revealed, required this.index});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: revealed
            ? const Color(0xFF1F2A3A).withOpacity(0.9)
            : const Color(0xFF0F1620),
        border: Border.all(
          color: revealed
              ? const Color(0xFF5DD9E8).withOpacity(0.25)
              : Colors.white.withOpacity(0.06),
          width: 1.3,
        ),
        borderRadius: BorderRadius.circular(9),
        boxShadow: [
          if (revealed)
            BoxShadow(
              color: const Color(0xFF5DD9E8).withOpacity(0.12),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
        ],
      ),
      child: revealed
          ? Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.grey.shade700.withOpacity(0.6),
                    Colors.grey.shade900.withOpacity(0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.location_on_rounded,
                size: 22,
                color: const Color(0xFF5DD9E8).withOpacity(0.7),
              ),
            )
          : Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF141E2A),
                    const Color(0xFF0A0F18),
                  ],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Icon(
                  Icons.lock_outline,
                  size: 19,
                  color: Colors.white.withOpacity(0.15),
                ),
              ),
            ),
    );
  }
}

class _ClaudeTitleSection extends StatelessWidget {
  const _ClaudeTitleSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          'מה בתמונה?',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 50,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.2,
            height: 1,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'חשוף חלקים · נחש את המקום',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withOpacity(0.64),
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.4,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _ClaudeNameInput extends StatelessWidget {
  final TextEditingController controller;
  final bool hasError;
  final ValueChanged<String> onChanged;

  const _ClaudeNameInput({
    required this.controller,
    required this.hasError,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFF1A2033).withOpacity(0.7),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: hasError
              ? Colors.red.shade400.withOpacity(0.5)
              : const Color(0xFF5DD9E8).withOpacity(0.15),
          width: 1.3,
        ),
        boxShadow: [
          BoxShadow(
            color: hasError
                ? Colors.red.shade400.withOpacity(0.08)
                : const Color(0xFF5DD9E8).withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          if (!hasError)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(13),
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF5DD9E8).withOpacity(0.05),
                      Colors.transparent,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
          TextField(
            controller: controller,
            onChanged: onChanged,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.center,
            maxLength: 16,
            textInputAction: TextInputAction.done,
            autocorrect: false,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
            decoration: InputDecoration(
              hintText: 'השם שלי (אופציונלי)',
              hintStyle: TextStyle(
                color: Colors.white.withOpacity(0.3),
                fontSize: 17,
                fontWeight: FontWeight.w400,
              ),
              counterText: '',
              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 0),
              border: InputBorder.none,
            ),
          ),
        ],
      ),
    );
  }
}

class _ClaudeButton extends StatelessWidget {
  final String label;
  final bool isPrimary;
  final VoidCallback onTap;

  const _ClaudeButton({
    required this.label,
    required this.isPrimary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          gradient: isPrimary
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFECC052),
                    Color(0xFFE8B923),
                    Color(0xFFC4872E),
                  ],
                )
              : const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF2C3240),
                    Color(0xFF1F242F),
                  ],
                ),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: isPrimary
                ? const Color(0xFFFFF8DC).withOpacity(0.35)
                : const Color(0xFF5DD9E8).withOpacity(0.12),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: isPrimary
                  ? const Color(0xFFE8B923).withOpacity(0.28)
                  : Colors.black.withOpacity(0.25),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
            if (isPrimary)
              BoxShadow(
                color: const Color(0xFFE8B923).withOpacity(0.12),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Stack(
          children: [
            if (isPrimary)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(11),
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.1),
                        Colors.transparent,
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.center,
                    ),
                  ),
                ),
              ),
            Center(
              child: Text(
                label,
                style: TextStyle(
                  color: isPrimary ? const Color(0xFF1A1F2E) : Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
