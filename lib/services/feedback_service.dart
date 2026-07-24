import 'package:flutter/services.dart';
import 'settings_service.dart';
import 'sfx_service.dart';

class FeedbackService {
  const FeedbackService._();

  static bool get _vibrate => SettingsService.instance.vibrationEnabled;

  static void click() {
    if (_vibrate) HapticFeedback.lightImpact();
    // Also give the tap a soft click sound (honors the sfx-volume setting).
    SfxService.instance.uiClick();
  }

  static void reveal() {
    if (_vibrate) HapticFeedback.mediumImpact();
  }

  static void success() {
    if (_vibrate) HapticFeedback.heavyImpact();
  }

  static void error() {
    if (_vibrate) HapticFeedback.mediumImpact();
  }
}
