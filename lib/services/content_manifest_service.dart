import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/game_constants.dart';
import '../models/game_image_model.dart';
import 'qa_logger_service.dart';

/// One entry in the remote content manifest. Mirrors the Firestore map written
/// by the admin app (content_manifest/places_v1).
class _ManifestPlace {
  final String id;
  final bool isActive;
  final String source; // 'bundled' | 'remote'
  final String category; // content category id (defaults to israel_places)
  final String? imageUrl;
  final int? imageVersion;
  final String nameHe;
  final String answerHe;
  final List<String> aliases;
  final List<String> facts;

  _ManifestPlace({
    required this.id,
    required this.isActive,
    required this.source,
    required this.category,
    this.imageUrl,
    this.imageVersion,
    required this.nameHe,
    required this.answerHe,
    required this.aliases,
    required this.facts,
  });

  bool get isRemote => source == 'remote';

  /// Cache-busting URL: a changed imageVersion yields a new key, so the
  /// CachedNetworkImage cache (and our pre-warm) re-downloads automatically.
  String? get effectiveUrl {
    final u = imageUrl;
    if (u == null || u.isEmpty) return null;
    if (imageVersion == null) return u;
    return u.contains('?') ? '$u&v=$imageVersion' : '$u?v=$imageVersion';
  }

  static _ManifestPlace? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final id = (raw['id'] ?? '').toString();
    if (id.isEmpty) return null;
    final name = (raw['nameHe'] ?? raw['name_he'] ?? '').toString();
    return _ManifestPlace(
      id: id,
      isActive: raw['isActive'] != false, // default active unless explicitly false
      source: (raw['source'] ?? 'bundled').toString(),
      category: (raw['category'] ?? 'israel_places').toString(),
      imageUrl: (raw['imageUrl'] as String?)?.trim().isNotEmpty == true
          ? (raw['imageUrl'] as String).trim()
          : null,
      imageVersion: (raw['imageVersion'] as num?)?.toInt(),
      nameHe: name,
      answerHe: (raw['answerHe'] ?? raw['answer_he'] ?? name).toString(),
      aliases: _strList(raw['aliasesHe'] ?? raw['aliases_he']),
      facts: _strList(raw['facts']),
    );
  }

  static List<String> _strList(Object? v) =>
      v is List ? v.map((e) => e.toString()).toList() : const [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'isActive': isActive,
        'source': source,
        'category': category,
        if (imageUrl != null) 'imageUrl': imageUrl,
        if (imageVersion != null) 'imageVersion': imageVersion,
        'nameHe': nameHe,
        'answerHe': answerHe,
        'aliasesHe': aliases,
        'facts': facts,
      };
}

/// Hybrid content manifest: bundled places stay in the app; the admin app can
/// toggle any place active/inactive and add new "remote" places (image in
/// Firebase Storage) — all via one Firestore document, fetched once at startup.
///
/// Design guarantees:
///  • Never blocks startup or game start — best-effort, short timeouts.
///  • Offline-safe — last manifest is persisted; remote images use the same
///    cache CachedNetworkImage reads, so cached places work with no network.
///  • Safety net — if the manifest is missing/empty, the game falls back to
///    bundled defaults (handled by RoomService).
class ContentManifestService {
  ContentManifestService._();
  static final ContentManifestService instance = ContentManifestService._();

  static const _prefsKey = 'content_manifest_v1';
  static const _topicsPrefsKey = 'content_topics_active_v1';
  static const _docPath = 'content_manifest/places_v1';

  // id → isActive override (covers bundled + remote).
  final Map<String, bool> _activeById = {};
  // category id → remote places active AND with image cached, in that category.
  final Map<String, List<GameImageModel>> _remoteByCategory = {};
  // category id → active flag (manifest `topicsActive` map). A whole topic
  // ("חי צומח דומם") can be hidden by the admin without touching its places.
  final Map<String, bool> _topicsActive = {};
  bool _loaded = false;

  bool get isLoaded => _loaded;
  bool get hasManifest => _activeById.isNotEmpty;

  int get _remoteReadyCount =>
      _remoteByCategory.values.fold(0, (n, l) => n + l.length);

  /// Active-state for a place id. Returns the manifest override when present,
  /// otherwise [localDefault] (so bundled behavior is unchanged without a
  /// manifest). Bundled places not listed in the manifest keep their default.
  bool isActive(String id, {required bool localDefault}) =>
      _activeById[id] ?? localDefault;

  /// Active-state for a whole category/topic. A category absent from the
  /// manifest `topicsActive` map counts as active (backward compatible — no
  /// map means every topic shows, exactly like before).
  bool isCategoryActive(String categoryId) => _topicsActive[categoryId] ?? true;

  /// Remote places ready to play (active + image cached) in [categoryId].
  /// Copy, never null.
  List<GameImageModel> availableRemoteImages(
          [String categoryId = 'israel_places']) =>
      List<GameImageModel>.unmodifiable(_remoteByCategory[categoryId] ?? const []);

