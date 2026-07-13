import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import '../../../models/game_image_model.dart';

/// Post-match gallery: every image played this match (all heat/proverbs
/// rounds, or just the one round for a normal game), swipeable, each with its
/// name/answer and any facts + source, and a save button that shares the
/// image with the app's logo watermarked onto it.
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

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final boundary = _boundaryKeys[_currentIndex].currentContext
          ?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('boundary not ready');
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData?.buffer.asUint8List();
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('השמירה נכשלה, נסה שוב')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
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
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFD4AF37),
                    disabledBackgroundColor:
                        const Color(0xFFD4AF37).withOpacity(0.4),
                    foregroundColor: const Color(0xFF07101F),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    textStyle: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.2, color: Color(0xFF07101F)),
                        )
                      : const Icon(Icons.ios_share_rounded),
                  label: const Text('שמור תמונה'),
                ),
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
