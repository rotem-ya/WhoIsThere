import 'package:flutter/services.dart';

class FeedbackService {
  const FeedbackService._();

  static void click() {
    HapticFeedback.lightImpact();
  }

  static void reveal() {
    HapticFeedback.mediumImpact();
  }

  static void success() {
    HapticFeedback.heavyImpact();
  }

  static void error() {
    HapticFeedback.mediumImpact();
  }
}
