import 'package:flutter/services.dart';

import '../../services/sfx_service.dart';

class AppFeedback {
  const AppFeedback._();

  static void tap() {
    HapticFeedback.selectionClick();
    SfxService.instance.uiClick();
  }

  static void selection() => tap();

  static void primary() {
    HapticFeedback.mediumImpact();
    SfxService.instance.uiPrimary();
  }

  static void back() {
    HapticFeedback.selectionClick();
    SfxService.instance.uiBack();
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
