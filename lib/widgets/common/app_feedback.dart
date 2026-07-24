import 'package:flutter/services.dart';

import '../../services/settings_service.dart';
import '../../services/sfx_service.dart';

/// Unified tactile + audio feedback for UI interactions. Haptics honor the
/// user's vibration setting (previously they fired unconditionally, so turning
/// vibration off in Settings had no effect on buttons); the custom click sounds
/// route through [SfxService], which honors the sfx-volume setting.
class AppFeedback {
  const AppFeedback._();

  static void _haptic(void Function() fire) {
    if (SettingsService.instance.vibrationEnabled) fire();
  }

  static void tap() {
    _haptic(HapticFeedback.selectionClick);
    SfxService.instance.uiClick();
  }

  static void selection() => tap();

  static void primary() {
    _haptic(HapticFeedback.mediumImpact);
    SfxService.instance.uiPrimary();
  }

  static void back() {
    _haptic(HapticFeedback.selectionClick);
    SfxService.instance.uiBack();
  }

  static void reveal() {
    _haptic(HapticFeedback.lightImpact);
    SystemSound.play(SystemSoundType.click);
  }

  static void success() {
    _haptic(HapticFeedback.heavyImpact);
    SystemSound.play(SystemSoundType.alert);
  }

  static void warning() {
    _haptic(HapticFeedback.vibrate);
    SystemSound.play(SystemSoundType.alert);
  }

  static void confirm() => success();

  static void error() => warning();

  static void vote() => primary();
}
