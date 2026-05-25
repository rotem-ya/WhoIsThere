import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static SettingsService? _instance;

  static SettingsService get instance {
    assert(_instance != null, 'Call SettingsService.init() before use');
    return _instance!;
  }

  static Future<SettingsService> init() async {
    final prefs = await SharedPreferences.getInstance();
    _instance = SettingsService._(prefs);
    return _instance!;
  }

  static const _kMusic = 'settings_music_volume';
  static const _kSfx = 'settings_sfx_volume';
  static const _kVibration = 'settings_vibration';

  final SharedPreferences _prefs;
  SettingsService._(this._prefs);

  double get musicVolume => (_prefs.getDouble(_kMusic) ?? 1.0).clamp(0.0, 1.0);
  double get sfxVolume => (_prefs.getDouble(_kSfx) ?? 1.0).clamp(0.0, 1.0);
  bool get vibrationEnabled => _prefs.getBool(_kVibration) ?? true;

  Future<void> setMusicVolume(double v) =>
      _prefs.setDouble(_kMusic, v.clamp(0.0, 1.0));
  Future<void> setSfxVolume(double v) =>
      _prefs.setDouble(_kSfx, v.clamp(0.0, 1.0));
  Future<void> setVibrationEnabled(bool v) => _prefs.setBool(_kVibration, v);
}
