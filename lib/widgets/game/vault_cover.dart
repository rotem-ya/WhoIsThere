import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../../models/card_skin.dart';

Future<ui.Image> _decodeUiImage(Uint8List bytes) {
  final completer = Completer<ui.Image>();
  ui.decodeImageFromList(bytes, completer.complete);
  return completer.future;
}

/// Resolves a network URL to a ui.Image, DISK-caching it (same cache as remote
/// place images) so each skin image downloads once instead of on every cold
/// start — the skins store pulls ~30 covers at once, so this is the difference
/// between a one-time fetch and re-downloading everything each visit.
Future<ui.Image?> _fetchNetworkUiImage(String url) async {
  try {
    final file = await DefaultCacheManager().getSingleFile(url);
    final bytes = await file.readAsBytes();
    return await _decodeUiImage(bytes);
  } catch (_) {
    // Fallback: direct network fetch (memory-cached by Flutter only).
    try {
      final stream = NetworkImage(url).resolve(ImageConfiguration.empty);
      final completer = Completer<ui.Image>();
      late ImageStreamListener listener;
      listener = ImageStreamListener(
        (info, _) => completer.complete(info.image),
        onError: (e, _) => completer.completeError(e),
      );
      stream.addListener(listener);
      final image = await completer.future;
      stream.removeListener(listener);
      return image;
    } catch (_) {
      return null;
    }
  }
}

class VaultCover extends StatefulWidget {
  final bool isRevealed;
  final bool isFocused;
  final Widget child;
  final String cardSkinId;
  /// Optional full skin object — when provided, network coverImageUrl is used.
  final CardSkin? skin;

  /// Board position — when [gridSize] > 1 the skin image is sliced so this tile
  /// shows only its cell of the shared picture (the whole closed board = one
  /// image). Defaults keep standalone/whole-image behaviour.
  final int index;
  final int gridSize;

  const VaultCover({
    super.key,
    required this.isRevealed,
    required this.child,
    this.isFocused = false,
    this.cardSkinId = 'default',
    this.skin,
    this.index = 0,
    this.gridSize = 1,
  });

  @override
  State<VaultCover> createState() => _VaultCoverState();
}

