import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/display_name_sanitizer.dart';
import '../../../providers/providers.dart';
import '../../../services/qa_logger_service.dart';

class GptAuthScreen extends ConsumerStatefulWidget {
  const GptAuthScreen({super.key});

  @override
  ConsumerState<GptAuthScreen> createState() => _GptAuthScreenState();
}

class _GptAuthScreenState extends ConsumerState<GptAuthScreen> {
  static const _navy = Color(0xFF050A14);
  static const _steelLight = Color(0xFF1A1F2E);
  static const _cyan = Color(0xFF4FC3F7);
  static const _gold = Color(0xFFD4AF37);

  final _nameController = TextEditingController();
  bool _isLoading = false;
  String? _nameError;

  @override
  void initState() {
    super.initState();
    QaLoggerService.instance.log('AUTH', 'GPT_DESIGN_OPENED');
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
    QaLoggerService.instance.log('AUTH', 'GPT_ANON_ATTEMPT');
    await _runAuth(
      () => ref.read(authServiceProvider).signInAnonymously(preferredName: name),
      logTag: 'GPT_ANON',
    );
  }

  Future<void> _signInWithGoogle() async {
    QaLoggerService.instance.log('AUTH', 'GPT_GOOGLE_ATTEMPT');
    await _runAuth(
      () => ref.read(authServiceProvider).signInWithGoogle(),
      logTag: 'GPT_GOOGLE',
    );
  }

  Future<void> _signInWithApple() async {
    QaLoggerService.instance.log('AUTH', 'GPT_APPLE_ATTEMPT');
    await _runAuth(
      () => ref.read(authServiceProvider).signInWithApple(),
      logTag: 'GPT_APPLE',
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
                      Color(0xFF0D1117),
                      Color(0xFF050A14),
                    ],
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
                          const SizedBox(height: 32),
                          const _GptRevealGrid(),
                          const SizedBox(height: 32),
                          const _GptTitleSection(),
                          const SizedBox(height: 48),
                          _GptNameInput(
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
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 11,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                          const SizedBox(height: 48),
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
                            _GptButton(
                              label: 'התחל לשחק',
                              isPrimary: true,
                              onTap: _signInAnonymously,
                            ),
                            const SizedBox(height: 12),
                            _GptButton(
                              label: 'המשך עם Google',
                              isPrimary: false,
                              onTap: _signInWithGoogle,
                            ),
                            if (Platform.isIOS) ...[
                              const SizedBox(height: 12),
                              _GptButton(
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10A37F).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: const Color(0xFF10A37F).withOpacity(0.4),
                      width: 0.8,
                    ),
                  ),
                  child: const Text(
                    'GPT',
                    style: TextStyle(
                      color: Color(0xFF10A37F),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
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

class _GptRevealGrid extends StatelessWidget {
  const _GptRevealGrid();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 140,
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: 9,
        itemBuilder: (context, index) {
          final revealed = index == 4 || index == 7;
          return _GptTile(revealed: revealed, index: index);
        },
      ),
    );
  }
}

class _GptTile extends StatelessWidget {
  final bool revealed;
  final int index;

  const _GptTile({required this.revealed, required this.index});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: revealed
            ? const Color(0xFF1A2B45).withOpacity(0.8)
            : const Color(0xFF0F1620),
        border: Border.all(
          color: revealed
              ? const Color(0xFF4FC3F7).withOpacity(0.3)
              : Colors.white.withOpacity(0.08),
          width: 1.2,
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          if (revealed)
            BoxShadow(
              color: const Color(0xFF4FC3F7).withOpacity(0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
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
                    Colors.grey.shade800,
                    Colors.grey.shade900,
                  ],
                ),
              ),
              child: Icon(
                Icons.location_on_rounded,
                size: 20,
                color: const Color(0xFF4FC3F7).withOpacity(0.6),
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
              ),
              child: Center(
                child: Icon(
                  Icons.lock_outline,
                  size: 18,
                  color: Colors.white.withOpacity(0.2),
                ),
              ),
            ),
    );
  }
}

class _GptTitleSection extends StatelessWidget {
  const _GptTitleSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          'מה בתמונה?',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 48,
            fontWeight: FontWeight.w900,
            letterSpacing: -1,
            height: 1,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'חשוף חלקים · נחש את המקום',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _GptNameInput extends StatelessWidget {
  final TextEditingController controller;
  final bool hasError;
  final ValueChanged<String> onChanged;

  const _GptNameInput({
    required this.controller,
    required this.hasError,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F2E).withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasError
              ? Colors.red.shade400.withOpacity(0.5)
              : Colors.white.withOpacity(0.1),
          width: 1.2,
        ),
        boxShadow: [
          if (hasError)
            BoxShadow(
              color: Colors.red.shade400.withOpacity(0.1),
              blurRadius: 8,
            ),
        ],
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.center,
        maxLength: 16,
        textInputAction: TextInputAction.done,
        autocorrect: false,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
        decoration: InputDecoration(
          hintText: 'השם שלי (אופציונלי)',
          hintStyle: TextStyle(
            color: Colors.white.withOpacity(0.3),
            fontSize: 16,
            fontWeight: FontWeight.w400,
          ),
          counterText: '',
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
          border: InputBorder.none,
        ),
      ),
    );
  }
}

class _GptButton extends StatelessWidget {
  final String label;
  final bool isPrimary;
  final VoidCallback onTap;

  const _GptButton({
    required this.label,
    required this.isPrimary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          gradient: isPrimary
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFE8B923),
                    Color(0xFFD4AF37),
                    Color(0xFFC4872E),
                  ],
                )
              : const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF2A2F3A),
                    Color(0xFF1F242F),
                  ],
                ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isPrimary
                ? const Color(0xFFFFF8DC).withOpacity(0.3)
                : Colors.white.withOpacity(0.12),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isPrimary
                  ? const Color(0xFFD4AF37).withOpacity(0.25)
                  : Colors.black.withOpacity(0.2),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
            if (isPrimary)
              BoxShadow(
                color: const Color(0xFFD4AF37).withOpacity(0.1),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isPrimary ? const Color(0xFF1A1F2E) : Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }
}
