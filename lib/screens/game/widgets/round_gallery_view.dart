import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_constants.dart';
import '../../../models/game_image_model.dart';

/// Post-match gallery: every image played this match (all heat/proverbs
/// rounds, or just the one round for a normal game), swipeable, each with its
/// name/answer and any facts + source. "שמור לגלריה" saves the image (with
/// the app's logo + a download-QR watermarked onto it) straight to the
/// device's photo gallery via the gal plugin; "שתף" opens the native share
/// sheet instead. The QR encodes this device's platform store link, so
/// whoever the saved/shared photo reaches can scan straight to the download
/// page — the whole point of carrying it on the image rather than as a
/// separate caption, which a gallery save can't attach anyway.
class RoundGalleryView extends StatefulWidget {
  final List<GameImageModel> images;
  final String answerLabel;
  final int initialIndex;

  const RoundGalleryView({
    super.key,
    required this.images,
    required this.answerLabel,
    this.initialIndex = 0,
  });

  @override
  State<RoundGalleryView> createState() => _RoundGalleryViewState();
}

class _RoundGalleryViewState extends State<RoundGalleryView> {
  late final PageController _pageController;
  late final List<GlobalKey> _boundaryKeys;
  late int _currentIndex;
  bool _saving = false;
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.images.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
    _boundaryKeys = List.generate(widget.images.length, (_) => GlobalKey());
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<Uint8List?> _captureCurrentBytes() async {
    final boundary = _boundaryKeys[_currentIndex].currentContext
        ?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _saveToGallery() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final bytes = await _captureCurrentBytes();
      if (bytes == null) throw Exception('encode failed');
      final hasAccess = await Gal.hasAccess() || await Gal.requestAccess();
      if (!hasAccess) {
        _toast('אין הרשאה לשמור לגלריה');
        return;
      }
      final name = widget.images[_currentIndex].answer;
      await Gal.putImageBytes(bytes, name: 'whoisthere_$name');
      _toast('התמונה נשמרה בגלריה 🖼️');
    } catch (_) {
      _toast('השמירה נכשלה, נסה שוב');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final bytes = await _captureCurrentBytes();
      if (bytes == null) throw Exception('encode failed');
      final name = widget.images[_currentIndex].answer;
      await Share.shareXFiles(
        [
          XFile.fromData(
            bytes,
            mimeType: 'image/png',
            name: 'whoisthere_$name.png',
          ),
        ],
        subject: 'מה בתמונה?',
      );
    } catch (_) {
      _toast('השיתוף נכשל, נסה שוב');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07101F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF07101F),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          '${_currentIndex + 1} / ${widget.images.length}',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                reverse: true, // RTL: swipe right = next
                itemCount: widget.images.length,
                onPageChanged: (i) => setState(() => _currentIndex = i),
                itemBuilder: (context, i) => _GalleryPage(
                  image: widget.images[i],
                  answerLabel: widget.answerLabel,
                  boundaryKey: _boundaryKeys[i],
                ),
              ),
            ),
            if (widget.images.length > 1)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(widget.images.length, (i) {
                    final active = i == _currentIndex;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: active ? 18 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: active
                            ? const Color(0xFFD4AF37)
                            : Colors.white.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _saveToGallery,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFD4AF37),
                          disabledBackgroundColor:
                              const Color(0xFFD4AF37).withOpacity(0.4),
                          foregroundColor: const Color(0xFF07101F),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          textStyle: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w900),
                        ),
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.2, color: Color(0xFF07101F)),
                              )
                            : const Icon(Icons.download_rounded),
                        label: const Text('שמור לגלריה'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 52,
                    height: 52,
                    child: OutlinedButton(
                      onPressed: _sharing ? null : _share,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF87CEEB),
                        side: BorderSide(
                            color: const Color(0xFF87CEEB).withOpacity(0.7)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        padding: EdgeInsets.zero,
                      ),
                      child: _sharing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.2, color: Color(0xFF87CEEB)),
                            )
                          : const Icon(Icons.ios_share_rounded),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GalleryPage extends StatelessWidget {
  final GameImageModel image;
  final String answerLabel;
  final GlobalKey boundaryKey;

  const _GalleryPage({
    required this.image,
    required this.answerLabel,
    required this.boundaryKey,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Column(
        children: [
          RepaintBoundary(
            key: boundaryKey,
            child: AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (image.imageUrl.startsWith('assets/'))
                      Image.asset(image.imageUrl, fit: BoxFit.cover)
                    else
                      CachedNetworkImage(
                        imageUrl: image.imageUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => const ColoredBox(
                          color: Color(0xFF0D1E30),
                          child: Center(
                            child: Text('🏆', style: TextStyle(fontSize: 40)),
                          ),
                        ),
                      ),
                    const Positioned(
                      left: 10,
                      bottom: 10,
                      child: _LogoBadge(),
                    ),
                    const Positioned(
                      right: 10,
                      bottom: 10,
                      child: _QrBadge(),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '$answerLabel: ${image.answer}',
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            style: const TextStyle(
              color: Color(0xFFD4AF37),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (image.facts.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF0E1E33).withOpacity(0.7),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF2080C0).withOpacity(0.35)),
              ),
              child: Text(
                image.facts.first,
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.85),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ),
          ],
          if (image.source != null && image.source!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              image.source!,
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LogoBadge extends StatelessWidget {
  const _LogoBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: Image.asset(
              'assets/icons/icon.png',
              width: 16,
              height: 16,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 5),
          const Text(
            'מה בתמונה?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small scannable QR badge encoding this device's store link, so a saved or
/// shared photo carries a working download link with it (a gallery save
/// can't attach a text caption the way a share-sheet message can).
class _QrBadge extends StatelessWidget {
  const _QrBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 6,
          ),
        ],
      ),
      child: QrImageView(
        data: AppConstants.storeUrl(),
        size: 46,
        padding: EdgeInsets.zero,
        gapless: true,
      ),
    );
  }
}
