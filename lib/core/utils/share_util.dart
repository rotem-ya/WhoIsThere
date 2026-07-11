import 'package:flutter/widgets.dart';
import 'package:share_plus/share_plus.dart';

/// Share.share wrapper that always passes sharePositionOrigin — on iPad the
/// share sheet is a popover and a missing/zero origin rect crashes with
/// "sharePositionOrigin: argument must be set" (seen in crash reports).
/// Anchors to the caller's widget when possible, else to the screen center.
Future<void> shareText(BuildContext context, String text, {String? subject}) {
  Rect origin;
  final box = context.findRenderObject() as RenderBox?;
  if (box != null && box.hasSize && box.size != Size.zero) {
    origin = box.localToGlobal(Offset.zero) & box.size;
  } else {
    final size = MediaQuery.sizeOf(context);
    origin = Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2), width: 1, height: 1);
  }
  return Share.share(text, subject: subject, sharePositionOrigin: origin);
}
