import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show mapEquals;

import 'package:flutter_ders/app/core/background/background_models.dart';
import 'package:flutter_ders/app/core/device/location_source.dart'
    show distanceMeters;

// ─────────────────────────────────────────────────────────────────────────
// DERS 19 — Arka plan işi: durum denetimi + 3 saniyede bir GPS
//
// Bu sınıf servis isolate'inde yaşar ama hiçbir eklentiyi doğrudan bilmez:
// GPS okuyucu ve depo dışarıdan verilir. Böylece testte saat, GPS ve disk
// sahte verilip her adım tek tek denenebilir.
//
//   uygulama ──'durum'──▶ setPresence()   (açık / arka plan / kapalı)
//   uygulama ──'nabiz'──▶ heartbeat()     (3 sn'de bir "yaşıyorum")
//   Timer(3 sn) ────────▶ tick()          (arkadaysa GPS okur, sayar)
//
// Uygulama kapatılınca (görev listesinden kaydırma) "detached" haberi her
// zaman gelmez; bu yüzden nabız [heartbeatTimeout] boyunca gelmezse uygulama
// kapalı sayılır.
// ─────────────────────────────────────────────────────────────────────────

/// Bir GPS ölçümü alır; alamazsa hata fırlatır.
typedef GpsReader = Future<GpsSample> Function(AppPresence presence);

/// Konum listesinin ve istatistiğin saklandığı yer.
abstract interface class TrackStore {
  /// Kayıtlı istatistik ve konumlar.
  Future<(BackgroundStats?, List<GpsSample>)> load();

  /// Bir konumu sona ekler.
  Future<void> append(GpsSample sample);

  /// İstatistiği yazar.
  Future<void> saveStats(BackgroundStats stats);

  /// Hepsini siler.
  Future<void> clear();
}

/// Bellekte tutan depo (testler).
class MemoryTrackStore implements TrackStore {
  /// Kayıtlı konumlar.
  final List<GpsSample> samples = [];

  /// Kayıtlı istatistik.
  BackgroundStats? stats;

  @override
  Future<(BackgroundStats?, List<GpsSample>)> load() async =>
      (stats, [...samples]);

  @override
  Future<void> append(GpsSample sample) async => samples.add(sample);

  @override
  Future<void> saveStats(BackgroundStats stats) async => this.stats = stats;

  @override
  Future<void> clear() async {
    samples.clear();
    stats = null;
  }
}

/// Telefonda dosyaya yazan depo: konumlar satır satır JSON (her ölçümde
/// yalnız bir satır eklenir, dosya baştan yazılmaz), istatistik tek dosya.
///
/// Uygulama ve servis aynı klasörü okur; yazan yalnız servistir.
class FileTrackStore implements TrackStore {
  /// [directory] uygulamanın kendi klasörüdür (getApplicationSupportDirectory).
  FileTrackStore(this.directory);

  /// Klasörü veren fonksiyon.
  final Future<Directory> Function() directory;

  Future<File> _file(String name) async {
    final dir = Directory('${(await directory()).path}/arka_plan');
    if (!dir.existsSync()) await dir.create(recursive: true);
    return File('${dir.path}/$name');
  }

  @override
  Future<(BackgroundStats?, List<GpsSample>)> load() async {
    final statsFile = await _file('istatistik.json');
    final samplesFile = await _file('konumlar.jsonl');
    BackgroundStats? stats;
    if (statsFile.existsSync()) {
      try {
        stats = BackgroundStats.fromJson(
          (jsonDecode(await statsFile.readAsString()) as Map).cast(),
        );
      } on FormatException {
        stats = null;
      }
    }
    final samples = <GpsSample>[];
    if (samplesFile.existsSync()) {
      for (final line in await samplesFile.readAsLines()) {
        if (line.trim().isEmpty) continue;
        try {
          samples.add(GpsSample.fromJson((jsonDecode(line) as Map).cast()));
        } on FormatException {
          // Yazılırken kesilen son satır atlanır.
        }
      }
    }
    return (stats, samples);
  }

  @override
  Future<void> append(GpsSample sample) async {
    final f = await _file('konumlar.jsonl');
    await f.writeAsString(
      '${jsonEncode(sample.toJson())}\n',
      mode: FileMode.append,
      flush: true,
    );
  }

