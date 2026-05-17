import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/display_name_sanitizer.dart';
import '../../../providers/providers.dart';
import '../../../services/qa_logger_service.dart';

class ProductionCandidateAuthScreen extends ConsumerStatefulWidget {
  const ProductionCandidateAuthScreen({super.key});

  @override
  ConsumerState<ProductionCandidateAuthScreen> createState() =>
      _ProductionCandidateAuthScreenState();
}

class _ProductionCandidateAuthScreenState
    extends ConsumerState<ProductionCandidateAuthScreen> {
  static const _navy = Color(0xFF050A14);
  static const _gold = Color(0xFFE8B923);
  static const _cyan = Color(0xFF00E5FF);

  final _nameController = TextEditingController();
  bool _isLoading = false;
  String? _nameError;

  @override
  void initState() {
    super.initState();
    QaLoggerService.instance.log('AUTH', 'PRODUCTION_CANDIDATE_OPENED');
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
    QaLoggerService.instance.log('AUTH', 'PRODUCTION_CANDIDATE_ANON_ATTEMPT');
    await _runAuth(
      () => ref.read(authServiceProvider).signInAnonymously(preferredName: name),
      logTag: 'PRODUCTION_CANDIDATE_ANON',
    );
  }

  Future<void> _signInWithGoogle() async {
    QaLoggerService.instance.log('AUTH', 'PRODUCTION_CANDIDATE_GOOGLE_ATTEMPT');
    await _runAuth(
      () => ref.read(authServiceProvider).signInWithGoogle(),
      logTag: 'PRODUCTION_CANDIDATE_GOOGLE',
    );
  }

  Future<void> _signInWithApple() async {
    QaLoggerService.instance.log('AUTH', 'PRODUCTION_CANDIDATE_APPLE_ATTEMPT');
    await _runAuth(
      () => ref.read(authServiceProvider).signInWithApple(),
      logTag: 'PRODUCTION_CANDIDATE_APPLE',
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
              SafeArea(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
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
                          const SizedBox(height: 20),
                          const _ProductionLocationGrid(),
                          const SizedBox(height: 32),
                          const _ProductionTitleSection(),
                          const SizedBox(height: 40),
                          _ProductionNameInput(
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
                          const SizedBox(height: 40),
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
                            _ProductionButton(
                              label: 'התחל לשחק',
                              isPrimary: true,
                              onTap: _signInAnonymously,
                            ),
                            const SizedBox(height: 12),
                            _ProductionButton(
                              label: 'המשך עם Google',
                              isPrimary: false,
                              onTap: _signInWithGoogle,
                            ),
                            if (Platform.isIOS) ...[
                              const SizedBox(height: 12),
                              _ProductionButton(
                                label: 'המשך עם Apple',
                                isPrimary: false,
                                onTap: _signInWithApple,
                              ),
                            ],
                          ],
                          const SizedBox(height: 28),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 12,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4AF37).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: const Color(0xFFD4AF37).withOpacity(0.35),
                      width: 0.8,
                    ),
                  ),
                  child: const Text(
                    'PROD',
                    style: TextStyle(
                      color: Color(0xFFE8B923),
                      fontSize: 9,
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

class _ProductionLocationGrid extends StatelessWidget {
  const _ProductionLocationGrid();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 160,
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 9,
          mainAxisSpacing: 9,
        ),
        itemCount: 9,
        itemBuilder: (context, index) {
          final revealed = [0, 2, 4, 5, 8].contains(index);
          return _ProductionLocationCard(revealed: revealed, index: index);
        },
      ),
    );
  }
}

class _ProductionLocationCard extends StatelessWidget {
  final bool revealed;
  final int index;

  const _ProductionLocationCard({required this.revealed, required this.index});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        boxShadow: revealed
            ? [
                BoxShadow(
                  color: const Color(0xFF00E5FF).withOpacity(0.1),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ]
            : [],
      ),
      child: revealed
          ? _RevealedCard(index: index)
          : _CoveredCard(index: index),
    );
  }
}

class _RevealedCard extends StatelessWidget {
  final int index;

  const _RevealedCard({required this.index});

  @override
  Widget build(BuildContext context) {
    final gradients = [
      LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFF8B6F47).withOpacity(0.8),
          const Color(0xFF4A3728).withOpacity(0.95),
        ],
      ),
      LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFF2E5266).withOpacity(0.8),
          const Color(0xFF1B2845).withOpacity(0.95),
        ],
      ),
      LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFF4A6741).withOpacity(0.8),
          const Color(0xFF283620).withOpacity(0.95),
        ],
      ),
      LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFF664D3E).withOpacity(0.8),
          const Color(0xFF3D2A20).withOpacity(0.95),
        ],
      ),
      LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFF5D6B76).withOpacity(0.8),
          const Color(0xFF3A4350).withOpacity(0.95),
        ],
      ),
    ];

    final gradient = gradients[index % gradients.length];

    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFF00E5FF).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withOpacity(0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.location_on_rounded,
                  size: 24,
                  color: const Color(0xFF00E5FF).withOpacity(0.7),
                ),
                const SizedBox(height: 4),
                Text(
                  'מקום',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CoveredCard extends StatelessWidget {
  final int index;

  const _CoveredCard({required this.index});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1A2A3A).withOpacity(0.7),
            const Color(0xFF0F1820).withOpacity(0.9),
          ],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
          width: 0.8,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.lock_rounded,
          size: 20,
          color: Colors.white.withOpacity(0.12),
        ),
      ),
    );
  }
}

class _ProductionTitleSection extends StatelessWidget {
  const _ProductionTitleSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          'מה בתמונה?',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 46,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.8,
            height: 1,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'חשוף חלקים · נחש את המקום',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 13,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.3,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _ProductionNameInput extends StatelessWidget {
  final TextEditingController controller;
  final bool hasError;
  final ValueChanged<String> onChanged;

  const _ProductionNameInput({
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasError
              ? Colors.red.shade400.withOpacity(0.4)
              : const Color(0xFF00E5FF).withOpacity(0.12),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: hasError
                ? Colors.red.shade400.withOpacity(0.06)
                : const Color(0xFF00E5FF).withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
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
          letterSpacing: 0.2,
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

class _ProductionButton extends StatelessWidget {
  final String label;
  final bool isPrimary;
  final VoidCallback onTap;

  const _ProductionButton({
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
                : const Color(0xFF00E5FF).withOpacity(0.1),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: isPrimary
                  ? const Color(0xFFE8B923).withOpacity(0.26)
                  : Colors.black.withOpacity(0.22),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
            if (isPrimary)
              BoxShadow(
                color: const Color(0xFFE8B923).withOpacity(0.1),
                blurRadius: 6,
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
                        Colors.white.withOpacity(0.12),
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
