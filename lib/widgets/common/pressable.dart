import 'package:flutter/material.dart';

import 'app_feedback.dart';

/// Wraps tappable content with a quick press-scale + tap feedback (haptic +
/// soft click via [AppFeedback]), so cards and tiles feel physical when
/// touched and spring back on release. Drop-in around any card/tile that
/// currently uses a bare GestureDetector/InkWell.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;

  /// Play the tap feedback on press. Turn off if the [onTap] already triggers
  /// its own AppFeedback so the click doesn't double up.
  final bool feedback;

  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.pressedScale = 0.96,
    this.feedback = true,
  });

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pressed = false;

  void _set(bool v) {
    if (widget.onTap == null) return;
    if (_pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => _set(true) : null,
      onTapUp: enabled ? (_) => _set(false) : null,
      onTapCancel: enabled ? () => _set(false) : null,
      onTap: !enabled
          ? null
          : () {
              if (widget.feedback) AppFeedback.tap();
              widget.onTap!.call();
            },
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1.0,
        duration: Duration(milliseconds: _pressed ? 90 : 150),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
