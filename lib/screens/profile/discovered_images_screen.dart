import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants/app_colors.dart';
import '../../core/ui/app_scaffold.dart';
import '../../core/ui/app_text_styles.dart';
import '../../models/game_image_model.dart';
import '../../providers/providers.dart';
import '../../widgets/common/app_header.dart';
import '../../widgets/common/skeleton.dart';

// Normalized (x=0→1 W→E, y=0→1 N→S) for each place ID.
// Bounding box: N=33.40°, S=29.45°, W=34.15°, E=35.90°
// x = (lng − 34.15) / 1.75,  y = (33.40 − lat) / 3.95
const Map<String, Offset> _placePositions = {
  // ── Jerusalem cluster ─────────────────────────────────────────────────
  'western_wall':             Offset(0.618, 0.412),
  'dome_of_the_rock':         Offset(0.628, 0.404),
  'tower_of_david':           Offset(0.607, 0.418),
  'mahane_yehuda_market':     Offset(0.591, 0.423),
  'knesset':                  Offset(0.581, 0.431),
  'israel_museum':            Offset(0.571, 0.438),
  'yad_vashem':               Offset(0.557, 0.433),
  'old_city_jerusalem':       Offset(0.623, 0.416),
  'jaffa_gate':               Offset(0.612, 0.422),
  'damascus_gate':            Offset(0.624, 0.402),
  'mount_of_olives':          Offset(0.636, 0.407),
  'temple_mount':             Offset(0.630, 0.411),
  // ── Dead Sea area ─────────────────────────────────────────────────────
  'masada':                   Offset(0.686, 0.529),
  'dead_sea':                 Offset(0.771, 0.481),
  'ein_gedi':                 Offset(0.720, 0.492),
  'david_stream':             Offset(0.709, 0.502),
  // ── Negev ─────────────────────────────────────────────────────────────
  'ramon_crater':             Offset(0.371, 0.709),
  'beer_sheva':               Offset(0.371, 0.544),
  // ── Eilat / South ─────────────────────────────────────────────────────
  'timna_park':               Offset(0.491, 0.919),
  'eilat':                    Offset(0.449, 0.966),
  'dolphin_reef':             Offset(0.463, 0.972),
  // ── Golan Heights ─────────────────────────────────────────────────────
  'mount_hermon':             Offset(0.957, 0.017),
  'banias_stream':            Offset(0.880, 0.040),
  'ein_gev_kibbutz':          Offset(0.854, 0.159),
  // ── Sea of Galilee ────────────────────────────────────────────────────
  'sea_of_galilee':           Offset(0.829, 0.147),
  'tiberias':                 Offset(0.789, 0.156),
  // ── Upper Galilee ─────────────────────────────────────────────────────
  'safed':                    Offset(0.771, 0.111),
  'rosh_hanikra':             Offset(0.543, 0.081),
  'old_acre':                 Offset(0.526, 0.119),
  'amud_stream':              Offset(0.743, 0.123),
  // ── Lower Galilee ─────────────────────────────────────────────────────
  'mount_tabor':              Offset(0.709, 0.182),
  'beit_shean':               Offset(0.771, 0.228),
  'megiddo':                  Offset(0.589, 0.210),
  // ── Haifa cluster ─────────────────────────────────────────────────────
  'haifa':                    Offset(0.479, 0.155),
  'bahai_gardens':            Offset(0.469, 0.163),
  'haifa_port':               Offset(0.491, 0.147),
  // ── Sharon / Coastal ──────────────────────────────────────────────────
  'caesarea':                 Offset(0.429, 0.228),
  'zichron_yaakov':           Offset(0.457, 0.213),
  'netanya':                  Offset(0.406, 0.271),
  'apollonia_national_park':  Offset(0.377, 0.309),
  // ── Tel Aviv cluster ──────────────────────────────────────────────────
  'tel_aviv':                 Offset(0.360, 0.330),
  'old_jaffa':                Offset(0.339, 0.345),
  'azrieli_towers':           Offset(0.374, 0.333),
  'tel_aviv_port':            Offset(0.344, 0.320),
  'carmel_market':            Offset(0.351, 0.342),
  'yarkon_park':              Offset(0.366, 0.318),
  // ── South coast ───────────────────────────────────────────────────────
  'ashdod':                   Offset(0.286, 0.405),
  'ashkelon':                 Offset(0.240, 0.438),
  // ── Central / Judean Hills ────────────────────────────────────────────
  'cave_of_the_patriarchs':   Offset(0.549, 0.476),
  'stalactite_cave':          Offset(0.474, 0.420),
};

