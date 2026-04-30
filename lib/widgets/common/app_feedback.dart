import 'package:flutter/services.dart';

class AppFeedback {
  const AppFeedback._();

  static void tap() {
    HapticFeedback.selectionClick();
    SystemSound.play(SystemSoundType.click);
  }

  static void selection() => tap();

  static void primary() {
    HapticFeedback.mediumImpact();
    SystemSound.play(SystemSoundType.click);
  }

  static void reveal() {
    HapticFeedback.lightImpact();
    SystemSound.play(SystemSoundType.click);
  }

  static void success() {
    HapticFeedback.heavyImpact();
    SystemSound.play(SystemSoundType.alert);
  }

  static void warning() {
    HapticFeedback.vibrate();
    SystemSound.play(SystemSoundType.alert);
  }

  static void confirm() => success();

  static void error() => warning();

  static void vote() => primary();
}