class _VaultCoverState extends State<VaultCover>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  ui.Image? _skinImage;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);

    if (widget.isRevealed) _ctrl.value = 1.0;
    _loadSkinImage(widget.cardSkinId);
  }

  @override
  void didUpdateWidget(covariant VaultCover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRevealed && !oldWidget.isRevealed) {
      _ctrl.forward();
    } else if (!widget.isRevealed && oldWidget.isRevealed) {
      _ctrl.reverse();
    }
    if (widget.cardSkinId != oldWidget.cardSkinId ||
        widget.skin?.coverImageUrl != oldWidget.skin?.coverImageUrl) {
      _loadSkinImage(widget.cardSkinId);
    }
  }

  Future<void> _loadSkinImage(String skinId) async {
    // Prefer explicit skin object (may have network URL) over hardcoded lookup
    final skin = widget.skin ??
        kAvailableCardSkins.firstWhere(
          (s) => s.id == skinId,
          orElse: () => kAvailableCardSkins.first,
        );

    // Network image takes priority
    if (skin.coverImageUrl != null) {
      final image = await _fetchNetworkUiImage(skin.coverImageUrl!);
      if (mounted) setState(() => _skinImage = image);
      return;
    }

    if (skin.assetPath == null) {
      if (mounted) setState(() => _skinImage = null);
      return;
    }
    try {
      final data = await rootBundle.load(skin.assetPath!);
      final image = await _decodeUiImage(data.buffer.asUint8List());
      if (mounted) setState(() => _skinImage = image);
    } catch (_) {
      if (mounted) setState(() => _skinImage = null);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Revealed image underneath ──────────────────────────────────
          widget.child,

          // ── Cover / Iris ───────────────────────────────────────────
          AnimatedBuilder(
            animation: _anim,
            builder: (context, _) {
              final v = _anim.value;
              if (v >= 0.995) return const SizedBox.shrink();
              // Fully closed: show flat skin design instead of the star-shaped iris
              if (v <= 0.005) {
                return RepaintBoundary(
                  child: _skinImage != null
                      ? CustomPaint(
                          painter: _ImageFillPainter(_skinImage!,
                              index: widget.index, gridSize: widget.gridSize))
                      : CustomPaint(painter: _SkinPreviewPainter(widget.cardSkinId)),
                );
              }
              // Animating: show iris opening
              return RepaintBoundary(
                child: CustomPaint(
                  painter: _AperturePainter(
                    progress: v,
                    cardSkinId: widget.cardSkinId,
                    skinImage: _skinImage,
                    index: widget.index,
                    gridSize: widget.gridSize,
                  ),
                ),
              );
            },
          ),

          // ── Flash of light at reveal peak ──────────────────────────────
          AnimatedBuilder(
            animation: _ctrl, // linear for precise timing
            builder: (context, _) {
              final t = _ctrl.value;
              // Ramp up 0→0.38, ramp down 0.38→0.72
              final raw = t <= 0.38
                  ? t / 0.38
                  : math.max(0.0, 1.0 - (t - 0.38) / 0.34);
              final opacity = (raw * 0.60).clamp(0.0, 1.0);
              if (opacity < 0.01) return const SizedBox.shrink();
              return Opacity(
                opacity: opacity,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        Color(0xFFFFFFFF),
                        Color(0xFFFFE082),
                        Color(0x00FFE082),
                      ],
                      stops: [0.0, 0.40, 1.0],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Simple full-fill painter for image-based skins (closed state) ─────────────

/// Source rect within [image] for tile [index] of a [gridSize]² board.
/// The image is cover-cropped into the square board (centered square of side
/// min(w,h)), then divided into gridSize×gridSize cells — so every closed tile
/// shows its own slice and the whole board assembles into one complete picture.
Rect _skinSliceSrc(ui.Image image, int index, int gridSize) {
  final iw = image.width.toDouble(), ih = image.height.toDouble();
  final m = math.min(iw, ih);
  final ox = (iw - m) / 2, oy = (ih - m) / 2;
  final cell = m / gridSize;
  final row = index ~/ gridSize, col = index % gridSize;
  return Rect.fromLTWH(ox + col * cell, oy + row * cell, cell, cell);
}

class _ImageFillPainter extends CustomPainter {
  final ui.Image image;
  final int index;
  final int gridSize;
  _ImageFillPainter(this.image, {this.index = 0, this.gridSize = 1});

  @override
  void paint(Canvas canvas, Size size) {
    final iw = image.width.toDouble(), ih = image.height.toDouble();
    if (iw <= 0 || ih <= 0) return;
    final Rect src;
    if (gridSize > 1) {
      // Board tile: draw only this tile's slice of the shared image, so the
      // closed board forms one whole picture split across the tiles.
      src = _skinSliceSrc(image, index, gridSize);
    } else {
      // Standalone (store preview): BoxFit.cover center-crop of the whole image,
      // avoiding distortion and trimming any edge border the art carries.
      final scale = math.max(size.width / iw, size.height / ih);
      final sw = size.width / scale, sh = size.height / scale;
      src = Rect.fromLTWH((iw - sw) / 2, (ih - sh) / 2, sw, sh);
    }
    canvas.drawImageRect(
      image, src, Offset.zero & size, Paint()..filterQuality = FilterQuality.medium);
  }

  @override
  bool shouldRepaint(covariant _ImageFillPainter o) =>
      o.image != image || o.index != index || o.gridSize != gridSize;
}

// ── Improved iris painter ──────────────────────────────────────────────────────

/// The baked-image card catalog (kAvailableCardSkins) uses ids that no longer
/// have their own procedural art. Map each onto one of the rich, code-drawn
/// styles that DO exist, so dropping the low-quality baked photos still yields a
/// distinct, designed cover per skin (and the free default reads as Candy).
const Map<String, String> _kSkinStyleAlias = {
  'default': 'royal_throne', // free default → clean royal purple (Candy)
  'minimal_lines': 'urban_concrete',
  'minimal_calm': 'quiet_night',
  'nature_leaves': 'valley_green',
  'nature_waves': 'mediterranean_blue',
  'nature_anemone': 'anemone_red',
  'mosaic_arabesque': 'oriental_arabesque',
  'mosaic_tiles': 'kotel_stones',
  'mosaic_star': 'jerusalem_of_gold',
  'neon_grid': 'jerusalem_neon',
  'neon_wave': 'blue_fire',
  'neon_cyber': 'cyber_future_israel',
  'cosmic_galaxy': 'space_cluster',
  'cosmic_aurora': 'meteor_shower',
  'cosmic_fireice': 'lava_core',
  'royal_magen': 'royal_sapphire',
};

String _canonicalSkinId(String id) => _kSkinStyleAlias[id] ?? id;

/// Clean Candy jelly colorways for the static tile cover, keyed by the real
/// catalog id — [light, dark]. Renders as a glossy jelly tile (see
/// _SkinPreviewPainter), consistent with the app's look.
const Map<String, List<Color>> _kJellyCover = {
  'default': [Color(0xFF7B3FD1), Color(0xFF3A1B6E)], // grape (free default)
  'minimal_lines': [Color(0xFF5B7BD1), Color(0xFF2E3F7A)],
  'minimal_calm': [Color(0xFF12B5A6), Color(0xFF0B5A52)],
  'nature_leaves': [Color(0xFF8CE05A), Color(0xFF3F7A2E)],
  'nature_waves': [Color(0xFF3E7BE0), Color(0xFF1F3F8A)],
  'nature_anemone': [Color(0xFFFF6B6B), Color(0xFF9E2B3E)],
  'mosaic_arabesque': [Color(0xFF9B5AE0), Color(0xFF4A2A8A)],
  'mosaic_tiles': [Color(0xFF3FD6CF), Color(0xFF1F6E6A)],
  'mosaic_star': [Color(0xFFFFD84D), Color(0xFF9A7014)],
  'neon_grid': [Color(0xFFFF6EA6), Color(0xFF9E2F62)],
  'neon_wave': [Color(0xFF3EA8E0), Color(0xFF1F5A8A)],
  'neon_cyber': [Color(0xFF8C6EF0), Color(0xFF3A2E8A)],
  'cosmic_galaxy': [Color(0xFF6A4AD1), Color(0xFF2E1F6E)],
  'cosmic_aurora': [Color(0xFF3FD6A0), Color(0xFF1F6E5A)],
  'cosmic_fireice': [Color(0xFFFF9E4A), Color(0xFF9E3050)],
  'royal_magen': [Color(0xFFFFE07A), Color(0xFF7A5A10)],
};

class _AperturePainter extends CustomPainter {
  final double progress;
  final String cardSkinId;
  final ui.Image? skinImage;
  final int index;
  final int gridSize;

  static const int _bladeCount = 10;

  const _AperturePainter({
    required this.progress,
    this.cardSkinId = 'default',
    this.skinImage,
    this.index = 0,
    this.gridSize = 1,
  });

  // ── Per-skin colour scheme ─────────────────────────────────────────────────
  static _SkinPalette _palette(String rawId) {
    final id = _canonicalSkinId(rawId);
    switch (id) {
      case 'classic':
        return const _SkinPalette(
          base:          Color(0xFF1A1A2E),
          bladeLight:    Color(0xFFE8E8F0),
          bladeMid:      Color(0xFFB0B0C8),
          bladeDark:     Color(0xFF6060A0),
          bladeShadow:   Color(0xFF0D0D1E),
          seam:          Color(0xFFFFFFFF),
          rimOuter:      Color(0xFFB0B0C8),
          rimInner:      Color(0xFF8080C0),
        );
      case 'ocean':
        return const _SkinPalette(
          base:          Color(0xFF001A33),
          bladeLight:    Color(0xFF80FFEE),
          bladeMid:      Color(0xFF00BCD4),
          bladeDark:     Color(0xFF006080),
          bladeShadow:   Color(0xFF001020),
          seam:          Color(0xFFB2FFF5),
          rimOuter:      Color(0xFF00BCD4),
          rimInner:      Color(0xFF00E5FF),
        );
      case 'forest':
        return const _SkinPalette(
          base:          Color(0xFF071A07),
          bladeLight:    Color(0xFFB8FFB8),
          bladeMid:      Color(0xFF4CAF50),
          bladeDark:     Color(0xFF1B5E20),
          bladeShadow:   Color(0xFF030D03),
          seam:          Color(0xFFCCFFCC),
          rimOuter:      Color(0xFF4CAF50),
          rimInner:      Color(0xFF69F070),
        );
      case 'sand':
        return const _SkinPalette(
          base:          Color(0xFF2A1F0A),
          bladeLight:    Color(0xFFFFF8DC),
          bladeMid:      Color(0xFFD4A54A),
          bladeDark:     Color(0xFF8B6914),
          bladeShadow:   Color(0xFF1A1005),
          seam:          Color(0xFFFFFAE0),
          rimOuter:      Color(0xFFD4A54A),
          rimInner:      Color(0xFFFFD060),
        );
      case 'blue':
        return const _SkinPalette(
          base:          Color(0xFF030D1A),
          bladeLight:    Color(0xFFB8DFFF),
          bladeMid:      Color(0xFF87CEEB),
          bladeDark:     Color(0xFF1890D0),
          bladeShadow:   Color(0xFF040F1E),
          seam:          Color(0xFFD0EEFF),
          rimOuter:      Color(0xFF87CEEB),
          rimInner:      Color(0xFF00BFFF),
        );
      case 'red':
        return const _SkinPalette(
          base:          Color(0xFF1A0303),
          bladeLight:    Color(0xFFFFBBB0),
          bladeMid:      Color(0xFFFF6B6B),
          bladeDark:     Color(0xFFBB1515),
          bladeShadow:   Color(0xFF230404),
          seam:          Color(0xFFFFD0CC),
          rimOuter:      Color(0xFFFF6B6B),
          rimInner:      Color(0xFFFF3B30),
        );
      case 'copper':
        return const _SkinPalette(
          base:          Color(0xFF1A0D05),
          bladeLight:    Color(0xFFFFCBA0),
          bladeMid:      Color(0xFFB87333),
          bladeDark:     Color(0xFF6B3D0A),
          bladeShadow:   Color(0xFF100803),
          seam:          Color(0xFFFFDDB8),
          rimOuter:      Color(0xFFB87333),
          rimInner:      Color(0xFFFF9050),
        );
      case 'dark':
        return const _SkinPalette(
          base:          Color(0xFF05050F),
          bladeLight:    Color(0xFFB8AEFF),
          bladeMid:      Color(0xFF8B6FFF),
          bladeDark:     Color(0xFF4A3A8A),
          bladeShadow:   Color(0xFF080516),
          seam:          Color(0xFFD0C8FF),
          rimOuter:      Color(0xFF8B6FFF),
          rimInner:      Color(0xFF6464FF),
        );
      case 'emerald':
        return const _SkinPalette(
          base:          Color(0xFF011A0D),
          bladeLight:    Color(0xFF80FFD0),
          bladeMid:      Color(0xFF00C853),
          bladeDark:     Color(0xFF00571E),
          bladeShadow:   Color(0xFF010D06),
          seam:          Color(0xFFB0FFE0),
          rimOuter:      Color(0xFF00C853),
          rimInner:      Color(0xFF69FFB4),
        );
      case 'ruby':
        return const _SkinPalette(
          base:          Color(0xFF1A0008),
          bladeLight:    Color(0xFFFFB0C8),
          bladeMid:      Color(0xFFE91E63),
          bladeDark:     Color(0xFF880025),
          bladeShadow:   Color(0xFF120005),
          seam:          Color(0xFFFFCCDD),
          rimOuter:      Color(0xFFE91E63),
          rimInner:      Color(0xFFFF4088),
        );
      case 'rose_gold':
        return const _SkinPalette(
          base:          Color(0xFF1A0D10),
          bladeLight:    Color(0xFFFFD6CC),
          bladeMid:      Color(0xFFB76E79),
          bladeDark:     Color(0xFF7A3040),
          bladeShadow:   Color(0xFF120809),
          seam:          Color(0xFFFFE8E2),
          rimOuter:      Color(0xFFB76E79),
          rimInner:      Color(0xFFFFAABB),
        );
      case 'galaxy':
        return const _SkinPalette(
          base:          Color(0xFF03001A),
          bladeLight:    Color(0xFFE0C0FF),
          bladeMid:      Color(0xFF9C27B0),
          bladeDark:     Color(0xFF4A0072),
          bladeShadow:   Color(0xFF020010),
          seam:          Color(0xFFF0D8FF),
          rimOuter:      Color(0xFF9C27B0),
          rimInner:      Color(0xFFCE93D8),
        );
      case 'obsidian':
        return const _SkinPalette(
          base:          Color(0xFF000000),
          bladeLight:    Color(0xFF909090),
          bladeMid:      Color(0xFF404040),
          bladeDark:     Color(0xFF1A1A1A),
          bladeShadow:   Color(0xFF000000),
          seam:          Color(0xFFC0C0C0),
          rimOuter:      Color(0xFF606060),
          rimInner:      Color(0xFF909090),
        );

      // ── BASIC ────────────────────────────────────────────────────────────
      case 'mediterranean_blue':
        return const _SkinPalette(
          base:         Color(0xFF0A1828),
          bladeLight:   Color(0xFFA8D8E8),
          bladeMid:     Color(0xFF4CA1AF),
          bladeDark:    Color(0xFF2C3E50),
          bladeShadow:  Color(0xFF040C14),
          seam:         Color(0xFFD0EEF8),
          rimOuter:     Color(0xFF4CA1AF),
          rimInner:     Color(0xFF00BCD4),
        );
      case 'valley_green':
        return const _SkinPalette(
          base:         Color(0xFF041008),
          bladeLight:   Color(0xFF92FE9D),
          bladeMid:     Color(0xFF2ECC71),
          bladeDark:    Color(0xFF00693A),
          bladeShadow:  Color(0xFF020804),
          seam:         Color(0xFFC0FFD0),
          rimOuter:     Color(0xFF00C9FF),
          rimInner:     Color(0xFF00E5FF),
        );
      case 'negev_sands':
        return const _SkinPalette(
          base:         Color(0xFF1E1004),
          bladeLight:   Color(0xFFFFE29F),
          bladeMid:     Color(0xFFE8906A),
          bladeDark:    Color(0xFFD4651A),
          bladeShadow:  Color(0xFF0E0802),
          seam:         Color(0xFFFFF0C0),
          rimOuter:     Color(0xFFFFA99F),
          rimInner:     Color(0xFFFFD080),
        );
      case 'quiet_night':
        return const _SkinPalette(
          base:         Color(0xFF030508),
          bladeLight:   Color(0xFF8090C8),
          bladeMid:     Color(0xFF304060),
          bladeDark:    Color(0xFF0F2027),
          bladeShadow:  Color(0xFF010204),
          seam:         Color(0xFFD0D8F0),
          rimOuter:     Color(0xFFA9A9A9),
          rimInner:     Color(0xFFC0C8E8),
        );
      case 'dawn_light':
        return const _SkinPalette(
          base:         Color(0xFF120608),
          bladeLight:   Color(0xFFFFE0D8),
          bladeMid:     Color(0xFFFF9A9E),
          bladeDark:    Color(0xFFD04050),
          bladeShadow:  Color(0xFF080306),
          seam:         Color(0xFFFFEEEA),
          rimOuter:     Color(0xFFFF9A9E),
          rimInner:     Color(0xFFFFEECC),
        );
      case 'urban_concrete':
        return const _SkinPalette(
          base:         Color(0xFF0E1214),
          bladeLight:   Color(0xFFD0D4D8),
          bladeMid:     Color(0xFF8090A0),
          bladeDark:    Color(0xFF2C3E50),
          bladeShadow:  Color(0xFF060A0C),
          seam:         Color(0xFFE8ECEF),
          rimOuter:     Color(0xFFBDC3C7),
          rimInner:     Color(0xFF909090),
        );
      case 'default': // default card back = Israeli flag (shares this artwork)
      case 'classic_zionist':
        return const _SkinPalette(
          base:         Color(0xFFF0F4FF),
          bladeLight:   Color(0xFFFFFFFF),
          bladeMid:     Color(0xFF4472C8),
          bladeDark:    Color(0xFF0038B8),
          bladeShadow:  Color(0xFF002080),
          seam:         Color(0xFFFFFFFF),
          rimOuter:     Color(0xFF0038B8),
          rimInner:     Color(0xFF6699FF),
        );
      case 'summer_pastel':
        return const _SkinPalette(
          base:         Color(0xFF0C0410),
          bladeLight:   Color(0xFFFFD8E8),
          bladeMid:     Color(0xFFF0A0C0),
          bladeDark:    Color(0xFFD070A0),
          bladeShadow:  Color(0xFF080308),
          seam:         Color(0xFFFFE8F4),
          rimOuter:     Color(0xFFFAD0C4),
          rimInner:     Color(0xFFABEBC6),
        );
      case 'simple_gold_basic':
        return const _SkinPalette(
          base:         Color(0xFF0E0A00),
          bladeLight:   Color(0xFFFFF0A0),
          bladeMid:     Color(0xFFF1C40F),
          bladeDark:    Color(0xFFB8860B),
          bladeShadow:  Color(0xFF060500),
          seam:         Color(0xFFFFF8C0),
          rimOuter:     Color(0xFFF39C12),
          rimInner:     Color(0xFFFFD700),
        );
      case 'terracotta_earth':
        return const _SkinPalette(
          base:         Color(0xFF100604),
          bladeLight:   Color(0xFFFFB090),
          bladeMid:     Color(0xFFE07A5F),
          bladeDark:    Color(0xFF8B3A2A),
          bladeShadow:  Color(0xFF080302),
          seam:         Color(0xFFFFD0C0),
          rimOuter:     Color(0xFFA0522D),
          rimInner:     Color(0xFFC07060),
        );

      // ── RARE ─────────────────────────────────────────────────────────────
      case 'jerusalem_neon':
        return const _SkinPalette(
          base:         Color(0xFF080808),
          bladeLight:   Color(0xFFFF80FF),
          bladeMid:     Color(0xFFCC00CC),
          bladeDark:    Color(0xFF800080),
          bladeShadow:  Color(0xFF040404),
          seam:         Color(0xFFFF00FF),
          rimOuter:     Color(0xFFFF00FF),
          rimInner:     Color(0xFFFF80FF),
        );
      case 'steel_armor':
        return const _SkinPalette(
          base:         Color(0xFF0E1014),
          bladeLight:   Color(0xFFF0F4FF),
          bladeMid:     Color(0xFFA0A8C0),
          bladeDark:    Color(0xFF4A5068),
          bladeShadow:  Color(0xFF060810),
          seam:         Color(0xFFFFFFFF),
          rimOuter:     Color(0xFFC0C0C0),
          rimInner:     Color(0xFFE8E8FF),
        );
      case 'space_cluster':
        return const _SkinPalette(
          base:         Color(0xFF020210),
          bladeLight:   Color(0xFFD0C0FF),
          bladeMid:     Color(0xFF5080D0),
          bladeDark:    Color(0xFF1A2860),
          bladeShadow:  Color(0xFF010108),
          seam:         Color(0xFFE0D8FF),
          rimOuter:     Color(0xFF00FFFF),
          rimInner:     Color(0xFF8E44AD),
        );
      case 'blue_fire':
        return const _SkinPalette(
          base:         Color(0xFF000008),
          bladeLight:   Color(0xFF80E8FF),
          bladeMid:     Color(0xFF1CB5E0),
          bladeDark:    Color(0xFF004060),
          bladeShadow:  Color(0xFF000004),
          seam:         Color(0xFFC0F4FF),
          rimOuter:     Color(0xFF00FFFF),
          rimInner:     Color(0xFF0088CC),
        );
      case 'hermon_glacier':
        return const _SkinPalette(
          base:         Color(0xFF061014),
          bladeLight:   Color(0xFFF0FAFF),
          bladeMid:     Color(0xFF81D4FA),
          bladeDark:    Color(0xFF0288D1),
          bladeShadow:  Color(0xFF020608),
          seam:         Color(0xFFFFFFFF),
          rimOuter:     Color(0xFFB3E5FC),
          rimInner:     Color(0xFF40C4FF),
        );
      case 'oriental_arabesque':
        return const _SkinPalette(
          base:         Color(0xFF041014),
          bladeLight:   Color(0xFF90E0B0),
          bladeMid:     Color(0xFF3E9E78),
          bladeDark:    Color(0xFF134E5E),
          bladeShadow:  Color(0xFF020808),
          seam:         Color(0xFFB0FFD8),
          rimOuter:     Color(0xFFD4AF37),
          rimInner:     Color(0xFFFFD700),
        );
      case 'ancient_gold_rare':
        return const _SkinPalette(
          base:         Color(0xFF0A0600),
          bladeLight:   Color(0xFFFFE0A0),
          bladeMid:     Color(0xFFC39738),
          bladeDark:    Color(0xFF804000),
          bladeShadow:  Color(0xFF050300),
          seam:         Color(0xFFFFF0C0),
          rimOuter:     Color(0xFF804000),
          rimInner:     Color(0xFFFF8C00),
        );
      case 'brushed_titanium':
        return const _SkinPalette(
          base:         Color(0xFF060810),
          bladeLight:   Color(0xFF80A090),
          bladeMid:     Color(0xFF485563),
          bladeDark:    Color(0xFF1C2028),
          bladeShadow:  Color(0xFF020406),
          seam:         Color(0xFFA0B8B0),
          rimOuter:     Color(0xFF39FF14),
          rimInner:     Color(0xFF80FF60),
        );
      case 'eilat_coral':
        return const _SkinPalette(
          base:         Color(0xFF06040C),
          bladeLight:   Color(0xFFFFC0C0),
          bladeMid:     Color(0xFFFF6B6B),
          bladeDark:    Color(0xFF802030),
          bladeShadow:  Color(0xFF030208),
          seam:         Color(0xFFFFE0E0),
          rimOuter:     Color(0xFF00FFFF),
          rimInner:     Color(0xFFFF7090),
        );
      case 'meteor_shower':
        return const _SkinPalette(
          base:         Color(0xFF000000),
          bladeLight:   Color(0xFFE8E8FF),
          bladeMid:     Color(0xFF606070),
          bladeDark:    Color(0xFF202030),
          bladeShadow:  Color(0xFF000000),
          seam:         Color(0xFFFFFFFF),
          rimOuter:     Color(0xFFE0E0E0),
          rimInner:     Color(0xFFFFFFFF),
        );

      // ── PREMIUM ───────────────────────────────────────────────────────────
      case 'royal_throne':
        return const _SkinPalette(
          base:         Color(0xFF060010),
          bladeLight:   Color(0xFFE0C0FF),
          bladeMid:     Color(0xFF6441A5),
          bladeDark:    Color(0xFF2A0845),
          bladeShadow:  Color(0xFF030008),
          seam:         Color(0xFFF0E0FF),
          rimOuter:     Color(0xFFFFD700),
          rimInner:     Color(0xFFFF4444),
        );
      case 'ancient_scroll':
        return const _SkinPalette(
          base:         Color(0xFF2A1E08),
          bladeLight:   Color(0xFFFFF8E0),
          bladeMid:     Color(0xFFD2B48C),
          bladeDark:    Color(0xFFA08050),
          bladeShadow:  Color(0xFF150F04),
          seam:         Color(0xFFFFFAE8),
          rimOuter:     Color(0xFFC4A47C),
          rimInner:     Color(0xFF8B6914),
        );
      case 'jerusalem_of_gold':
        return const _SkinPalette(
          base:         Color(0xFF0E0A00),
          bladeLight:   Color(0xFFFFFCE0),
          bladeMid:     Color(0xFFFFD700),
          bladeDark:    Color(0xFFC8960A),
          bladeShadow:  Color(0xFF060400),
          seam:         Color(0xFFFFFFFF),
          rimOuter:     Color(0xFFFFD700),
          rimInner:     Color(0xFFFFFF80),
        );
      case 'kotel_stones':
        return const _SkinPalette(
          base:         Color(0xFF100E08),
          bladeLight:   Color(0xFFFFF8E8),
          bladeMid:     Color(0xFFC8A87A),
          bladeDark:    Color(0xFF8A7050),
          bladeShadow:  Color(0xFF080604),
          seam:         Color(0xFFFFFAF0),
          rimOuter:     Color(0xFFA89F91),
          rimInner:     Color(0xFFFFD700),
        );
      case 'anemone_red':
        return const _SkinPalette(
          base:         Color(0xFF100402),
          bladeLight:   Color(0xFFFFB0A0),
          bladeMid:     Color(0xFFED1C24),
          bladeDark:    Color(0xFF7D0A0A),
          bladeShadow:  Color(0xFF080202),
          seam:         Color(0xFFFFD0C8),
          rimOuter:     Color(0xFFFFD700),
          rimInner:     Color(0xFFFF6060),
        );
      case 'salt_sunset':
        return const _SkinPalette(
          base:         Color(0xFF030008),
          bladeLight:   Color(0xFFFFC080),
          bladeMid:     Color(0xFF8E24AA),
          bladeDark:    Color(0xFF4A00E0),
          bladeShadow:  Color(0xFF010004),
          seam:         Color(0xFFFFE0C0),
          rimOuter:     Color(0xFFFF00FF),
          rimInner:     Color(0xFF8844CC),
        );
      case 'royal_sapphire':
        return const _SkinPalette(
          base:         Color(0xFF000018),
          bladeLight:   Color(0xFFA0C0FF),
          bladeMid:     Color(0xFF0000CD),
          bladeDark:    Color(0xFF000080),
          bladeShadow:  Color(0xFF00000C),
          seam:         Color(0xFFE0EEFF),
          rimOuter:     Color(0xFF3333FF),
          rimInner:     Color(0xFF88AAFF),
        );
      case 'lava_core':
        return const _SkinPalette(
          base:         Color(0xFF060200),
          bladeLight:   Color(0xFFFF8040),
          bladeMid:     Color(0xFFFF4500),
          bladeDark:    Color(0xFF802000),
          bladeShadow:  Color(0xFF030100),
          seam:         Color(0xFFFFC080),
          rimOuter:     Color(0xFFFF4500),
          rimInner:     Color(0xFFFF8C00),
        );
      case 'diamond_shield':
        return const _SkinPalette(
          base:         Color(0xFF04080C),
          bladeLight:   Color(0xFFFFFFFF),
          bladeMid:     Color(0xFFB9F2FF),
          bladeDark:    Color(0xFF4080A0),
          bladeShadow:  Color(0xFF020406),
          seam:         Color(0xFFFFFFFF),
          rimOuter:     Color(0xFFE8E8FF),
          rimInner:     Color(0xFF00E5FF),
        );
      case 'cyber_future_israel':
        return const _SkinPalette(
          base:         Color(0xFF000000),
          bladeLight:   Color(0xFF80FFFF),
          bladeMid:     Color(0xFF0080C0),
          bladeDark:    Color(0xFF003060),
          bladeShadow:  Color(0xFF000000),
          seam:         Color(0xFFFFFFFF),
          rimOuter:     Color(0xFF00FFFF),
          rimInner:     Color(0xFF8080FF),
        );

      default: // 'default' — gold mandala
        return const _SkinPalette(
          base:          Color(0xFF07101F),
          bladeLight:    Color(0xFFFFF3B8),
          bladeMid:      Color(0xFFD4AF37),
          bladeDark:     Color(0xFF8B6914),
          bladeShadow:   Color(0xFF3A2A05),
          seam:          Color(0xFFFFF8CC),
          rimOuter:      Color(0xFFD4AF37),
          rimInner:      Color(0xFF87CEEB),
        );
    }
  }

  // ── Per-skin unique background pattern ────────────────────────────────────
  void _drawSkinPattern(Canvas canvas, Size size, Rect rect,
      Offset center, _SkinPalette pal) {
    _drawPattern(canvas, size, rect, center, pal, cardSkinId);
  }

  static void _drawPattern(
      Canvas canvas, Size size, Rect rect, Offset center,
      _SkinPalette pal, String rawSkinId) {
    final skinId = _canonicalSkinId(rawSkinId);
    final rngA = math.Random(1337);
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final fillPaint = Paint()..style = PaintingStyle.fill;

    switch (skinId) {
      // ── classic — ornamental diamond grid ──────────────────────────────
      case 'classic':
        linePaint
          ..color = pal.bladeMid.withOpacity(0.20)
          ..strokeWidth = 0.8;
        const s = 20.0;
        for (var x = -s; x < size.width + s; x += s) {
          for (var y = -s; y < size.height + s; y += s) {
            final p = Path()
              ..moveTo(x, y - s * 0.5)
              ..lineTo(x + s * 0.5, y)
              ..lineTo(x, y + s * 0.5)
              ..lineTo(x - s * 0.5, y)
              ..close();
            canvas.drawPath(p, linePaint);
          }
        }

      // ── ocean — horizontal sine waves ──────────────────────────────────
      case 'ocean':
        linePaint
          ..color = pal.bladeMid.withOpacity(0.22)
          ..strokeWidth = 1.1;
        const waveCount = 13;
        const amp = 5.0;
        for (var w = 0; w <= waveCount; w++) {
          final baseY = (size.height / waveCount) * w;
          final path = Path();
          var first = true;
          for (var x = 0.0; x <= size.width; x += 3) {
            final y = baseY + math.sin(x * 0.045 + w * 0.9) * amp;
            if (first) {
              path.moveTo(x, y);
              first = false;
            } else {
              path.lineTo(x, y);
            }
          }
          canvas.drawPath(path, linePaint);
        }

      // ── forest — diagonal branch lines + leaf ovals ────────────────────
      case 'forest':
        linePaint
          ..color = pal.bladeMid.withOpacity(0.18)
          ..strokeWidth = 0.9;
        const spacing = 26.0;
        for (var i = -size.height.toInt();
            i < size.width.toInt() + size.height.toInt();
            i += spacing.toInt()) {
          canvas.drawLine(Offset(i.toDouble(), 0),
              Offset(i.toDouble() + size.height * 0.7, size.height), linePaint);
        }
        fillPaint.color = pal.bladeLight.withOpacity(0.12);
        for (var i = 0; i < 18; i++) {
          final angle = i * 2.41;
          final r = size.width * (0.08 + (i % 5) * 0.09);
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(center.dx + math.cos(angle) * r,
                  center.dy + math.sin(angle) * r),
              width: 14,
              height: 7,
            ),
            fillPaint,
          );
        }

      // ── sand — concentric ellipse rings ────────────────────────────────
      case 'sand':
        linePaint
          ..color = pal.bladeMid.withOpacity(0.22)
          ..strokeWidth = 1.0;
        for (var i = 1; i <= 12; i++) {
          canvas.drawOval(
            Rect.fromCenter(
              center: center,
              width: i * size.width * 0.17,
              height: i * size.height * 0.13,
            ),
            linePaint,
          );
        }

      // ── blue — constellation (dots + connecting lines) ─────────────────
      case 'blue':
        final positions = List.generate(
          55,
          (i) => Offset(
            rngA.nextDouble() * size.width,
            rngA.nextDouble() * size.height,
          ),
        );
        fillPaint.color = pal.bladeLight.withOpacity(0.55);
        for (final p in positions) {
          canvas.drawCircle(p, rngA.nextDouble() * 1.5 + 0.5, fillPaint);
        }
        linePaint
          ..color = pal.bladeMid.withOpacity(0.14)
          ..strokeWidth = 0.6;
        for (var i = 0; i < 14; i++) {
          canvas.drawLine(positions[i], positions[i + 1], linePaint);
        }

      // ── red — bold diagonal stripes ────────────────────────────────────
      case 'red':
        linePaint
          ..color = pal.bladeMid.withOpacity(0.20)
          ..strokeWidth = 10;
        const sp = 32.0;
        for (var i = -size.height.toInt();
            i < size.width.toInt() + size.height.toInt();
            i += sp.toInt()) {
          canvas.drawLine(Offset(i.toDouble(), 0),
              Offset(i.toDouble() + size.height, size.height), linePaint);
        }

      // ── copper — cross-hatch grid ──────────────────────────────────────
      case 'copper':
        linePaint
          ..color = pal.bladeMid.withOpacity(0.20)
          ..strokeWidth = 0.8;
        const g = 18.0;
        for (var x = 0.0; x < size.width; x += g) {
          canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
        }
        for (var y = 0.0; y < size.height; y += g) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
        }

      // ── dark — night star field + purple glow ─────────────────────────
      case 'dark':
        fillPaint.color = pal.bladeLight.withOpacity(0.55);
        for (var i = 0; i < 90; i++) {
          final x = rngA.nextDouble() * size.width;
          final y = rngA.nextDouble() * size.height;
          final r = i < 6 ? 1.8 : 0.7;
          canvas.drawCircle(Offset(x, y), r, fillPaint);
        }
        // Soft central glow
        canvas.drawCircle(
          center,
          size.width * 0.28,
          Paint()
            ..color = pal.bladeDark.withOpacity(0.22)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24),
        );

      // ── emerald — hexagonal grid ───────────────────────────────────────
      case 'emerald':
        linePaint
          ..color = pal.bladeMid.withOpacity(0.22)
          ..strokeWidth = 1.0;
        const hr = 16.0;
        const dx = hr * 1.7321; // sqrt(3)
        const dy = hr * 1.5;
        for (var row = -1; row < size.height / dy + 2; row++) {
          for (var col = -1; col < size.width / dx + 2; col++) {
            final ox = (row % 2) * (dx / 2);
            final cx = col * dx + ox;
            final cy = row * dy;
            final path = Path();
            for (var side = 0; side < 6; side++) {
              final a = side * math.pi / 3 - math.pi / 6;
              final px = cx + hr * math.cos(a);
              final py = cy + hr * math.sin(a);
              if (side == 0) path.moveTo(px, py);
              else path.lineTo(px, py);
            }
            path.close();
            canvas.drawPath(path, linePaint);
          }
        }

      // ── ruby — scattered 4-pointed sparkles ───────────────────────────
      case 'ruby':
        fillPaint.color = pal.bladeLight.withOpacity(0.40);
        for (var i = 0; i < 40; i++) {
          final x = rngA.nextDouble() * size.width;
          final y = rngA.nextDouble() * size.height;
          final s = rngA.nextDouble() * 5 + 2;
          final path = Path()
            ..moveTo(x, y - s)
            ..lineTo(x + s * 0.28, y - s * 0.28)
            ..lineTo(x + s, y)
            ..lineTo(x + s * 0.28, y + s * 0.28)
            ..lineTo(x, y + s)
            ..lineTo(x - s * 0.28, y + s * 0.28)
            ..lineTo(x - s, y)
            ..lineTo(x - s * 0.28, y - s * 0.28)
            ..close();
          canvas.drawPath(path, fillPaint);
        }

      // ── rose_gold — overlapping circle petals ─────────────────────────
      case 'rose_gold':
        linePaint
          ..color = pal.bladeMid.withOpacity(0.18)
          ..strokeWidth = 1.1;
        const petalCount = 8;
        const petalR = 30.0;
        for (var i = 0; i < petalCount; i++) {
          final a = (i / petalCount) * 2 * math.pi;
          final px = center.dx + math.cos(a) * petalR;
          final py = center.dy + math.sin(a) * petalR;
          for (var j = 0; j < 4; j++) {
            canvas.drawCircle(
              Offset(px, py),
              petalR * (1 - j * 0.2),
              linePaint
                ..color = pal.bladeMid.withOpacity(0.10 - j * 0.02),
            );
          }
        }
        for (var r = 15.0; r < size.width; r += 28) {
          canvas.drawCircle(
              center, r, linePaint..color = pal.bladeLight.withOpacity(0.07));
        }

      // ── galaxy — star field + two spiral arms ─────────────────────────
      case 'galaxy':
        fillPaint.color = pal.bladeLight.withOpacity(0.60);
        for (var i = 0; i < 130; i++) {
          canvas.drawCircle(
            Offset(rngA.nextDouble() * size.width,
                rngA.nextDouble() * size.height),
            rngA.nextDouble() * 1.4 + 0.3,
            fillPaint,
          );
        }
        linePaint
          ..color = pal.bladeMid.withOpacity(0.16)
          ..strokeWidth = 1.6;
        for (var arm = 0; arm < 2; arm++) {
          final offset = arm * math.pi;
          final path = Path();
          var first = true;
          for (var t = 0.0; t < 4 * math.pi; t += 0.07) {
            final r = t * size.width * 0.06;
            final x = center.dx + math.cos(t + offset) * r;
            final y = center.dy + math.sin(t + offset) * r;
            if (first) {
              path.moveTo(x, y);
              first = false;
            } else {
              path.lineTo(x, y);
            }
          }
          canvas.drawPath(path, linePaint);
        }

      // ── mediterranean_blue — layered horizontal waves ─────────────────
      case 'mediterranean_blue':
        linePaint
          ..color = pal.bladeMid.withOpacity(0.25)
          ..strokeWidth = 1.2;
        const mbWaves = 10;
        const mbAmp = 6.0;
        for (var w = 0; w <= mbWaves; w++) {
          final baseY = (size.height / mbWaves) * w;
          final path = Path();
          var first = true;
          for (var x = 0.0; x <= size.width; x += 4) {
            final y = baseY + math.sin(x * 0.04 + w * 1.1) * mbAmp;
            if (first) { path.moveTo(x, y); first = false; }
            else path.lineTo(x, y);
          }
          canvas.drawPath(path, linePaint);
        }

      // ── valley_green — diagonal crop rows + leaf ovals ────────────────
      case 'valley_green':
        linePaint
          ..color = pal.bladeMid.withOpacity(0.18)
          ..strokeWidth = 1.0;
        const vgSp = 22.0;
        for (var i = -size.height.toInt();
            i < size.width.toInt() + size.height.toInt();
            i += vgSp.toInt()) {
          canvas.drawLine(Offset(i.toDouble(), 0),
              Offset(i.toDouble() + size.height * 0.6, size.height), linePaint);
        }
        fillPaint.color = pal.bladeLight.withOpacity(0.22);
        for (var i = 0; i < 20; i++) {
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(rngA.nextDouble() * size.width,
                  rngA.nextDouble() * size.height),
              width: 10,
              height: 5,
            ),
            fillPaint,
          );
        }

      // ── negev_sands — concentric ellipses (dune silhouette) ───────────
      case 'negev_sands':
        linePaint
          ..color = pal.bladeMid.withOpacity(0.22)
          ..strokeWidth = 1.0;
        final duneC = Offset(center.dx, size.height * 0.78);
        for (var i = 1; i <= 14; i++) {
          canvas.drawOval(
            Rect.fromCenter(
              center: duneC,
              width: i * size.width * 0.18,
              height: i * size.height * 0.10,
            ),
            linePaint,
          );
        }

      // ── quiet_night — dense star field + moon glow ────────────────────
      case 'quiet_night':
        fillPaint.color = pal.bladeLight.withOpacity(0.60);
        for (var i = 0; i < 110; i++) {
          final r = i < 9 ? 2.0 : 0.8;
          canvas.drawCircle(
            Offset(rngA.nextDouble() * size.width,
                rngA.nextDouble() * size.height),
            r,
            fillPaint,
          );
        }
        canvas.drawCircle(
          Offset(size.width * 0.76, size.height * 0.2),
          size.width * 0.13,
          Paint()
            ..color = Colors.white.withOpacity(0.07)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
        );

      // ── dawn_light — radial rays from horizon ─────────────────────────
      case 'dawn_light':
        linePaint
          ..color = pal.bladeMid.withOpacity(0.18)
          ..strokeWidth = 1.5;
        final sunPt = Offset(center.dx, size.height * 1.08);
        for (var i = 0; i < 18; i++) {
          final a = -math.pi + (i / 18) * math.pi;
          canvas.drawLine(
            sunPt,
            Offset(sunPt.dx + math.cos(a) * size.width * 1.4,
                sunPt.dy + math.sin(a) * size.height * 1.4),
            linePaint,
          );
        }

      // ── urban_concrete — square grid ──────────────────────────────────
      case 'urban_concrete':
        linePaint
          ..color = pal.bladeMid.withOpacity(0.18)
          ..strokeWidth = 0.9;
        const ucG = 20.0;
        for (var x = 0.0; x < size.width; x += ucG) {
          canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
        }
        for (var y = 0.0; y < size.height; y += ucG) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
        }

      // ── classic_zionist — two Israeli flag stripes ────────────────────
      case 'default': // default card back = Israeli flag (shares this artwork)
      case 'classic_zionist':
        final stripePaint = Paint()
          ..color = pal.bladeDark.withOpacity(0.85)
          ..strokeWidth = 7.0
          ..style = PaintingStyle.stroke;
        canvas.drawLine(Offset(0, size.height * 0.22),
            Offset(size.width, size.height * 0.22), stripePaint);
        canvas.drawLine(Offset(0, size.height * 0.78),
            Offset(size.width, size.height * 0.78), stripePaint);
        canvas.drawCircle(
          center,
          size.width * 0.12,
          Paint()
            ..color = pal.bladeDark.withOpacity(0.20)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0,
        );

      // ── summer_pastel — soft overlapping circles + rings ──────────────
      case 'summer_pastel':
        fillPaint.color = pal.bladeMid.withOpacity(0.13);
        for (var i = 0; i < 12; i++) {
          final r = 14.0 + (i % 4) * 9.0;
          final a = i * 2.09;
          final dist = size.width * (0.14 + (i % 3) * 0.16);
          canvas.drawCircle(
            Offset(center.dx + math.cos(a) * dist,
                center.dy + math.sin(a) * dist),
            r,
            fillPaint,
          );
        }
        linePaint
          ..color = pal.rimInner.withOpacity(0.15)
          ..strokeWidth = 0.8;
        for (var r = 22.0; r < size.width; r += 26) {
          canvas.drawCircle(center, r, linePaint);
        }

      // ── simple_gold_basic — diamond grid ──────────────────────────────
      case 'simple_gold_basic':
        linePaint
          ..color = pal.bladeMid.withOpacity(0.25)
          ..strokeWidth = 0.9;
        const sgS = 22.0;
        for (var x = -sgS; x < size.width + sgS; x += sgS) {
          for (var y = -sgS; y < size.height + sgS; y += sgS) {
            final p = Path()
              ..moveTo(x, y - sgS * 0.5)
              ..lineTo(x + sgS * 0.5, y)
              ..lineTo(x, y + sgS * 0.5)
              ..lineTo(x - sgS * 0.5, y)
              ..close();
            canvas.drawPath(p, linePaint);
          }
        }

      // ── terracotta_earth — alternating horizontal clay bands ──────────
      case 'terracotta_earth':
        const teCount = 12;
        for (var i = 0; i < teCount; i++) {
          final y = (size.height / teCount) * i;
          final h = size.height / teCount * 0.45;
          fillPaint.color =
              (i % 2 == 0 ? pal.bladeMid : pal.bladeDark).withOpacity(0.18);
          canvas.drawRect(Rect.fromLTWH(0, y, size.width, h), fillPaint);
        }

      // ── RARE ──────────────────────────────────────────────────────────

      // ── jerusalem_neon — stone wall pattern + neon glow ───────────────
      case 'jerusalem_neon':
        linePaint
          ..color = pal.bladeMid.withOpacity(0.30)
          ..strokeWidth = 0.8;
        const jnRowH = 18.0;
        for (var row = 0; row * jnRowH < size.height; row++) {
          final y = row * jnRowH;
          canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
          final jnOff = (row % 2) * 20.0;
          for (var x = jnOff; x < size.width; x += 40.0) {
            canvas.drawLine(Offset(x, y), Offset(x, y + jnRowH), linePaint);
          }
        }
        canvas.drawCircle(
          center,
          size.width * 0.22,
          Paint()
            ..color = pal.rimOuter.withOpacity(0.10)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20),
        );

      // ── steel_armor — brushed horizontal lines + diagonal highlight ───
      case 'steel_armor':
        linePaint
          ..color = pal.bladeLight.withOpacity(0.12)
          ..strokeWidth = 0.5;
        var y = 0.0;
        while (y < size.height) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
          y += 3.0;
        }
        linePaint
          ..color = pal.bladeLight.withOpacity(0.22)
          ..strokeWidth = 2.0;
        canvas.drawLine(
            Offset(0, size.height * 0.28), Offset(size.width, 0), linePaint);
        canvas.drawLine(
            Offset(0, size.height), Offset(size.width, size.height * 0.48),
            linePaint);

      // ── space_cluster — dense star field + nebula blobs ───────────────
      case 'space_cluster':
        fillPaint.color = pal.bladeLight.withOpacity(0.65);
        for (var i = 0; i < 150; i++) {
          canvas.drawCircle(
            Offset(rngA.nextDouble() * size.width,
                rngA.nextDouble() * size.height),
            i < 10 ? 1.8 : 0.6,
            fillPaint,
          );
        }
        for (final nc in [
          Offset(size.width * 0.3, size.height * 0.4),
          Offset(size.width * 0.7, size.height * 0.6),
        ]) {
          canvas.drawCircle(
            nc,
            size.width * 0.2,
            Paint()
              ..color = pal.bladeMid.withOpacity(0.08)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22),
          );
        }

      // ── blue_fire — vertical plasma wave lines ────────────────────────
      case 'blue_fire':
        for (var w = 0; w < 8; w++) {
          final path = Path();
          var first = true;
          for (var py = 0.0; py < size.height; py += 4) {
            final px = size.width * 0.5 +
                math.sin(py * 0.06 + w * 0.7) * size.width * 0.35;
            if (first) { path.moveTo(px, py); first = false; }
            else path.lineTo(px, py);
          }
          canvas.drawPath(
            path,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.4
              ..color = pal.bladeMid.withOpacity(0.10 + w * 0.025),
          );
        }

      // ── hermon_glacier — frost radial cracks + icy center ────────────
      case 'hermon_glacier':
        linePaint
          ..color = pal.bladeMid.withOpacity(0.30)
          ..strokeWidth = 0.7;
        for (var crack = 0; crack < 14; crack++) {
          var angle = crack * math.pi * 2 / 14;
          var cx = center.dx, cy = center.dy;
          final path = Path()..moveTo(cx, cy);
          for (var step = 0; step < 8; step++) {
            angle += (rngA.nextDouble() - 0.5) * 0.4;
            cx += math.cos(angle) * size.width * 0.08;
            cy += math.sin(angle) * size.height * 0.08;
            path.lineTo(cx, cy);
          }
          canvas.drawPath(path, linePaint);
        }
        canvas.drawCircle(
          center,
          size.width * 0.15,
          Paint()
            ..color = Colors.white.withOpacity(0.12)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15),
        );

      // ── oriental_arabesque — 8-pointed star tessellation ─────────────
      case 'oriental_arabesque':
        linePaint
          ..color = pal.rimOuter.withOpacity(0.28)
          ..strokeWidth = 0.9;
        const oaSp = 30.0;
        for (var gx = 0.0; gx < size.width + oaSp; gx += oaSp) {
          for (var gy = 0.0; gy < size.height + oaSp; gy += oaSp) {
            final sc = Offset(gx, gy);
            const sr = oaSp * 0.42;
            for (var pt = 0; pt < 8; pt++) {
              final a1 = pt * math.pi / 4;
              final a2 = a1 + math.pi / 8;
              canvas.drawLine(
                Offset(sc.dx + math.cos(a1) * sr, sc.dy + math.sin(a1) * sr),
                Offset(sc.dx + math.cos(a2) * sr * 0.40,
                    sc.dy + math.sin(a2) * sr * 0.40),
                linePaint,
              );
            }
          }
        }

      // ── ancient_gold_rare — scratch marks + warm glow ────────────────
      case 'ancient_gold_rare':
        linePaint
          ..color = pal.bladeLight.withOpacity(0.15)
          ..strokeWidth = 0.6;
        for (var i = 0; i < 32; i++) {
          final x1 = rngA.nextDouble() * size.width;
          final y1 = rngA.nextDouble() * size.height;
          final len = 15.0 + rngA.nextDouble() * 35;
          final ang = rngA.nextDouble() * math.pi;
          canvas.drawLine(
            Offset(x1, y1),
            Offset(x1 + math.cos(ang) * len, y1 + math.sin(ang) * len),
            linePaint,
          );
        }
        canvas.drawCircle(
          center,
          size.width * 0.20,
          Paint()
            ..color = pal.rimInner.withOpacity(0.12)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
        );

      // ── brushed_titanium — fine horizontal lines + neon stripe ───────
      case 'brushed_titanium':
        linePaint
          ..color = pal.bladeLight.withOpacity(0.10)
          ..strokeWidth = 0.5;
        var bty = 0.0;
        while (bty < size.height) {
          canvas.drawLine(Offset(0, bty), Offset(size.width, bty), linePaint);
          bty += 2.5;
        }
        linePaint
          ..color = pal.rimOuter.withOpacity(0.25)
          ..strokeWidth = 1.5;
        canvas.drawLine(Offset(size.width * 0.08, 0),
            Offset(size.width * 0.92, size.height), linePaint);

      // ── eilat_coral — vertical caustic wave columns ───────────────────
      case 'eilat_coral':
        const ecWaves = 8;
        for (var w = 0; w < ecWaves; w++) {
          final baseX = (size.width / ecWaves) * w;
          final path = Path();
          var first = true;
          for (var py = 0.0; py < size.height; py += 3) {
            final px =
                baseX + math.sin(py * 0.05 + w * 1.3) * size.width * 0.10;
            if (first) { path.moveTo(px, py); first = false; }
            else path.lineTo(px, py);
          }
          canvas.drawPath(
            path,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.0
              ..color = pal.bladeMid.withOpacity(0.22),
          );
        }

      // ── meteor_shower — diagonal streaks + star field ─────────────────
      case 'meteor_shower':
        linePaint
          ..color = pal.bladeLight.withOpacity(0.25)
          ..strokeWidth = 0.8;
        for (var i = 0; i < 22; i++) {
          final x1 = rngA.nextDouble() * size.width * 1.5 - size.width * 0.25;
          final y1 = rngA.nextDouble() * size.height * 0.65;
          final len = 20.0 + rngA.nextDouble() * 55;
          canvas.drawLine(Offset(x1, y1),
              Offset(x1 + len * 0.6, y1 + len), linePaint);
        }
        fillPaint.color = Colors.white.withOpacity(0.70);
        for (var i = 0; i < 35; i++) {
          canvas.drawCircle(
            Offset(rngA.nextDouble() * size.width,
                rngA.nextDouble() * size.height),
            0.8,
            fillPaint,
          );
        }

      // ── PREMIUM ───────────────────────────────────────────────────────

      // ── royal_throne — damask diamond + gold glow ────────────────────
      case 'royal_throne':
        linePaint
          ..color = pal.rimOuter.withOpacity(0.22)
          ..strokeWidth = 0.9;
        const rtS = 40.0;
        for (var x = 0.0; x < size.width + rtS; x += rtS) {
          for (var y = 0.0; y < size.height + rtS; y += rtS) {
            for (final f in [rtS * 0.50, rtS * 0.26]) {
              final dp = Path()
                ..moveTo(x, y - f)
                ..lineTo(x + f, y)
                ..lineTo(x, y + f)
                ..lineTo(x - f, y)
                ..close();
              canvas.drawPath(dp, linePaint);
            }
          }
        }
        canvas.drawCircle(
          center,
          size.width * 0.3,
          Paint()
            ..color = pal.rimOuter.withOpacity(0.10)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28),
        );

      // ── ancient_scroll — parchment text lines + aged cracks ──────────
      case 'ancient_scroll':
        linePaint
          ..color = pal.bladeDark.withOpacity(0.20)
          ..strokeWidth = 0.7;
        for (var ly = 12.0; ly < size.height; ly += 14.0) {
          final lineW = size.width * (0.58 + rngA.nextDouble() * 0.35);
          canvas.drawLine(
            Offset(size.width * 0.06, ly),
            Offset(size.width * 0.06 + lineW, ly),
            linePaint,
          );
        }
        linePaint
          ..color = pal.bladeDark.withOpacity(0.35)
          ..strokeWidth = 0.5;
        for (var crack = 0; crack < 7; crack++) {
          var cangle = crack * math.pi / 3.5;
          var cx = center.dx + rngA.nextDouble() * size.width * 0.5 - size.width * 0.25;
          var cy = center.dy + rngA.nextDouble() * size.height * 0.5 - size.height * 0.25;
          final cp = Path()..moveTo(cx, cy);
          for (var step = 0; step < 6; step++) {
            cangle += (rngA.nextDouble() - 0.5) * 1.0;
            cx += math.cos(cangle) * 14;
            cy += math.sin(cangle) * 14;
            cp.lineTo(cx, cy);
          }
          canvas.drawPath(cp, linePaint);
        }

      // ── jerusalem_of_gold — radial rays + city skyline silhouette ─────
      case 'jerusalem_of_gold':
        linePaint
          ..color = pal.bladeMid.withOpacity(0.18)
          ..strokeWidth = 1.0;
        for (var i = 0; i < 24; i++) {
          final angle = (i / 24) * 2 * math.pi;
          canvas.drawLine(
            center,
            Offset(center.dx + math.cos(angle) * size.width,
                center.dy + math.sin(angle) * size.height),
            linePaint,
          );
        }
        final skylinePath = Path()
          ..moveTo(0, size.height * 0.85);
        const jgX = [0.0, 0.08, 0.15, 0.25, 0.38, 0.50, 0.62, 0.72, 0.82, 0.92, 1.0];
        const jgH = [0.0, 0.12, 0.07, 0.20, 0.05, 0.24, 0.09, 0.14, 0.06, 0.11, 0.0];
        for (var i = 0; i < jgX.length; i++) {
          skylinePath.lineTo(size.width * jgX[i], size.height * (0.85 - jgH[i]));
        }
        skylinePath
          ..lineTo(size.width, size.height)
          ..lineTo(0, size.height)
          ..close();
        canvas.drawPath(
          skylinePath,
          Paint()..color = pal.bladeDark.withOpacity(0.28),
        );

      // ── kotel_stones — limestone block pattern + golden crevice glow ──
      case 'kotel_stones':
        linePaint
          ..color = pal.bladeDark.withOpacity(0.38)
          ..strokeWidth = 1.3;
        const ksRowH = 22.0;
        const ksStoneW = 44.0;
        for (var row = 0; row * ksRowH < size.height; row++) {
          final y = row * ksRowH;
          canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
          final ksOff = (row % 2) * ksStoneW * 0.5;
          for (var x = ksOff; x < size.width; x += ksStoneW) {
            canvas.drawLine(Offset(x, y), Offset(x, y + ksRowH), linePaint);
          }
        }
        for (final glowPt in [
          Offset(size.width * 0.28, size.height * 0.52),
          Offset(size.width * 0.68, size.height * 0.32),
        ]) {
          canvas.drawCircle(
            glowPt,
            size.width * 0.07,
            Paint()
              ..color = pal.rimInner.withOpacity(0.14)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
          );
        }

      // ── anemone_red — large petal ellipses + gold concentric rings ────
      case 'anemone_red':
        const petalN = 6;
        for (var i = 0; i < petalN; i++) {
          final angle = (i / petalN) * 2 * math.pi;
          final pr = size.width * 0.28;
          canvas.save();
          canvas.translate(
            center.dx + math.cos(angle) * pr * 0.5,
            center.dy + math.sin(angle) * pr * 0.5,
          );
          canvas.rotate(angle);
          canvas.drawOval(
            Rect.fromCenter(
                center: Offset.zero, width: pr * 0.55, height: pr * 1.2),
            Paint()..color = pal.bladeLight.withOpacity(0.15),
          );
          canvas.restore();
        }
        linePaint
          ..color = pal.rimOuter.withOpacity(0.18)
          ..strokeWidth = 0.9;
        for (var r = 14.0; r < size.width * 0.6; r += 18) {
          canvas.drawCircle(center, r, linePaint);
        }

      // ── salt_sunset — crystal shimmer dots + radial prismatic lines ───
      case 'salt_sunset':
        for (var i = 0; i < 90; i++) {
          canvas.drawCircle(
            Offset(rngA.nextDouble() * size.width,
                rngA.nextDouble() * size.height),
            0.5 + rngA.nextDouble() * 2.5,
            Paint()
              ..color =
                  Colors.white.withOpacity(0.18 + rngA.nextDouble() * 0.42),
          );
        }
        linePaint
          ..color = pal.rimOuter.withOpacity(0.14)
          ..strokeWidth = 0.7;
        for (var i = 0; i < 16; i++) {
          final angle = (i / 16) * 2 * math.pi;
          canvas.drawLine(
            center,
            Offset(center.dx + math.cos(angle) * size.width,
                center.dy + math.sin(angle) * size.height),
            linePaint,
          );
        }

      // ── royal_sapphire — faceted gem cut lines + central brilliance ───
      case 'royal_sapphire':
        linePaint
          ..color = pal.bladeMid.withOpacity(0.35)
          ..strokeWidth = 0.9;
        for (var i = 0; i < 12; i++) {
          final angle = (i / 12) * 2 * math.pi;
          canvas.drawLine(
            center,
            Offset(center.dx + math.cos(angle) * size.width,
                center.dy + math.sin(angle) * size.height),
            linePaint,
          );
        }
        for (final ep in [
          [Offset.zero, Offset(size.width.toDouble(), size.height.toDouble())],
          [Offset(size.width.toDouble(), 0), Offset(0, size.height.toDouble())],
        ]) {
          canvas.drawLine(ep[0], ep[1],
              linePaint..color = pal.bladeLight.withOpacity(0.15));
        }
        canvas.drawCircle(
          center,
          size.width * 0.07,
          Paint()
            ..color = Colors.white.withOpacity(0.28)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
        );

      // ── lava_core — glowing crack web + intense center ────────────────
      case 'lava_core':
        linePaint
          ..color = pal.rimOuter.withOpacity(0.50)
          ..strokeWidth = 1.5;
        for (var crack = 0; crack < 8; crack++) {
          var angle = crack * math.pi * 2 / 8;
          var cx = center.dx, cy = center.dy;
          final path = Path()..moveTo(cx, cy);
          for (var step = 0; step < 8; step++) {
            angle += (rngA.nextDouble() - 0.5) * 0.7;
            cx += math.cos(angle) * size.width * 0.09;
            cy += math.sin(angle) * size.height * 0.09;
            path.lineTo(cx, cy);
          }
          canvas.drawPath(path, linePaint);
        }
        canvas.drawCircle(
          center,
          size.width * 0.18,
          Paint()
            ..color = pal.rimInner.withOpacity(0.22)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20),
        );

      // ── diamond_shield — Star of David + radial facets ────────────────
      case 'diamond_shield':
        linePaint
          ..color = pal.bladeMid.withOpacity(0.32)
          ..strokeWidth = 0.9;
        final dsR = size.width * 0.36;
        for (var tri = 0; tri < 2; tri++) {
          final triPath = Path();
          for (var pt = 0; pt < 3; pt++) {
            final a = pt * (2 * math.pi / 3) +
                (tri == 0 ? -math.pi / 2 : math.pi / 2);
            final p = Offset(
                center.dx + dsR * math.cos(a), center.dy + dsR * math.sin(a));
            if (pt == 0) triPath.moveTo(p.dx, p.dy);
            else triPath.lineTo(p.dx, p.dy);
          }
          triPath.close();
          canvas.drawPath(triPath, linePaint);
        }
        for (var i = 0; i < 8; i++) {
          final angle = (i / 8) * 2 * math.pi;
          canvas.drawLine(
            center,
            Offset(center.dx + math.cos(angle) * dsR * 1.25,
                center.dy + math.sin(angle) * dsR * 1.25),
            linePaint..color = pal.bladeMid.withOpacity(0.18),
          );
        }
        canvas.drawCircle(
          center,
          size.width * 0.08,
          Paint()
            ..color = Colors.white.withOpacity(0.42)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );

      // ── cyber_future_israel — circuit board traces + Star of David ────
      case 'cyber_future_israel':
        linePaint
          ..color = pal.bladeMid.withOpacity(0.30)
          ..strokeWidth = 0.9;
        const cfG = 24.0;
        for (var x = cfG; x < size.width; x += cfG) {
          for (var y = cfG; y < size.height; y += cfG) {
            if (rngA.nextBool()) {
              canvas.drawLine(Offset(x - cfG, y), Offset(x, y), linePaint);
            } else {
              canvas.drawLine(Offset(x, y - cfG), Offset(x, y), linePaint);
            }
            canvas.drawCircle(Offset(x, y), 1.5,
                Paint()..color = pal.bladeLight.withOpacity(0.40));
          }
        }
        canvas.drawCircle(
          center,
          size.width * 0.15,
          Paint()
            ..color = pal.rimOuter.withOpacity(0.12)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15),
        );

      // ── obsidian — jagged cracks from centre ──────────────────────────
      case 'obsidian':
        linePaint
          ..color = pal.rimInner.withOpacity(0.30)
          ..strokeWidth = 0.9;
        for (var crack = 0; crack < 9; crack++) {
          var angle = crack * math.pi * 2 / 9;
          var x = center.dx;
          var y = center.dy;
          final path = Path()..moveTo(x, y);
          for (var step = 0; step < 10; step++) {
            angle += (rngA.nextDouble() - 0.5) * 0.9;
            x += math.cos(angle) * size.width * 0.095;
            y += math.sin(angle) * size.height * 0.095;
            path.lineTo(x, y);
            if (rngA.nextDouble() < 0.3 && step > 3) {
              final ba = angle + (rngA.nextDouble() - 0.5) * 1.2;
              path
                ..lineTo(
                    x + math.cos(ba) * size.width * 0.055,
                    y + math.sin(ba) * size.height * 0.055)
                ..moveTo(x, y);
            }
          }
          canvas.drawPath(path, linePaint);
        }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = Offset(size.width / 2, size.height / 2);
    final diagonal =
        math.sqrt(size.width * size.width + size.height * size.height);
    final outerRadius = diagonal * 0.74;
    final pal = _palette(cardSkinId);

    canvas.saveLayer(rect, Paint());

    // ── Base: skin image if loaded, otherwise solid colour ────────────────
    if (skinImage != null) {
      // Slice per board tile (whole board = one image) when on a grid.
      final src = gridSize > 1
          ? _skinSliceSrc(skinImage!, index, gridSize)
          : Rect.fromLTWH(
              0, 0, skinImage!.width.toDouble(), skinImage!.height.toDouble());
      canvas.drawImageRect(skinImage!, src, rect, Paint());
    } else {
      canvas.drawRect(rect, Paint()..color = pal.base);
      // Draw per-skin unique pattern (only when no custom image)
      _drawSkinPattern(canvas, size, rect, center, pal);
    }

    // ── Metallic rotating blades (skin colours) ───────────────────────────
    final rotation = progress * math.pi * 0.52;
    final angleStep = (2 * math.pi) / _bladeCount;

    for (int i = 0; i < _bladeCount; i++) {
      final angle = i * angleStep + rotation;
      final nextAngle = angle + angleStep * 1.85;

      final pOuter1 = Offset(
        center.dx + outerRadius * math.cos(angle),
        center.dy + outerRadius * math.sin(angle),
      );
      final pOuter2 = Offset(
        center.dx + outerRadius * math.cos(nextAngle),
        center.dy + outerRadius * math.sin(nextAngle),
      );
      final midAngle = (angle + nextAngle) / 2;
      final controlRadius = outerRadius * 0.78;
      final pControl = Offset(
        center.dx + controlRadius * math.cos(midAngle),
        center.dy + controlRadius * math.sin(midAngle),
      );

      final bladePath = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(pOuter1.dx, pOuter1.dy)
        ..quadraticBezierTo(
            pControl.dx, pControl.dy, pOuter2.dx, pOuter2.dy)
        ..close();

      final gradientAngle = angle + 0.25;
      canvas.drawPath(
        bladePath,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment(
                math.cos(gradientAngle), math.sin(gradientAngle)),
            end: Alignment(math.cos(gradientAngle + math.pi),
                math.sin(gradientAngle + math.pi)),
            colors: [
              pal.bladeLight,
              pal.bladeLight.withOpacity(0.85),
              pal.bladeMid,
              pal.bladeDark,
              pal.bladeShadow,
            ],
            stops: const [0.0, 0.18, 0.42, 0.72, 1.0],
          ).createShader(rect),
      );

      // Thin bright seam on the leading edge
      canvas.drawLine(
        center,
        pOuter1,
        Paint()
          ..color = pal.seam.withOpacity(0.55)
          ..strokeWidth = 0.6,
      );
    }

    // ── Punch iris hole using BlendMode.clear ────────────────────────────
    final holeRadius = progress * outerRadius;
    if (holeRadius > 0) {
      canvas.drawCircle(
          center, holeRadius, Paint()..blendMode = BlendMode.clear);
    }

    canvas.restore();

    // ── Chrome ring at the iris edge (skin-tinted) ───────────────────────
    if (holeRadius > 2 && progress < 0.97) {
      final rimAlpha = (1.0 - progress).clamp(0.0, 1.0);

      canvas.drawCircle(
        center,
        holeRadius + 0.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = pal.rimOuter.withOpacity(rimAlpha * 0.85)
          ..strokeWidth = 1.4,
      );
      canvas.drawCircle(
        center,
        holeRadius - 0.8,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = pal.rimInner.withOpacity(rimAlpha * 0.50)
          ..strokeWidth = 0.7,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AperturePainter old) =>
      old.progress != progress ||
      old.cardSkinId != cardSkinId ||
      old.skinImage != skinImage ||
      old.index != index ||
      old.gridSize != gridSize;
}