// Simplified Israel border (normalized, clockwise from NW coast).
const List<Offset> _borderPoints = [
  Offset(0.543, 0.081), // Rosh HaNikra coast
  Offset(0.657, 0.063), // Lebanon border E
  Offset(0.811, 0.030), // Metula
  Offset(0.943, 0.025), // Golan NE
  Offset(0.971, 0.066), // Golan E
  Offset(0.931, 0.163), // Golan SE
  Offset(0.869, 0.182), // Sea of Galilee SE
  Offset(0.800, 0.241), // Jordan Valley N
  Offset(0.800, 0.413), // Dead Sea N
  Offset(0.800, 0.481), // Dead Sea E
  Offset(0.754, 0.583), // Dead Sea S
  Offset(0.686, 0.709), // Arava N
  Offset(0.543, 0.810), // Arava mid
  Offset(0.480, 0.975), // Eilat E
  Offset(0.457, 0.975), // Eilat S tip
  Offset(0.286, 0.861), // Egyptian border mid
  Offset(0.103, 0.638), // Egyptian border NW
  Offset(0.069, 0.553), // Gaza/Egypt corner
  Offset(0.063, 0.481), // Gaza coast S
  Offset(0.229, 0.438), // Ashkelon coast
  Offset(0.320, 0.342), // Tel Aviv coast
  Offset(0.380, 0.240), // Sharon coast
  Offset(0.460, 0.147), // Haifa coast
];

class DiscoveredImagesScreen extends ConsumerWidget {
  final List<String> discoveredImageIds;
  const DiscoveredImagesScreen({super.key, required this.discoveredImageIds});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allImagesAsync = ref.watch(allImagesProvider);
    final discoveredSet = discoveredImageIds.toSet();

    return AppScaffold(
      backgroundGradient: AppColors.pageBackground,
      child: Column(
        children: [
          AppHeader(
            title: 'המקומות שגיליתי',
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.maybePop(context);
              },
            ),
          ),
          Expanded(
            child: allImagesAsync.when(
              data: (allImages) {
                final imageMap = {for (final img in allImages) img.id: img};
                final discovered = allImages
                    .where((img) => discoveredSet.contains(img.id))
                    .toList()
                  ..sort((a, b) => (a.name.isNotEmpty ? a.name : a.answer)
                      .compareTo(b.name.isNotEmpty ? b.name : b.answer));
                final locked =
                    allImages.where((img) => !discoveredSet.contains(img.id)).toList();

                if (allImages.isEmpty) {
                  return const _EmptyState();
                }
                return _CollectionView(
                  discovered: discovered,
                  locked: locked,
                  total: allImages.length,
                  discoveredSet: discoveredSet,
                  imageMap: imageMap,
                );
              },
              loading: () => const SingleChildScrollView(
                child: SkeletonGrid(count: 12),
              ),
              error: (e, _) => const _EmptyState(),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🌍', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          Text('עדיין לא גילית מקומות',
              style: AppTextStyles.titleDark, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text('שחק משחק ראשון כדי לגלות מקומות',
              style: AppTextStyles.subtitleDark, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ── Collection view: hero map + progress + grid of places ──────────────────────

class _CollectionView extends StatelessWidget {
  final List<GameImageModel> discovered;
  final List<GameImageModel> locked;
  final int total;
  final Set<String> discoveredSet;
  final Map<String, GameImageModel> imageMap;

  const _CollectionView({
    required this.discovered,
    required this.locked,
    required this.total,
    required this.discoveredSet,
    required this.imageMap,
  });

  void _openPlace(BuildContext context, GameImageModel image) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _PlaceSheet(image: image),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ordered = [...discovered, ...locked];
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
          16, 4, 16, 24 + MediaQuery.of(context).viewPadding.bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Hero map — decorative, shows where you've been
          _MapHero(discoveredSet: discoveredSet),
          const SizedBox(height: 12),
          _ProgressBar(discovered: discovered.length, total: total),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.82,
            ),
            itemCount: ordered.length,
            itemBuilder: (context, i) {
              final img = ordered[i];
              final isDiscovered = discoveredSet.contains(img.id);
              return _PlaceCard(
                image: img,
                discovered: isDiscovered,
                onTap: isDiscovered ? () => _openPlace(context, img) : null,
              ).animate(delay: Duration(milliseconds: 30 * (i.clamp(0, 12))))
                  .fadeIn(duration: 220.ms)
                  .scaleXY(begin: 0.94, end: 1.0, duration: 220.ms, curve: Curves.easeOut);
            },
          ),
        ],
      ),
    );
  }
}

