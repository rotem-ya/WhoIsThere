import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/rewards_config.dart';
import 'qa_logger_service.dart';

/// Live rewards configuration — lets the ADMIN app manage the spin wheel
/// (segments/weights), Happy Hour, and the daily/weekly quest list without an
/// app release, mirroring [CosmeticsCatalogService]:
///
///   Firestore doc `rewards_config/config_v1` (read: public, write: admin).
///
/// Offline-safe: the last config is cached in SharedPreferences and applied
/// instantly on startup; on any failure the game silently runs on the embedded
/// defaults ([RewardsConfig.fallback]). See docs/REWARDS_HUB_DESIGN.md.
class RewardsConfigService {
  RewardsConfigService._();
  static final RewardsConfigService instance = RewardsConfigService._();

  static const _docPath = 'rewards_config/config_v1';
  static const _prefsKey = 'rewards_config_json';

  RewardsConfig _config = RewardsConfig.fallback;
  RewardsConfig get config => _config;

  /// Bumped on every applied update so open screens can rebuild.
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _liveSub;

  /// The coin multiplier in effect right now (1 unless Happy Hour is active).
  int get happyHourMultiplier =>
      _config.happyHour.multiplierAt(DateTime.now().toUtc());
  bool get happyHourActive =>
      _config.happyHour.activeAt(DateTime.now().toUtc());
  String get happyHourLabel => _config.happyHour.label;

  /// Applies the last cached config (instant, offline-safe). Call at startup.
  Future<void> loadCached() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.isEmpty) return;
      _apply(jsonDecode(raw) as Map<String, dynamic>, persist: false);
      QaLoggerService.instance.log('REWARDS', 'CONFIG_CACHE_APPLIED');
    } catch (e) {
      QaLoggerService.instance.log('REWARDS', 'CONFIG_CACHE_ERROR $e');
    }
  }

  /// Subscribes live so admin edits appear immediately. Self-healing.
  void startRealtime() {
    if (_liveSub != null) return;
    _liveSub =
        FirebaseFirestore.instance.doc(_docPath).snapshots().listen((snap) {
      if (!snap.exists) return; // no config yet — embedded defaults
      _apply(snap.data() ?? {}, persist: true);
      QaLoggerService.instance.log('REWARDS', 'CONFIG_LIVE_APPLIED');
    }, onError: (e) {
      QaLoggerService.instance.log('REWARDS', 'CONFIG_LIVE_ERROR $e');
      _liveSub?.cancel();
      _liveSub = null;
    });
  }

  void _apply(Map<String, dynamic> map, {required bool persist}) {
    try {
      _config = RewardsConfig.fromMap(map);
      revision.value++;
      if (persist) {
        SharedPreferences.getInstance()
            .then((p) => p.setString(_prefsKey, jsonEncode(map)))
            .ignore();
      }
    } catch (e) {
      QaLoggerService.instance.log('REWARDS', 'CONFIG_APPLY_ERROR $e');
      // Keep whatever config we had; never crash on a malformed doc.
    }
  }
}
