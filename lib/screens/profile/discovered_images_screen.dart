import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants/app_colors.dart';
import '../../core/ui/app_scaffold.dart';
import '../../models/game_image_model.dart';
import '../../providers/providers.dart';
import '../../widgets/common/app_header.dart';

// Normalized (x=0→1 W→E, y=0→1 N→S) for each place ID.
// x = (lng − 34.15) / 1.75,  y = (33.40 − lat) / 3.95
const Map<String, Offset> _placePositions = {
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
  'masada':                   Offset(0.686, 0.529),
  'dead_sea':                 Offset(0.771, 0.481),
  'ein_gedi':                 Offset(0.720, 0.492),
  'david_stream':             Offset(0.709, 0.502),
  'ramon_crater':             Offset(0.371, 0.709),
  'beer_sheva':               Offset(0.371, 0.544),
  'timna_park':               Offset(0.491, 0.919),
  'eilat':                    Offset(0.449, 0.966),
  'dolphin_reef':             Offset(0.463, 0.972),
  'mount_hermon':             Offset(0.957, 0.017),
  'banias_stream':            Offset(0.880, 0.040),
  'ein_gev_kibbutz':          Offset(0.854, 0.159),
  'sea_of_galilee':           Offset(0.829, 0.147),
  'tiberias':                 Offset(0.789, 0.156),
  'safed':                    Offset(0.771, 0.111),
  'rosh_hanikra':             Offset(0.543, 0.081),
  'old_acre':                 Offset(0.526, 0.119),
  'amud_stream':              Offset(0.743, 0.123),
  'mount_tabor':              Offset(0.709, 0.182),
  'beit_shean':               Offset(0.771, 0.228),
  'megiddo':                  Offset(0.589, 0.210),
  'haifa':                    Offset(0.479, 0.155),
  'bahai_gardens':            Offset(0.469, 0.163),
  'haifa_port':               Offset(0.491, 0.147),
  'caesarea':                 Offset(0.429, 0.228),
  'zichron_yaakov':           Offset(0.457, 0.213),
  'netanya':                  Offset(0.406, 0.271),
  'apollonia_national_park':  Offset(0.377, 0.309),
  'tel_aviv':                 Offset(0.360, 0.330),
  'old_jaffa':                Offset(0.339, 0.345),
  'azrieli_towers':           Offset(0.374, 0.333),
  'tel_aviv_port':            Offset(0.344, 0.320),
  'carmel_market':            Offset(0.351, 0.342),
  'yarkon_park':              Offset(0.366, 0.318),
  'ashdod':                   Offset(0.286, 0.405),
  'ashkelon':                 Offset(0.240, 0.438),
  'cave_of_the_patriarchs':   Offset(0.549, 0.476),
  'stalactite_cave':          Offset(0.474, 0.420),
};

const List<Offset> _borderPoints = [
  Offset(0.543, 0.081),
  Offset(0.657, 0.063),
  Offset(0.811, 0.030),
  Offset(0.943, 0.025),
  Offset(0.971, 0.066),
  Offset(0.931, 0.163),
  Offset(0.869, 0.182),
  Offset(0.800, 0.241),
  Offset(0.800, 0.413),
  Offset(0.800, 0.481),
  Offset(0.754, 0.583),
  Offset(0.686, 0.709),
  Offset(0.543, 0.810),
  Offset(0.480, 0.975),
  Offset(0.457, 0.975),
  Offset(0.286, 0.861),
  Offset(0.103, 0.638),
  Offset(0.069, 0.553),
  Offset(0.063, 0.481),
  Offset(0.229, 0.438),
  Offset(0.320, 0.342),
  Offset(0.380, 0.240),
  Offset(0.460, 0.147),
];

