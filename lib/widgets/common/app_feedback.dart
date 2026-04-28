import 'package:flutter/services.dart';

class AppFeedback {
  const AppFeedback._();

  static void tap() {
    HapticFeedback.selectionClick();
    SystemSound.play(SystemSoundType.click);
  }

  static void selection() => tap();
}