  @override
  Future<void> saveStats(BackgroundStats stats) async {
    final f = await _file('istatistik.json');
    // Önce geçici dosya, sonra ad değişikliği: okuyan yarım JSON görmez.
    final tmp = File('${f.path}.part');
    await tmp.writeAsString(jsonEncode(stats.toJson()), flush: true);
    await tmp.rename(f.path);
  }

  @override
  Future<void> clear() async {
    for (final name in ['istatistik.json', 'konumlar.jsonl']) {
      final f = await _file(name);
      if (f.existsSync()) await f.delete();
    }
  }
}

/// Bir adımın sonucu.
enum TickOutcome {
  /// Konum alındı.
  recorded,

  /// Uygulama açık; GPS okunmadı.
  skippedOpen,

  /// Önceki okuma sürüyordu.
  overlapped,

  /// GPS okunamadı.
  failed,
}

/// Durum denetimi ve konum toplama.
class BackgroundTracker {
  /// Oluşturur.
  BackgroundTracker({
    required this._readGps,
    required this._store,
    DateTime Function()? now,
    this.heartbeatTimeout = const Duration(seconds: 10),
    this.maxSamplesInMemory = 2000,
  }) : _now = now ?? DateTime.now;

  final GpsReader _readGps;
  final TrackStore _store;
  final DateTime Function() _now;

  /// Bu süre boyunca nabız gelmezse uygulama kapalı sayılır.
  final Duration heartbeatTimeout;

  /// Bellekte (ve ekrana giden) en çok konum; dosyada hepsi durur.
  final int maxSamplesInMemory;

  BackgroundStats _stats = const BackgroundStats();
  final List<GpsSample> _samples = [];
  DateTime? _accountedAt;
  bool _reading = false;
  int _storedSamples = 0;

  /// Şimdiki istatistik.
  BackgroundStats get stats => _stats;

  /// Bellekteki konumlar (en yenisi sonda).
  List<GpsSample> get samples => List.unmodifiable(_samples);

  /// Dosyadaki toplam konum sayısı.
  int get storedSamples => _storedSamples;

  /// Diskteki son durumu okur ve servisin yeni bir başlangıcını sayar.
  Future<void> load() async {
    final (stats, samples) = await _store.load();
    final now = _now();
    _samples
      ..clear()
      ..addAll(_tail(samples));
    _storedSamples = samples.length;
    _stats = (stats ?? const BackgroundStats()).copyWith(
      startedAt: stats?.startedAt ?? now,
      serviceStarts: (stats?.serviceStarts ?? 0) + 1,
      // Servis uygulama açıkken başlatılır; ilk haberi uygulama verir.
      presence: AppPresence.open,
      lastHeartbeatAt: now,
    );
    _accountedAt = now;
    await _store.saveStats(_stats);
  }

  List<GpsSample> _tail(List<GpsSample> all) => all.length > maxSamplesInMemory
      ? all.sublist(all.length - maxSamplesInMemory)
      : all;

  // Önceki hesaptan bu yana geçen süre şimdiki duruma yazılır.
  void _account(DateTime now) {
    final from = _accountedAt ?? now;
    final ms = now.difference(from).inMilliseconds;
    if (ms > 0) {
      final map = {..._stats.presenceMs};
      map[_stats.presence] = (map[_stats.presence] ?? 0) + ms;
      _stats = _stats.copyWith(presenceMs: map);
    }
    _accountedAt = now;
  }

  /// Uygulamanın durumu değişti. Değiştiyse true.
  bool setPresence(AppPresence presence, String reason) {
    final now = _now();
    _account(now);
    if (presence != AppPresence.closed) {
      _stats = _stats.copyWith(lastHeartbeatAt: now);
    }
    if (presence == _stats.presence) return false;
    final changes = [..._stats.changes, PresenceChange(now, presence, reason)];
    _stats = _stats.copyWith(
      presence: presence,
      changes: changes.length > BackgroundStats.maxChanges
          ? changes.sublist(changes.length - BackgroundStats.maxChanges)
          : changes,
    );
    unawaited(_store.saveStats(_stats));
    return true;
  }

  /// Uygulamadan "yaşıyorum" sinyali.
  void heartbeat() => _stats = _stats.copyWith(lastHeartbeatAt: _now());

  /// Nabız kesildiyse uygulamayı kapalı sayar. Kapandıysa true.
  bool checkHeartbeat() {
    final last = _stats.lastHeartbeatAt;
    if (_stats.presence == AppPresence.closed || last == null) return false;
    if (_now().difference(last) < heartbeatTimeout) return false;
    return setPresence(AppPresence.closed, 'nabız kesildi');
  }

