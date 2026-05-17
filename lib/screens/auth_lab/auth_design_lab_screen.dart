import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AuthDesignLabScreen extends StatelessWidget {
  const AuthDesignLabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF050A14),
                Color(0xFF0A0F1E),
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 32),
                const Text(
                  'Auth Design Lab',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Select a design to preview',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 48),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      _DesignCard(
                        title: 'GPT Design',
                        subtitle: 'Current Production',
                        color: const Color(0xFF10A37F),
                        onTap: () => context.push('/auth_lab/gpt'),
                      ),
                      const SizedBox(height: 16),
                      _DesignCard(
                        title: 'Gemini Design',
                        subtitle: 'Vault & Rings',
                        color: const Color(0xFF4285F4),
                        onTap: () => context.push('/auth_lab/gemini'),
                      ),
                      const SizedBox(height: 16),
                      _DesignCard(
                        title: 'Claude Design',
                        subtitle: 'Enhanced Polish',
                        color: const Color(0xFFD4AF37),
                        onTap: () => context.push('/auth_lab/claude'),
                      ),
                      const SizedBox(height: 16),
                      _DesignCard(
                        title: 'Production Candidate',
                        subtitle: 'Location Cards Hero',
                        color: const Color(0xFF00E5FF),
                        onTap: () => context.push('/auth_lab/production'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                TextButton.icon(
                  onPressed: () => context.go('/auth'),
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: const Text('Back to Auth'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white60,
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DesignCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _DesignCard({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withOpacity(0.2),
                      border: Border.all(color: color.withOpacity(0.5), width: 1.5),
                    ),
                    child: Icon(Icons.arrow_forward_rounded, color: color, size: 20),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