class DiscoveredImagesScreen extends ConsumerWidget {
  final List<String> discoveredImageIds;
  const DiscoveredImagesScreen({super.key, required this.discoveredImageIds});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allImagesAsync = ref.watch(allImagesProvider);
    final discoveredSet = discoveredImageIds.toSet();
    final total = _placePositions.length;
    final found = discoveredSet.intersection(_placePositions.keys.toSet()).length;

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
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF00E5FF).withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF00E5FF).withOpacity(0.35),
                  width: 0.8,
                ),
              ),
              child: Text(
                '$found / $total',
                style: const TextStyle(
                  color: Color(0xFF00E5FF),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          Expanded(
            child: discoveredSet.isEmpty
                ? _emptyState()
                : allImagesAsync.when(
                    data: (allImages) {
                      final imageMap = {for (final img in allImages) img.id: img};
                      return _IsraelMapView(
                        imageMap: imageMap,
                        discoveredSet: discoveredSet,
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator(color: AppColors.accent)),
                    error: (_, __) => _IsraelMapView(
                      imageMap: const {},
                      discoveredSet: discoveredSet,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text('🌍', style: TextStyle(fontSize: 60)),
            SizedBox(height: 14),
            Text(
              'עדיין לא גילית מקומות',
              style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 6),
            Text(
              'שחק משחק ראשון כדי לגלות מקומות',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ],
        ),
      );
}

// ── Map view ──────────────────────────────────────────────────────────────────

class _IsraelMapView extends StatefulWidget {
  final Map<String, GameImageModel> imageMap;
  final Set<String> discoveredSet;

  const _IsraelMapView({required this.imageMap, required this.discoveredSet});

  @override
  State<_IsraelMapView> createState() => _IsraelMapViewState();
}

class _IsraelMapViewState extends State<_IsraelMapView> {
  final _tc = TransformationController();
  double _scale = 1.0;

  @override
  void initState() {
    super.initState();
    _tc.addListener(() {
      final s = _tc.value.getMaxScaleOnAxis();
      if ((s - _scale).abs() > 0.05) setState(() => _scale = s);
    });
  }

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  void _onTap(String placeId) {
    if (!widget.discoveredSet.contains(placeId)) return;
    HapticFeedback.lightImpact();
    final image = widget.imageMap[placeId];
    if (image == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('תמונה אינה זמינה', textAlign: TextAlign.center),
        backgroundColor: const Color(0xFF0D1E30),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ));
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (_) => _PlaceSheet(image: image),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Dot radius shrinks when zoomed so visual size stays stable
    final dotR = (3.5 / _scale).clamp(1.0, 4.0);

    return Stack(
      children: [
        InteractiveViewer(
          transformationController: _tc,
          minScale: 0.9,
          maxScale: 6.0,
          boundaryMargin: const EdgeInsets.all(60),
          child: LayoutBuilder(builder: (_, constraints) {
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;
            return Stack(
              children: [
                // Map border
                Positioned.fill(
                  child: CustomPaint(
                    painter: _MapPainter(),
                  ).animate().fadeIn(duration: 500.ms),
                ),
                // Dots
                ..._placePositions.entries.toList().asMap().entries.map((e) {
                  final i = e.key;
                  final id = e.value.key;
                  final pos = e.value.value;
                  final disc = widget.discoveredSet.contains(id);
                  final px = pos.dx * w;
                  final py = pos.dy * h;
                  const hitSize = 32.0;
                  return Positioned(
                    left: px - hitSize / 2,
                    top: py - hitSize / 2,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _onTap(id),
                      child: SizedBox(
                        width: hitSize,
                        height: hitSize,
                        child: Center(
                          child: disc
                              ? _GlowDot(r: dotR)
                                  .animate(delay: Duration(milliseconds: 200 + i * 15))
                                  .fadeIn(duration: 220.ms)
                                  .scaleXY(begin: 0.0, end: 1.0, duration: 300.ms, curve: Curves.elasticOut)
                              : _DimDot(r: dotR * 0.55)
                                  .animate(delay: Duration(milliseconds: 60 + i * 6))
                                  .fadeIn(duration: 160.ms),
                        ),
                      ),
                    ),
                  );
                }),
                // N indicator
                Positioned(
                  top: 10, left: 10,
                  child: const _NorthBadge()
                      .animate(delay: 600.ms)
                      .fadeIn(duration: 250.ms),
                ),
              ],
            );
          }),
        ),
        // Zoom hint — fades out after 3s
        Positioned(
          bottom: 10,
          left: 0, right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.45),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.pinch_rounded, size: 12,
                      color: Colors.white.withOpacity(0.45)),
                  const SizedBox(width: 5),
                  Text('צבוט להגדלה',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.45), fontSize: 11)),
                ],
              ),
            )
                .animate(delay: 800.ms)
                .fadeIn(duration: 400.ms)
                .then(delay: 3.seconds)
                .fadeOut(duration: 600.ms),
          ),
        ),
      ],
    );
  }
}