// ── Skin colour palette ───────────────────────────────────────────────────────

class _SkinPalette {
  final Color base;
  final Color bladeLight;
  final Color bladeMid;
  final Color bladeDark;
  final Color bladeShadow;
  final Color seam;
  final Color rimOuter;
  final Color rimInner;

  const _SkinPalette({
    required this.base,
    required this.bladeLight,
    required this.bladeMid,
    required this.bladeDark,
    required this.bladeShadow,
    required this.seam,
    required this.rimOuter,
    required this.rimInner,
  });
}

// ── Store preview widget ──────────────────────────────────────────────────────
// Shows the iris nearly closed (8 % open) so the full iris design is visible.

class CardSkinPreview extends StatefulWidget {
  final String cardSkinId;
  final CardSkin? skin;

  const CardSkinPreview({super.key, required this.cardSkinId, this.skin});

  @override
  State<CardSkinPreview> createState() => _CardSkinPreviewState();
}

class _CardSkinPreviewState extends State<CardSkinPreview> {
  ui.Image? _skinImage;

  @override
  void initState() {
    super.initState();
    _loadImage(widget.cardSkinId);
  }

  @override
  void didUpdateWidget(covariant CardSkinPreview old) {
    super.didUpdateWidget(old);
    if (widget.cardSkinId != old.cardSkinId ||
        widget.skin?.coverImageUrl != old.skin?.coverImageUrl) {
      _loadImage(widget.cardSkinId);
    }
  }

