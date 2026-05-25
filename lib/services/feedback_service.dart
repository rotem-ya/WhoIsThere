import 'package:flutter/services.dart';
import 'settings_service.dart';

class FeedbackService {
  const FeedbackService._();

  static bool get _vibrate => SettingsService.instance.vibrationEnabled;

  static void click() {
    if (_vibrate) HapticFeedback.lightImpact();
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
