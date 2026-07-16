import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Small "מה בתמונה?" logo pill, watermarked onto any image or screenshot the
/// app lets a player save or share, so the app is identifiable wherever the
/// image ends up.
class AppLogoBadge extends StatelessWidget {
  const AppLogoBadge();

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

/// Small scannable QR badge encoding a store download link, so a saved or
/// shared screenshot carries a working download link with it — a gallery
/// save or an image share can't attach a text caption the way a share-sheet
/// message can, so baking the link into the image is the only way it
/// travels with it.
class AppQrBadge extends StatelessWidget {
  final String storeUrl;
  final double size;

  const AppQrBadge({required this.storeUrl, this.size = 46});

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
        data: storeUrl,
        size: size,
        padding: EdgeInsets.zero,
        gapless: true,
      ),
    );
  }
}