// ── Painter ───────────────────────────────────────────────────────────────────

class _MapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size sz) {
    final path = Path()
      ..moveTo(_borderPoints[0].dx * sz.width, _borderPoints[0].dy * sz.height);
    for (var i = 1; i < _borderPoints.length; i++) {
      path.lineTo(_borderPoints[i].dx * sz.width, _borderPoints[i].dy * sz.height);
    }
    path.close();

    canvas.drawPath(path, Paint()
      ..color = const Color(0xFF07111F)
      ..style = PaintingStyle.fill);

    // soft outer glow
    canvas.drawPath(path, Paint()
      ..color = const Color(0xFF00FFFF).withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));

    // bright inner stroke
    canvas.drawPath(path, Paint()
      ..color = const Color(0xFF00E5FF).withOpacity(0.70)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round);
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

// ── Dots ─────────────────────────────────────────────────────────────────────

class _GlowDot extends StatelessWidget {
  final double r;
  const _GlowDot({required this.r});

  @override
  Widget build(BuildContext context) => Container(
        width: r * 2,
        height: r * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF00E5FF),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFF00FFFF).withOpacity(0.95),
                blurRadius: r * 1.5,
                spreadRadius: r * 0.4),
            BoxShadow(
                color: const Color(0xFF00FFFF).withOpacity(0.35),
                blurRadius: r * 4,
                spreadRadius: r),
          ],
        ),
      );
}

class _DimDot extends StatelessWidget {
  final double r;
  const _DimDot({required this.r});

  @override
  Widget build(BuildContext context) => Container(
        width: r * 2,
        height: r * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.25),
        ),
      );
}

class _NorthBadge extends StatelessWidget {
  const _NorthBadge();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFF060E1A).withOpacity(0.80),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: const Color(0xFF00E5FF).withOpacity(0.30), width: 0.7),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.navigation_rounded, color: Color(0xFF00E5FF), size: 10),
            SizedBox(width: 2),
            Text('N',
                style: TextStyle(
                    color: Color(0xFF00E5FF),
                    fontSize: 10,
                    fontWeight: FontWeight.w900)),
          ],
        ),
      );
}

// ── Bottom sheet ──────────────────────────────────────────────────────────────

class _PlaceSheet extends StatelessWidget {
  final GameImageModel image;
  const _PlaceSheet({required this.image});

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewPadding.bottom;
    return Container(
      margin: EdgeInsets.fromLTRB(0, 0, 0, bottomPad),
      decoration: const BoxDecoration(
        color: Color(0xFF0A1525),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 4),
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Image
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Stack(
                children: [
                  image.thumbnailUrl.isNotEmpty
                      ? _PlaceImage(url: image.thumbnailUrl)
                      : const _Placeholder(),
                  // gradient + name
                  Positioned(
                    bottom: 0, left: 0, right: 0,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(14, 30, 14, 14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.78),
                          ],
                        ),
                      ),
                      child: Text(
                        image.name.isNotEmpty ? image.name : image.answer,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Close
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                minimumSize: const Size(double.infinity, 46),
                backgroundColor: Colors.white.withOpacity(0.06),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('סגור',
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaceImage extends StatelessWidget {
  final String url;
  const _PlaceImage({required this.url});

  @override
  Widget build(BuildContext context) {
    if (url.startsWith('assets/')) {
      return Image.asset(url,
          height: 200,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const _Placeholder());
    }
    return CachedNetworkImage(
      imageUrl: url,
      height: 200,
      width: double.infinity,
      fit: BoxFit.cover,
      errorWidget: (_, __, ___) => const _Placeholder(),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder();

  @override
  Widget build(BuildContext context) => Container(
        height: 200,
        color: const Color(0xFF0D1E30),
        child: const Center(child: Text('🌍', style: TextStyle(fontSize: 48))),
      );
}