  Future<void> _loadImage(String skinId) async {
    final skin = widget.skin ??
        kAvailableCardSkins.firstWhere(
          (s) => s.id == skinId,
          orElse: () => kAvailableCardSkins.first,
        );

    if (skin.coverImageUrl != null) {
      final image = await _fetchNetworkUiImage(skin.coverImageUrl!);
      if (mounted) setState(() => _skinImage = image);
      return;
    }

    if (skin.assetPath == null) {
      if (mounted) setState(() => _skinImage = null);
      return;
    }
    try {
      final data = await rootBundle.load(skin.assetPath!);
      final image = await _decodeUiImage(data.buffer.asUint8List());
      if (mounted) setState(() => _skinImage = image);
    } catch (_) {
      if (mounted) setState(() => _skinImage = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    // If the skin has a real image (asset or admin network cover), show the
    // FULL flat image — exactly how the card back looks closed in-game, and
    // matching the admin preview. (Previously this drew a nearly-closed iris
    // over the image, so image skins looked like the procedural sunburst.)
    // Skins without an image keep the distinctive flat procedural preview.
    if (_skinImage != null) {
      return RepaintBoundary(
        child: CustomPaint(
          painter: _ImageFillPainter(_skinImage!),
        ),
      );
    }
    return RepaintBoundary(
      child: CustomPaint(
        painter: _SkinPreviewPainter(widget.cardSkinId),
      ),
    );
  }
}

// ── Flat skin preview painter ─────────────────────────────────────────────────
// Each skin gets its own visually distinct design — no iris overlay.

class _SkinPreviewPainter extends CustomPainter {
  final String id;
  _SkinPreviewPainter(this.id);

  void _bg(Canvas c, Rect r, List<Color> colors,
      {Alignment b = Alignment.topLeft, Alignment e = Alignment.bottomRight}) {
    c.drawRect(r, Paint()
      ..shader = LinearGradient(colors: colors, begin: b, end: e).createShader(r));
  }

  void _tierBorder(Canvas c, Rect r, Color color, {double width = 1.5}) {
    c.drawRect(
      r.deflate(width * 0.5),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = width,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = Offset(size.width / 2, size.height / 2);
    _paintSkin(canvas, size, rect, center);
  }

  void _paintSkin(Canvas canvas, Size size, Rect rect, Offset center) {
    // Clean, glossy Candy jelly cover — one coherent look for every skin, in a
    // distinct colorway per id. Reads premium in the store preview and as a
    // tiled board in-game (each tile draws its own self-contained jelly).
    final cw = _kJellyCover[id] ?? const [Color(0xFF7B3FD1), Color(0xFF3A1B6E)];
    final light = cw[0], dark = cw[1];

    // Base vertical jelly gradient.
    final gloss = Color.lerp(light, Colors.white, 0.18)!;
    _bg(canvas, rect, [gloss, light, dark],
        b: Alignment.topCenter, e: Alignment.bottomCenter);

    // Top glossy sheen over the upper ~48%.
    final sheenRect = Rect.fromLTWH(0, 0, size.width, size.height * 0.48);
    canvas.drawRect(
      sheenRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white.withOpacity(0.30), Colors.white.withOpacity(0)],
        ).createShader(sheenRect),
    );

    // Soft bottom inner shadow for depth.
    final shadeRect = Rect.fromLTWH(
        0, size.height * 0.6, size.width, size.height * 0.4);
    canvas.drawRect(
      shadeRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black.withOpacity(0), Colors.black.withOpacity(0.20)],
        ).createShader(shadeRect),
    );