  /// Instant, offline load from the last persisted manifest. Call at startup
  /// before [sync] so the previous state applies with zero network wait.
  Future<void> loadCached() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _applyTopics(prefs.getString(_topicsPrefsKey));
      final raw = prefs.getString(_prefsKey);
      if (raw == null) return;
      final places = _parsePlaces(raw);
      await _apply(places, downloadMissing: false);
      QaLoggerService.instance.log('CONTENT',
          'MANIFEST_CACHE_LOADED places=${places.length} remoteReady=${_remoteReadyCount}');
    } catch (e) {
      QaLoggerService.instance.log('CONTENT', 'MANIFEST_CACHE_ERROR $e');
    }
  }

  /// Best-effort startup sync: one Firestore read, persist, then pre-warm any
  /// active remote images that aren't cached yet. Fully background-safe.
  Future<void> sync() async {
    try {
      final snap = await FirebaseFirestore.instance
          .doc(_docPath)
          .get()
          .timeout(const Duration(seconds: 6));
      if (!snap.exists) {
        QaLoggerService.instance.log('CONTENT', 'MANIFEST_NONE (no doc)');
        _loaded = true;
        return;
      }
      final data = snap.data() ?? {};
      final placesRaw = data['places'];
      final places = (placesRaw is List)
          ? placesRaw.map(_ManifestPlace.tryParse).whereType<_ManifestPlace>().toList()
          : <_ManifestPlace>[];

      // Whole-topic active flags (optional; absent map = every topic active).
      final topics = <String, bool>{};
      final topicsRaw = data['topicsActive'];
      if (topicsRaw is Map) {
        topicsRaw.forEach((k, v) {
          if (v is bool) topics[k.toString()] = v;
        });
      }

      // Persist for offline use before doing any (slow) downloads.
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
            _prefsKey, jsonEncode(places.map((p) => p.toJson()).toList()));
        await prefs.setString(_topicsPrefsKey, jsonEncode(topics));
      } catch (_) {}

      _topicsActive
        ..clear()
        ..addAll(topics);

      await _apply(places, downloadMissing: true);
      _loaded = true;
      QaLoggerService.instance.log('CONTENT',
          'MANIFEST_SYNCED places=${places.length} remoteReady=${_remoteReadyCount} v=${(data['version'] ?? '?')}');
    } catch (e) {
      // Network/Firebase failure — keep whatever loadCached() already set.
      _loaded = true;
      QaLoggerService.instance.log('CONTENT', 'MANIFEST_SYNC_FAILED $e');
    }
  }

  /// Loads the persisted `topicsActive` map (best-effort) into memory.
  void _applyTopics(String? rawJson) {
    _topicsActive.clear();
    if (rawJson == null) return;
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is Map) {
        decoded.forEach((k, v) {
          if (v is bool) _topicsActive[k.toString()] = v;
        });
      }
    } catch (_) {}
  }

  List<_ManifestPlace> _parsePlaces(String rawJson) {
    final decoded = jsonDecode(rawJson);
    if (decoded is! List) return const [];
    return decoded.map(_ManifestPlace.tryParse).whereType<_ManifestPlace>().toList();
  }

  /// Applies parsed manifest places to in-memory state. When [downloadMissing]
  /// is true, active remote images not yet cached are downloaded (bounded).
  Future<void> _apply(List<_ManifestPlace> places,
      {required bool downloadMissing}) async {
    _activeById
      ..clear()
      ..addEntries(places.map((p) => MapEntry(p.id, p.isActive)));

    final cache = DefaultCacheManager();
    final byCategory = <String, List<GameImageModel>>{};
    for (final p in places) {
      if (!p.isRemote || !p.isActive) continue;
      final url = p.effectiveUrl;
      if (url == null) {
        QaLoggerService.instance.log('CONTENT', 'MANIFEST_REMOTE_NO_URL id=${p.id}');
        continue;
      }
      try {
        var fileInfo = await cache.getFileFromCache(url);
        if (fileInfo == null && downloadMissing) {
          fileInfo = await cache.downloadFile(url).timeout(const Duration(seconds: 12));
        }
        if (fileInfo != null) {
          (byCategory[p.category] ??= []).add(_toImage(p, url));
        }
        // Not cached and offline → skip this remote place for now.
      } catch (e) {
        QaLoggerService.instance.log('CONTENT', 'MANIFEST_REMOTE_SKIP id=${p.id} $e');
      }
    }
    _remoteByCategory
      ..clear()
      ..addAll(byCategory);
  }

  GameImageModel _toImage(_ManifestPlace p, String url) => GameImageModel(
        id: p.id,
        name: p.nameHe,
        answer: p.answerHe,
        acceptedAnswers: p.aliases,
        facts: p.facts,
        category: ImageCategory.israeliLandmark,
        imageUrl: url,
        thumbnailUrl: url,
      );
}
