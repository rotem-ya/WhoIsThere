import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
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
  static const _topicLabelsPrefsKey = 'content_topic_labels_v1';
  static const _docPath = 'content_manifest/places_v1';

  // Content model (per Rotem): the ADMIN is the live source of truth — image
  // overrides and remote-only places published in the manifest appear in the
  // game immediately, no app update needed. At each APP RELEASE the current
  // remote images are baked into the bundled assets and their overrides are
  // cleared from the manifest, so long-term serving stays local on-device and
  // Firestore/Storage only carries the delta since the last release (see
  // CLAUDE.md → "תוכן מהענן"). Set to true ONLY as an emergency brake that
  // ignores every cloud image (topic/text/hide admin controls still apply).
  static const bool kBundledImagesOnly = false;

  // id → isActive override (covers bundled + remote).
  final Map<String, bool> _activeById = {};
  // id → full manifest entry (covers bundled + remote). Drives per-item override
  // of a BUNDLED place's image/text without a new build (see [resolveBundled]).
  final Map<String, _ManifestPlace> _entryById = {};
  // Override image URLs (cache-busted) that are confirmed cached and therefore
  // safe to show. A bundled override only takes effect once its image is ready,
  // so offline/just-published items fall back to the bundled asset cleanly.
  final Set<String> _readyOverrideUrls = {};
  // category id → remote places active AND with image cached, in that category.
  final Map<String, List<GameImageModel>> _remoteByCategory = {};
  // category id → active flag (manifest `topicsActive` map). A whole topic
  // ("חי צומח דומם") can be hidden by the admin without touching its places.
  final Map<String, bool> _topicsActive = {};
  // category id → admin display-name override (manifest `topicLabels` map).
  // Empty/missing = the bundled default name from GameCategories (§8).
  final Map<String, String> _topicLabels = {};
  bool _loaded = false;

  // Bumped on every manifest change (startup, live update). Widgets/providers can
  // listen to rebuild so admin edits show immediately without an app restart.
  final ValueNotifier<int> revision = ValueNotifier<int>(0);
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _liveSub;

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
  /// map means every topic shows, exactly like before). The admin is the single
  /// source of truth for enabling/disabling topics, via the manifest.
  bool isCategoryActive(String categoryId) => _topicsActive[categoryId] ?? true;

  /// Admin display-name override for a topic, or null when none is set (callers
  /// then fall back to the bundled default name from GameCategories §8). A
  /// category absent from the manifest `topicLabels` map returns null —
  /// backward compatible: no map means every topic shows its built-in name.
  String? topicLabel(String categoryId) {
    final v = _topicLabels[categoryId];
    return (v != null && v.isNotEmpty) ? v : null;
  }

  /// Remote places ready to play (active + image cached) in [categoryId].
  /// Copy, never null.
  List<GameImageModel> availableRemoteImages(
          [String categoryId = 'israel_places']) =>
      kBundledImagesOnly
          ? const []
          : List<GameImageModel>.unmodifiable(
              _remoteByCategory[categoryId] ?? const []);

  /// Applies any live admin override to a BUNDLED place. For every id the
  /// manifest may carry overrides that win over the built-in JSON/asset:
  ///  • image — when the entry has a non-empty `imageUrl` AND that (cache-busted)
  ///    image is already cached, it replaces the bundled asset (egress-friendly:
  ///    once the admin clears `imageUrl`, the game falls back to the asset).
  ///  • text — a non-empty `nameHe` / `answerHe` / `aliasesHe` / `facts` replaces
  ///    the bundled value (empty = no override). `answerHe` falls back to
  ///    `nameHe` per the manifest parse, so send both together for a text edit.
  /// Returns [bundled] unchanged when there is no entry or nothing to override.
  GameImageModel resolveBundled(GameImageModel bundled) {
    final o = _entryById[bundled.id];
    if (o == null) return bundled;

    final overrideUrl = o.effectiveUrl;
    final useImage = !kBundledImagesOnly &&
        overrideUrl != null &&
        _readyOverrideUrls.contains(overrideUrl);

    final name = o.nameHe.isNotEmpty ? o.nameHe : bundled.name;
    final answer = o.answerHe.isNotEmpty ? o.answerHe : bundled.answer;
    final aliases = o.aliases.isNotEmpty ? o.aliases : bundled.acceptedAnswers;
    final facts = o.facts.isNotEmpty ? o.facts : bundled.facts;

    if (!useImage &&
        name == bundled.name &&
        answer == bundled.answer &&
        identical(aliases, bundled.acceptedAnswers) &&
        identical(facts, bundled.facts)) {
      return bundled; // nothing changed
    }

    return GameImageModel(
      id: bundled.id,
      name: name,
      answer: answer,
      acceptedAnswers: aliases,
      facts: facts,
      category: bundled.category,
      isPremium: bundled.isPremium,
      cost: bundled.cost,
      imageUrl: useImage ? overrideUrl : bundled.imageUrl,
      thumbnailUrl: useImage ? overrideUrl : bundled.thumbnailUrl,
      source: bundled.source,
    );
  }

  /// Instant, offline load from the last persisted manifest. Call at startup
  /// before [sync] so the previous state applies with zero network wait.
  Future<void> loadCached() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _applyTopics(prefs.getString(_topicsPrefsKey));
      _applyTopicLabels(prefs.getString(_topicLabelsPrefsKey));
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
      await _ingest(snap.data() ?? {});
    } catch (e) {
      // Network/Firebase failure — keep whatever loadCached() already set.
      _loaded = true;
      QaLoggerService.instance.log('CONTENT', 'MANIFEST_SYNC_FAILED $e');
    }
  }

  /// Live sync: subscribes to the manifest doc so admin edits propagate to the
  /// running game IMMEDIATELY (no app restart). The first snapshot also serves
  /// as the initial sync, so this replaces the one-shot [sync] at startup. Every
  /// update re-applies state and bumps [revision] so open screens can refresh.
  /// Idempotent — calling twice keeps a single subscription.
  void startRealtime() {
    if (_liveSub != null) return;
    _liveSub = FirebaseFirestore.instance
        .doc(_docPath)
        .snapshots()
        .listen((snap) {
      if (!snap.exists) {
        _loaded = true;
        QaLoggerService.instance.log('CONTENT', 'MANIFEST_NONE (live, no doc)');
        return;
      }
      // Fire-and-forget; _ingest awaits its own image pre-warm and bumps revision.
      unawaited(_ingest(snap.data() ?? {}));
    }, onError: (e) {
      _loaded = true;
      QaLoggerService.instance.log('CONTENT', 'MANIFEST_LIVE_ERROR $e');
      // A Firestore snapshot stream TERMINATES after an error (e.g. a
      // permission-denied raced against auth restore) — without a retry the
      // session would never receive live admin updates again. Re-subscribe
      // after a short delay; repeated failures just keep retrying quietly.
      _liveSub?.cancel();
      _liveSub = null;
      Future.delayed(const Duration(seconds: 20), () {
        if (_liveSub == null) startRealtime();
      });
    });
  }

  /// Stops the live subscription (rarely needed; the manifest is app-lifelong).
  void stopRealtime() {
    _liveSub?.cancel();
    _liveSub = null;
  }

  /// Applies one manifest document's data: parse, persist (offline), pre-warm
  /// images, then notify listeners. Shared by [sync] and [startRealtime].
  Future<void> _ingest(Map<String, dynamic> data) async {
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

    // Per-topic display-name overrides (optional; absent map = built-in names).
    final labels = <String, String>{};
    final labelsRaw = data['topicLabels'];
    if (labelsRaw is Map) {
      labelsRaw.forEach((k, v) {
        if (v is String && v.isNotEmpty) labels[k.toString()] = v;
      });
    }

    // Persist for offline use before doing any (slow) downloads.
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _prefsKey, jsonEncode(places.map((p) => p.toJson()).toList()));
      await prefs.setString(_topicsPrefsKey, jsonEncode(topics));
      await prefs.setString(_topicLabelsPrefsKey, jsonEncode(labels));
    } catch (_) {}

    _topicsActive
      ..clear()
      ..addAll(topics);
    _topicLabels
      ..clear()
      ..addAll(labels);

    await _apply(places, downloadMissing: true);
    _loaded = true;
    revision.value++; // notify listeners so open screens refresh immediately
    QaLoggerService.instance.log('CONTENT',
        'MANIFEST_SYNCED places=${places.length} remoteReady=${_remoteReadyCount} v=${(data['version'] ?? '?')}');
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

  /// Loads the persisted `topicLabels` map (best-effort) into memory.
  void _applyTopicLabels(String? rawJson) {
    _topicLabels.clear();
    if (rawJson == null) return;
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is Map) {
        decoded.forEach((k, v) {
          if (v is String && v.isNotEmpty) _topicLabels[k.toString()] = v;
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
    _entryById
      ..clear()
      ..addEntries(places.map((p) => MapEntry(p.id, p)));
    _readyOverrideUrls.clear();

    final cache = DefaultCacheManager();
    final byCategory = <String, List<GameImageModel>>{};
    for (final p in places) {
      if (!p.isActive) continue;
      final url = p.effectiveUrl;
      if (url == null) {
        // A remote place with no image can't be played; a bundled place with no
        // override URL simply keeps its asset — nothing to pre-warm.
        if (p.isRemote) {
          QaLoggerService.instance.log('CONTENT', 'MANIFEST_REMOTE_NO_URL id=${p.id}');
        }
        continue;
      }
      // Pre-warm any image carried by the manifest — remote definitions AND
      // bundled overrides — so it's ready (and offline-safe) before use.
      try {
        var fileInfo = await cache.getFileFromCache(url);
        if (fileInfo == null && downloadMissing) {
          fileInfo = await cache.downloadFile(url).timeout(const Duration(seconds: 12));
        }
        if (fileInfo != null) {
          _readyOverrideUrls.add(url);
          if (p.isRemote) {
            (byCategory[p.category] ??= []).add(_toImage(p, url));
          }
        }
        // Not cached and offline → skip; bundled places fall back to the asset.
      } catch (e) {
        QaLoggerService.instance.log('CONTENT', 'MANIFEST_IMG_SKIP id=${p.id} $e');
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