    // Quality escalates with price tier: rare skins add a soft sparkle, premium
    // skins add a bright gold gleam + gold sparkles + a gold rim, so pricier
    // covers read as clearly superior.
    final price = kAvailableCardSkins
        .firstWhere((s) => s.id == id,
            orElse: () => const CardSkin(id: '', name: '', price: 0))
        .price;
    final isRare = price >= 200 && price < 1000;
    final isPremium = price >= 1000;

    // Diagonal light streak — stronger for premium (a real gleam).
    final streak = Paint()
      ..color = Colors.white.withOpacity(isPremium ? 0.16 : 0.06)
      ..style = PaintingStyle.fill;
    final sp = Path()
      ..moveTo(size.width * 0.05, size.height)
      ..lineTo(size.width * 0.45, 0)
      ..lineTo(size.width * 0.62, 0)
      ..lineTo(size.width * 0.22, size.height)
      ..close();
    canvas.drawPath(sp, streak);

    // Sparkles (static): a few for rare, a gold cluster for premium.
    if (isRare || isPremium) {
      final rnd = math.Random(id.hashCode);
      final n = isPremium ? 7 : 3;
      final spColor = isPremium ? const Color(0xFFFFE9A8) : Colors.white;
      for (var i = 0; i < n; i++) {
        final o = Offset(size.width * (0.15 + rnd.nextDouble() * 0.7),
            size.height * (0.12 + rnd.nextDouble() * 0.6));
        final r = size.width * (isPremium ? 0.07 : 0.05) * (0.7 + rnd.nextDouble() * 0.6);
        final p = Paint()
          ..color = spColor.withOpacity(isPremium ? 0.85 : 0.55)
          ..strokeWidth = math.max(0.8, r * 0.22)
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(Offset(o.dx, o.dy - r), Offset(o.dx, o.dy + r), p);
        canvas.drawLine(Offset(o.dx - r, o.dy), Offset(o.dx + r, o.dy), p);
        canvas.drawCircle(o, r * 0.28, Paint()..color = spColor.withOpacity(isPremium ? 0.9 : 0.6));
      }
    }

    // Rim — gold and slightly thicker for premium, else a thin bright rim.
    _tierBorder(
      canvas,
      rect,
      isPremium ? const Color(0xFFFFD84D).withOpacity(0.75) : Colors.white.withOpacity(0.22),
      width: isPremium ? 2.0 : 1.4,
    );
  }

  @override
  bool shouldRepaint(covariant _SkinPreviewPainter o) => o.id != id;
}