  /// 3 saniyelik adım: durum denetimi, arkadaysa GPS.
  Future<TickOutcome> tick() async {
    final now = _now();
    checkHeartbeat();
    _account(now);
    _stats = _stats.copyWith(ticks: _stats.ticks + 1, lastTickAt: now);
    if (_stats.presence == AppPresence.open) {
      _stats = _stats.copyWith(skippedOpen: _stats.skippedOpen + 1);
      await _store.saveStats(_stats);
      return TickOutcome.skippedOpen;
    }
    if (_reading) {
      _stats = _stats.copyWith(overlapped: _stats.overlapped + 1);
      return TickOutcome.overlapped;
    }
    _reading = true;
    final watch = Stopwatch()..start();
    try {
      final sample = await _readGps(_stats.presence);
      final ms = watch.elapsedMilliseconds;
      final withMs = GpsSample(
        latitude: sample.latitude,
        longitude: sample.longitude,
        accuracy: sample.accuracy,
        speed: sample.speed,
        time: sample.time,
        presence: sample.presence,
        readMs: ms,
      );
      var distance = _stats.distanceMeters;
      if (_samples.isNotEmpty) {
        final prev = _samples.last;
        final step = distanceMeters(
          prev.latitude,
          prev.longitude,
          withMs.latitude,
          withMs.longitude,
        );
        // Yerinde dururken GPS birkaç metre titrer; doğruluktan küçük
        // adımlar mesafeye eklenmez (Ders 12 ile aynı kural).
        if (step > withMs.accuracy / 2) distance += step;
      }
      _samples.add(withMs);
      if (_samples.length > maxSamplesInMemory) _samples.removeAt(0);
      _storedSamples++;
      _stats = _stats.copyWith(
        gpsOk: _stats.gpsOk + 1,
        totalReadMs: _stats.totalReadMs + ms,
        maxReadMs: ms > _stats.maxReadMs ? ms : _stats.maxReadMs,
        distanceMeters: distance,
      );
      await _store.append(withMs);
      await _store.saveStats(_stats);
      return TickOutcome.recorded;
    } on Object {
      _stats = _stats.copyWith(gpsFailed: _stats.gpsFailed + 1);
      await _store.saveStats(_stats);
      return TickOutcome.failed;
    } finally {
      _reading = false;
    }
  }

  /// Gönderilen bir bildirimi sayar.
  void recordNotification(String kind) {
    final map = {..._stats.notificationsSent};
    map[kind] = (map[kind] ?? 0) + 1;
    _stats = _stats.copyWith(notificationsSent: map);
    unawaited(_store.saveStats(_stats));
  }

  /// İptal edilen bekleyen bildirimleri sayar.
  void recordCancelled(int count) {
    if (count == 0) return;
    _stats = _stats.copyWith(
      notificationsCancelled: _stats.notificationsCancelled + count,
    );
    unawaited(_store.saveStats(_stats));
  }

  /// Düğme sayılarını ortak depodan alır (düğmeler başka isolate'te
  /// sayılır).
  void syncActions(Map<String, int> actions) {
    if (mapEquals(actions, _stats.actions)) return;
    _stats = _stats.copyWith(actions: actions);
    unawaited(_store.saveStats(_stats));
  }

  /// Bildirimleri sessize alır ya da açar.
  void setMuted({required bool muted}) {
    if (_stats.muted == muted) return;
    _stats = _stats.copyWith(muted: muted);
    unawaited(_store.saveStats(_stats));
  }

  /// Konumları ve istatistiği siler; sayım sıfırdan başlar.
  Future<void> clear() async {
    await _store.clear();
    final now = _now();
    _samples.clear();
    _storedSamples = 0;
    _stats = BackgroundStats(
      startedAt: now,
      lastHeartbeatAt: now,
      presence: _stats.presence,
      serviceStarts: 1,
    );
    _accountedAt = now;
    await _store.saveStats(_stats);
  }

  /// Uygulamaya giden özet: istatistik + son [recent] konum.
  Map<String, Object?> report({int recent = 30}) => {
    'istatistik': _stats.toJson(),
    'kayitli': _storedSamples,
    'son_konumlar': [
      for (final s in _samples.reversed.take(recent)) s.toJson(),
    ],
  };
}
