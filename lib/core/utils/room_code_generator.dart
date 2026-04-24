import 'dart:math';
import '../constants/game_constants.dart';

class RoomCodeGenerator {
  static const _chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static final _random = Random.secure();

  static String generate() {
    return List.generate(
      GameConstants.roomCodeLength,
      (_) => _chars[_random.nextInt(_chars.length)],
    ).join();
  }
}
