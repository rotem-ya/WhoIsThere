import 'package:flutter/material.dart';

class VaultGameIcon extends StatefulWidget {
  final double size;

  const VaultGameIcon({
    super.key,
    this.size = 150,
  });

  @override
  State<VaultGameIcon> createState() => _VaultGameIconState();
}

class _VaultGameIconState extends State<VaultGameIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const navyDeep = Color(0xFF07101F);
    const goldPrimary = Color(0xFFD4AF37);
    const goldDark = Color(0xFFA1811A);
    const cyanEnergy = Color(0xFF87CEEB);
    final size = widget.size;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: navyDeep,
        borderRadius: BorderRadius.circular(size * 0.23),
        border: Border.all(color: goldDark.withOpacity(0.82), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.50),
            blurRadius: 16,
            offset: const Offset(0, 9),
          ),
          BoxShadow(
            color: goldPrimary.withOpacity(0.14),
            blurRadius: 34,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(size * 0.22),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.09),
                    Colors.transparent,
                    Colors.black.withOpacity(0.18),
                  ],
                ),
              ),
            ),
          ),
          _PuzzleGrid(
            size: size,
            cyanColor: cyanEnergy.withOpacity(0.22),
            goldColor: goldPrimary.withOpacity(0.24),
          ),
          _MagicCore(
            size: size,
            controller: _glowController,
            cyanColor: cyanEnergy,
            goldColor: goldPrimary,
          ),
        ],
      ),
    );
  }
}

class _PuzzleGrid extends StatelessWidget {
  final double size;
  final Color cyanColor;
  final Color goldColor;

  const _PuzzleGrid({
    required this.size,
    required this.cyanColor,
    required this.goldColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(size * 0.19),
      child: GridView.builder(
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: size * 0.065,
          mainAxisSpacing: size * 0.065,
        ),
        itemCount: 9,
        itemBuilder: (context, index) {
          if (index == 4) return const SizedBox.shrink();
          return Container(
            decoration: BoxDecoration(
              color: const Color(0xFF050A14),
              borderRadius: BorderRadius.circular(size * 0.055),
              border: Border.all(
                color: index.isEven ? goldColor : cyanColor,
                width: 1,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MagicCore extends StatelessWidget {
  final double size;
  final Animation<double> controller;
  final Color cyanColor;
  final Color goldColor;

  const _MagicCore({
    required this.size,
    required this.controller,
    required this.cyanColor,
    required this.goldColor,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          final glow = controller.value;
          return Container(
            width: size * 0.40,
            height: size * 0.40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  cyanColor,
                  cyanColor.withOpacity(0.10),
                  Colors.transparent,
                ],
                stops: const [0.1, 0.62, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: cyanColor.withOpacity(0.42 + glow * 0.34),
                  blurRadius: 18 + glow * 12,
                  spreadRadius: 2 + glow * 4,
                ),
                BoxShadow(
                  color: goldColor.withOpacity(0.40),
                  blurRadius: 6,
                  spreadRadius: -1,
                ),
              ],
            ),
            child: child,
          );
        },
        child: Icon(
          Icons.auto_awesome,
          size: size * 0.27,
          color: Colors.white,
          shadows: const [
            Shadow(color: Colors.black, blurRadius: 6, offset: Offset(0, 2)),
          ],
        ),
      ),
    );
  }
}