// ── Progress bar ───────────────────────────────────────────────────────────────

class _ProgressBar extends StatelessWidget {
  final int discovered;
  final int total;
  const _ProgressBar({required this.discovered, required this.total});

  @override
  Widget build(BuildContext context) {
    final ratio = total == 0 ? 0.0 : (discovered / total).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'גילית $discovered מתוך $total מקומות',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              '${(ratio * 100).round()}%',
              style: const TextStyle(
                color: Color(0xFF00E5FF),
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: ratio),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (_, value, __) => LinearProgressIndicator(
              value: value,
              minHeight: 8,
              backgroundColor: Colors.white.withOpacity(0.08),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF00E5FF)),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Hero map (decorative, aspect-correct) ──────────────────────────────────────

class _MapHero extends StatelessWidget {
  final Set<String> discoveredSet;
  const _MapHero({required this.discoveredSet});

  // Israel's true proportions are tall & narrow (≈0.38 wide as tall),
  // so the silhouette is fitted — never stretched — and centered.
  static const double _aspect = 0.38;

  static Rect _fittedRect(Size s) {
    double w = s.height * _aspect;
    double h = s.height;
    if (w > s.width) {
      w = s.width;
      h = w / _aspect;
    }
    return Rect.fromLTWH((s.width - w) / 2, (s.height - h) / 2, w, h);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 320,
      child: LayoutBuilder(
        builder: (context, c) {
          final size = Size(c.maxWidth, c.maxHeight);
          final rect = _fittedRect(size);
          return Stack(
            children: [
              CustomPaint(
                size: size,
                painter: _IsraelMapPainter(rect),
              ).animate().fadeIn(duration: 600.ms, curve: Curves.easeOut),
              ..._placePositions.entries.map((e) {
                final discovered = discoveredSet.contains(e.key);
                final px = rect.left + e.value.dx * rect.width;
                final py = rect.top + e.value.dy * rect.height;
                final r = discovered ? 4.0 : 1.6;
                return Positioned(
                  left: px - r,
                  top: py - r,
                  child: (discovered
                          ? const _GlowDot(radius: 4.0)
                          : const _DimDot(radius: 1.6))
                      .animate().fadeIn(duration: 400.ms),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}

// ── Place card (grid) ──────────────────────────────────────────────────────────

class _PlaceCard extends StatelessWidget {
  final GameImageModel image;
  final bool discovered;
  final VoidCallback? onTap;

  const _PlaceCard({
    required this.image,
    required this.discovered,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0A1426),
                  border: Border.all(
                    color: discovered
                        ? const Color(0xFF00E5FF).withOpacity(0.45)
                        : Colors.white.withOpacity(0.08),
                    width: discovered ? 1.2 : 0.8,
                  ),
                  boxShadow: discovered
                      ? [
                          BoxShadow(
                            color: const Color(0xFF00E5FF).withOpacity(0.18),
                            blurRadius: 10,
                          ),
                        ]
                      : null,
                ),
                child: discovered
                    ? _PlaceThumb(url: image.thumbnailUrl)
                    : const Center(
                        child: Icon(Icons.lock_outline_rounded,
                            color: Colors.white24, size: 24),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            discovered
                ? (image.name.isNotEmpty ? image.name : image.answer)
                : '? ? ?',
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: discovered ? Colors.white : Colors.white38,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              height: 1.15,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Custom painter ─────────────────────────────────────────────────────────────

class _IsraelMapPainter extends CustomPainter {
  final Rect rect;
  const _IsraelMapPainter(this.rect);

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    Offset p(int i) => Offset(
          rect.left + _borderPoints[i].dx * rect.width,
          rect.top + _borderPoints[i].dy * rect.height,
        );
    path.moveTo(p(0).dx, p(0).dy);
    for (var i = 1; i < _borderPoints.length; i++) {
      path.lineTo(p(i).dx, p(i).dy);
    }
    path.close();

    // Dark fill
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF071324)
        ..style = PaintingStyle.fill,
    );
    // Outer glow
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF00FFFF).withOpacity(0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    // Mid glow
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF00E5FF).withOpacity(0.38)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    // Solid neon line
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF00E5FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _IsraelMapPainter oldDelegate) =>
      oldDelegate.rect != rect;
}

// ── Dot widgets ───────────────────────────────────────────────────────────────

class _GlowDot extends StatelessWidget {
  final double radius;
  const _GlowDot({required this.radius});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF00E5FF),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00FFFF).withOpacity(0.85),
            blurRadius: 8,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: const Color(0xFF00FFFF).withOpacity(0.40),
            blurRadius: 16,
            spreadRadius: 4,
          ),
        ],
      ),
    );
  }
}

