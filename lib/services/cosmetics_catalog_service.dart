import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/avatar_frame.dart';
import '../models/board_skin.dart';
import '../models/name_style.dart';
import '../models/win_effect.dart';
import 'qa_logger_service.dart';

/// Live store-cosmetics catalog — lets the ADMIN app add/edit/hide avatar
/// frames, name styles, win effects and board skins without an app release,
/// mirroring the content-manifest architecture:
///
///   Firestore doc `cosmetics_catalog/catalog_v1` (read: public, write: admin):
///     { frames: [...], nameStyles: [...], winEffects: [...], boardSkins: [...] }
///
/// Each entry carries the same fields as the bundled model (colors as hex
/// strings). An entry whose id matches a bundled item REPLACES it (edit /
/// price change / hide via active:false); a new id is appended to the store.
///
/// The merged lists are pushed into the model files' `liveX` hooks so every
/// existing lookup (`frameFor`, `boardSkinFor`, ...) and store screen picks
/// them up with no call-site changes. Offline-safe: the last catalog is cached
/// in SharedPreferences and applied instantly on startup; on any failure the
/// game silently runs on the bundled catalog.
class CosmeticsCatalogService {
  CosmeticsCatalogService._();
  static final CosmeticsCatalogService instance = CosmeticsCatalogService._();

  static const _docPath = 'cosmetics_catalog/catalog_v1';
  static const _prefsKey = 'cosmetics_catalog_json';

  /// Bumped on every applied update so open screens can rebuild.
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _liveSub;

  /// Applies the last cached catalog (instant, offline-safe). Call at startup.
  Future<void> loadCached() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.isEmpty) return;
      _apply(jsonDecode(raw) as Map<String, dynamic>, persist: false);
      QaLoggerService.instance.log('COSMETICS', 'CATALOG_CACHE_APPLIED');
    } catch (e) {
      QaLoggerService.instance.log('COSMETICS', 'CATALOG_CACHE_ERROR $e');
    }
  }

  /// Subscribes live so admin edits appear immediately. Self-healing: a
  /// Firestore snapshot stream terminates after an error, so re-subscribe.
  void startRealtime() {
    if (_liveSub != null) return;
    _liveSub = FirebaseFirestore.instance
        .doc(_docPath)
        .snapshots()
        .listen((snap) {
      if (!snap.exists) return; // no catalog yet — bundled only
      _apply(snap.data() ?? {}, persist: true);
      QaLoggerService.instance.log('COSMETICS', 'CATALOG_LIVE_APPLIED');
    }, onError: (e) {
      QaLoggerService.instance.log('COSMETICS', 'CATALOG_LIVE_ERROR $e');
      _liveSub?.cancel();
      _liveSub = null;
      Future.delayed(const Duration(seconds: 25), () {
        if (_liveSub == null) startRealtime();
      });
    });
  }

  // ── Parsing + merge ────────────────────────────────────────────────────────

  void _apply(Map<String, dynamic> data, {required bool persist}) {
    liveAvatarFrames = _merge<AvatarFrame>(
        kAvatarFrames, data['frames'], _parseFrame, (x) => x.id);
    liveNameStyles = _merge<NameStyle>(
        kNameStyles, data['nameStyles'], _parseNameStyle, (x) => x.id);
    liveWinEffects = _merge<WinEffect>(
        kWinEffects, data['winEffects'], _parseWinEffect, (x) => x.id);
    liveBoardSkins = _merge<BoardSkin>(
        kBoardSkins, data['boardSkins'], _parseBoardSkin, (x) => x.id);
    revision.value++;

    if (persist) {
      // Persist only the raw remote arrays (compact + timestamp-free).
      unawaited(SharedPreferences.getInstance().then((prefs) {
        final compact = <String, dynamic>{
          for (final k in ['frames', 'nameStyles', 'winEffects', 'boardSkins'])
            if (data[k] is List) k: data[k],
        };
        return prefs.setString(_prefsKey, jsonEncode(compact));
      }).catchError((_) => false));
    }
  }

  /// Bundled list + remote entries: same id replaces, new id appends.
  List<T> _merge<T>(List<T> bundled, dynamic remoteRaw,
      T? Function(Map<String, dynamic>) parse, String Function(T) idOf) {
    if (remoteRaw is! List) return bundled;
    final remote = <String, T>{};
    for (final e in remoteRaw) {
      if (e is! Map) continue;
      final item = parse(Map<String, dynamic>.from(e));
      if (item != null) remote[idOf(item)] = item;
    }
    if (remote.isEmpty) return bundled;
    final out = <T>[
      for (final b in bundled) remote.remove(idOf(b)) ?? b,
      ...remote.values,
    ];
    return out;
  }

  static List<Color> _colors(dynamic raw) {
    if (raw is! List) return const [];
    final out = <Color>[];
    for (final c in raw) {
      final color = _hexColor(c);
      if (color != null) out.add(color);
    }
    return out;
  }

  static Color? _hexColor(dynamic raw) {
    if (raw is! String) return null;
    var h = raw.replaceAll('#', '').trim();
    if (h.length == 6) h = 'FF$h';
    if (h.length != 8) return null;
    final v = int.tryParse(h, radix: 16);
    return v == null ? null : Color(v);
  }

  static String? _str(Map<String, dynamic> m, String k) {
    final v = m[k];
    return v is String && v.trim().isNotEmpty ? v.trim() : null;
  }

  static int _int(Map<String, dynamic> m, String k, int fallback) {
    final v = m[k];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return fallback;
  }

  static bool _bool(Map<String, dynamic> m, String k, bool fallback) =>
      m[k] is bool ? m[k] as bool : fallback;

  AvatarFrame? _parseFrame(Map<String, dynamic> m) {
    final id = _str(m, 'id');
    if (id == null) return null;
    return AvatarFrame(
      id: id,
      name: _str(m, 'name') ?? id,
      price: _int(m, 'price', 0),
      colors: _colors(m['colors']),
      glow: _bool(m, 'glow', false),
      studs: _int(m, 'studs', 0),
      doubleRing: _bool(m, 'doubleRing', false),
      active: _bool(m, 'active', true),
    );
  }

  NameStyle? _parseNameStyle(Map<String, dynamic> m) {
    final id = _str(m, 'id');
    if (id == null) return null;
    return NameStyle(
      id: id,
      name: _str(m, 'name') ?? id,
      price: _int(m, 'price', 0),
      colors: _colors(m['colors']),
      active: _bool(m, 'active', true),
    );
  }

  WinEffect? _parseWinEffect(Map<String, dynamic> m) {
    final id = _str(m, 'id');
    if (id == null) return null;
    return WinEffect(
      id: id,
      name: _str(m, 'name') ?? id,
      price: _int(m, 'price', 0),
      colors: _colors(m['colors']),
      emoji: _str(m, 'emoji'),
      motion: WinEffectMotion.values.asNameMap()[_str(m, 'motion')] ??
          WinEffectMotion.fall,
      shape: WinEffectShape.values.asNameMap()[_str(m, 'shape')] ??
          WinEffectShape.rect,
      active: _bool(m, 'active', true),
    );
  }

  BoardSkin? _parseBoardSkin(Map<String, dynamic> m) {
    final id = _str(m, 'id');
    if (id == null) return null;
    return BoardSkin(
      id: id,
      name: _str(m, 'name') ?? id,
      price: _int(m, 'price', 0),
      colors: _colors(m['colors']),
      imageUrl: _str(m, 'imageUrl'),
      active: _bool(m, 'active', true),
    );
  }
}