class _DimDot extends StatelessWidget {
  final double radius;
  const _DimDot({required this.radius});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.18),
      ),
    );
  }
}

// ── Place info bottom sheet ───────────────────────────────────────────────────

class _PlaceSheet extends StatelessWidget {
  final GameImageModel image;
  const _PlaceSheet({required this.image});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.fromLTRB(
          16, 0, 16, 24 + MediaQuery.of(context).viewPadding.bottom),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1A2E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF00E5FF).withOpacity(0.35),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00FFFF).withOpacity(0.10),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 8),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Thumbnail
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: image.thumbnailUrl.isNotEmpty
                  ? _PlaceImage(url: image.thumbnailUrl)
                  : const _SheetImagePlaceholder(),
            ),
          ),
          // Name
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              image.name.isNotEmpty ? image.name : image.answer,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          // Close
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: double.infinity,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF00E5FF).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF00E5FF).withOpacity(0.28),
                    width: 0.8,
                  ),
                ),
                child: const Center(
                  child: Text(
                    'סגור',
                    style: TextStyle(
                      color: Color(0xFF00E5FF),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Fills its parent box (used by grid cards). Assets via Image.asset, URLs via CachedNetworkImage.
class _PlaceThumb extends StatelessWidget {
  final String url;
  const _PlaceThumb({required this.url});

  static const Widget _fallback = ColoredBox(
    color: Color(0xFF0D1E30),
    child: Center(child: Text('🌍', style: TextStyle(fontSize: 28))),
  );

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) return _fallback;
    if (url.startsWith('assets/')) {
      return Image.asset(
        url,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => _fallback,
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorWidget: (_, __, ___) => _fallback,
    );
  }
}

// Loads local assets (assets/...) with Image.asset, network URLs with CachedNetworkImage.
class _PlaceImage extends StatelessWidget {
  final String url;
  const _PlaceImage({required this.url});

  @override
  Widget build(BuildContext context) {
    if (url.startsWith('assets/')) {
      return Image.asset(
        url,
        height: 170,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const _SheetImagePlaceholder(),
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      height: 170,
      width: double.infinity,
      fit: BoxFit.cover,
      errorWidget: (_, __, ___) => const _SheetImagePlaceholder(),
    );
  }
}

class _SheetImagePlaceholder extends StatelessWidget {
  const _SheetImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 170,
      color: const Color(0xFF0D1E30),
      child: const Center(
        child: Text('🌍', style: TextStyle(fontSize: 48)),
      ),
    );
  }
}
