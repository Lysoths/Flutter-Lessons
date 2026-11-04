import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_ders/app/core/cache/image_fetchers.dart';
import 'package:flutter_ders/app/core/cache/image_source.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────
// DERS 17 — Sürüme bağlı görsel önbelleği
//
// İki katman:
//   Bellek  Flutter'ın ImageCache'i: çözülmüş (decode edilmiş) görseller.
//   Disk    <uygulama klasörü>/image_cache/<sürüm>/<sha1>.img: ham baytlar.
//
// Yeni sürüm çıkınca: uygulama açılırken kayıtlı sürüm ile şimdiki sürüm
// karşılaştırılır. Farklıysa iki katman da boşaltılır; eski sürümün
// görseli (aynı adreste değişmiş logo, banner ...) ekranda kalmaz.
//
// Yarım / bozuk görsel ekrana gelmesin diye:
//   1. İndirilen bayt sayısı beklenenle karşılaştırılır (image_fetchers).
//   2. Baytlar diske yazılmadan önce bir kez çözülür; çözülemiyorsa atılır.
//   3. Dosya önce .part adıyla yazılır, bitince adı değiştirilir. Uygulama
//      yazma sırasında kapanırsa yarım dosya hiçbir zaman .img olmaz.
//   4. Diskten okunan dosya da çözülerek denetlenir; bozuksa silinip
//      yeniden indirilir.
//   5. Aynı görsel aynı anda iki yerden istenirse tek indirme yapılır.
// ─────────────────────────────────────────────────────────────────────────

/// Görselin bu sefer nereden geldiği.
enum CacheOrigin {
  /// Flutter'ın bellek önbelleği (çözülmüş hâli hazır).
  memory('Bellek'),

  /// Disk önbelleği.
  disk('Disk'),

  /// Kaynaktan indirildi.
  source('Kaynak');

  const CacheOrigin(this.label);

  /// Görünen ad.
  final String label;
}

/// Önbelleğin sayaçları.
typedef ImageCacheStats = ({
  int diskHits,
  int downloads,
  int corrupted,
  int retries,
  int sharedRequests,
});

/// Sürüm değişince neler oldu?
typedef VersionCheck = ({
  String current,
  String? previous,
  bool cleared,
  int removedFiles,
});

/// DERS 17 — Uygulamanın görsel önbelleği.
class AppImageCache {
  /// Önbellek oluşturur.
  ///
  /// [rootDirectory]: disk klasörünün bulunduğu yer; [appVersion]: şimdiki
  /// sürüm (`1.0.0+1`). İkisi de testte sahte verilir.
  AppImageCache({
    required this._rootDirectory,
    required this._appVersion,
    required this._fetcher,
    required this._prefs,
    this._memory,
    this.maxRetries = 2,
  });

  /// Kayıtlı sürümün anahtarı.
  static const versionKey = 'ders17_image_cache_version';

  /// İndirme başarısız olursa kaç kez daha denenir.
  final int maxRetries;

  final Future<Directory> Function() _rootDirectory;
  final Future<String> Function() _appVersion;
  final ImageFetcher _fetcher;
  final Future<SharedPreferences> Function() _prefs;
  final ImageCache? _memory;

  ImageCache get _imageCache => _memory ?? PaintingBinding.instance.imageCache;

  final _inflight = <String, Future<Uint8List>>{};
  final _origins = <String, CacheOrigin>{};
  Future<VersionCheck>? _ready;
  late Directory _dir;
  late String _version;

  int _diskHits = 0;
  int _downloads = 0;
  int _corrupted = 0;
  int _retries = 0;
  int _shared = 0;

  /// Sayaçlar.
  ImageCacheStats get stats => (
    diskHits: _diskHits,
    downloads: _downloads,
    corrupted: _corrupted,
    retries: _retries,
    sharedRequests: _shared,
  );

  /// Önbelleğin bağlı olduğu sürüm (`ensureReady` sonrası).
  String get version => _version;

  /// Sürümü denetler; birden çok kez çağrılabilir, iş bir kez yapılır.
  Future<VersionCheck> ensureReady() => _ready ??= _checkVersion();

  Future<VersionCheck> _checkVersion() async {
    _version = await _appVersion();
    final prefs = await _prefs();
    final previous = prefs.getString(versionKey);
    final root = Directory('${(await _rootDirectory()).path}/image_cache');
    _dir = Directory('${root.path}/${_safe(_version)}');
    var removed = 0;
    final changed = previous != _version;
    if (changed) {
      // Eski sürümün klasörleri (ve varsa bilinmeyenler) silinir.
      if (root.existsSync()) {
        for (final entity in root.listSync()) {
          if (entity.path == _dir.path) continue;
          removed += _countFiles(entity);
          entity.deleteSync(recursive: true);
        }
      }
      _imageCache
        ..clear()
        ..clearLiveImages();
      await prefs.setString(versionKey, _version);
    }
    _dir.createSync(recursive: true);
    return (
      current: _version,
      previous: previous,
      cleared: changed && previous != null,
      removedFiles: removed,
    );
  }

  /// [source]'un baytları: önce disk, yoksa kaynak.
  Future<Uint8List> load(
    CachedImageSource source, {
    FetchProgress? onProgress,
  }) {
    final running = _inflight[source.key];
    if (running != null) {
      _shared++;
      return running;
    }
    final future = _load(source, onProgress);
    _inflight[source.key] = future;
    return future.whenComplete(() => _inflight.remove(source.key));
  }

  Future<Uint8List> _load(
    CachedImageSource source,
    FetchProgress? onProgress,
  ) async {
    await ensureReady();
    final file = _fileFor(source);
    if (file.existsSync()) {
      final bytes = await file.readAsBytes();
      if (await isDecodable(bytes)) {
        _diskHits++;
        _origins[source.key] = CacheOrigin.disk;
        onProgress?.call(bytes.length, bytes.length);
        return bytes;
      }
      // Diskte bozulmuş: sil, yeniden indir.
      _corrupted++;
      file.deleteSync();
    }
    final bytes = await _download(source, onProgress);
    await _write(file, bytes);
    _downloads++;
    _origins[source.key] = CacheOrigin.source;
    return bytes;
  }

  Future<Uint8List> _download(
    CachedImageSource source,
    FetchProgress? onProgress,
  ) async {
    for (var attempt = 0; ; attempt++) {
      try {
        final bytes = await _fetcher.fetch(source, onProgress: onProgress);
        if (!await isDecodable(bytes)) {
          throw const ImageFetchFailure('Gelen veri görsel olarak çözülemedi.');
        }
        return bytes;
      } on ImageFetchFailure {
        if (attempt >= maxRetries) rethrow;
        _retries++;
        await Future<void>.delayed(Duration(milliseconds: 300 * (attempt + 1)));
      }
    }
  }

  Future<void> _write(File file, Uint8List bytes) async {
    final part = File('${file.path}.part');
    await part.writeAsBytes(bytes, flush: true);
    await part.rename(file.path);
  }

  /// Baytlar en son nereden okundu: disk ya da kaynak. (Bellekteki çözülmüş
  /// görsel bu önbelleğe hiç uğramaz; onu `ImageCache.containsKey` söyler.)
  CacheOrigin? lastLoadOrigin(CachedImageSource source) => _origins[source.key];

  /// Diskte mi?
  bool isOnDisk(CachedImageSource source) => _fileFor(source).existsSync();

  /// Disk önbelleğinin dosya sayısı ve boyutu.
  ({int files, int bytes}) diskUsage() {
    if (!_dir.existsSync()) return (files: 0, bytes: 0);
    var files = 0;
    var bytes = 0;
    for (final f in _dir.listSync().whereType<File>()) {
      if (!f.path.endsWith('.img')) continue;
      files++;
      bytes += f.lengthSync();
    }
    return (files: files, bytes: bytes);
  }

  /// Bellek önbelleğini boşaltır (ekrandaki görseller kalır).
  void clearMemory() => _imageCache.clear();

  /// Disk önbelleğini boşaltır.
  Future<void> clearDisk() async {
    await ensureReady();
    if (_dir.existsSync()) {
      for (final f in _dir.listSync()) {
        f.deleteSync(recursive: true);
      }
    }
    _origins.clear();
  }

  /// Ders için: diskteki dosyanın ortasını bozar (yarım yazılmış gibi).
  Future<bool> corrupt(CachedImageSource source) async {
    final file = _fileFor(source);
    if (!file.existsSync()) return false;
    final bytes = await file.readAsBytes();
    await file.writeAsBytes(bytes.sublist(0, bytes.length ~/ 3), flush: true);
    return true;
  }

  /// Ders için: kayıtlı sürümü eskisiyle değiştirir; bir sonraki
  /// [ensureReady] "yeni sürüm çıktı" gibi davranır.
  Future<void> pretendOldVersion(String old) async {
    final prefs = await _prefs();
    await prefs.setString(versionKey, old);
    // Bugünkü dosyalar "eski sürümün" klasörüne taşınır: gerçek bir
    // yükseltmede diskte durum budur.
    final root = Directory('${(await _rootDirectory()).path}/image_cache');
    final oldDir = Directory('${root.path}/${_safe(old)}');
    if (oldDir.existsSync()) oldDir.deleteSync(recursive: true);
    if (_dir.existsSync()) _dir.renameSync(oldDir.path);
    _ready = null;
  }

  File _fileFor(CachedImageSource source) =>
      File('${_dir.path}/${source.key}.img');

  static String _safe(String version) =>
      version.replaceAll(RegExp('[^A-Za-z0-9._+-]'), '_');

  static int _countFiles(FileSystemEntity e) => e is File
      ? 1
      : e is Directory
      ? e.listSync(recursive: true).whereType<File>().length
      : 0;
}

/// Baytlar eksiksiz bir görsel mi?
///
/// Önce biçimin bitiş işaretine bakılır: Skia kısaltılmış bir PNG'yi bazen
/// hata vermeden YARIM çizer (alt kısmı gri). Sonra bir kez çözülür.
Future<bool> isDecodable(Uint8List bytes) async {
  if (!hasCompleteStructure(bytes)) return false;
  ui.Codec? codec;
  try {
    codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    frame.image.dispose();
    return true;
  } on Object {
    return false;
  } finally {
    codec?.dispose();
  }
}

/// Biçimin kendi "dosya bitti" işareti yerinde mi?
///
///   PNG   son 8 bayt: IEND parçası (49 45 4E 44 AE 42 60 82)
///   JPEG  son 2 bayt: FF D9 (sonrasında boşluk olabilir)
///   GIF   son bayt: 3B (;)
///   WebP  RIFF başlığındaki boyut + 8 = dosya boyutu
///   Diğer biçimler yalnızca çözülerek denetlenir.
bool hasCompleteStructure(Uint8List b) {
  if (b.length < 12) return false;
  bool startsWith(List<int> sig) {
    for (var i = 0; i < sig.length; i++) {
      if (b[i] != sig[i]) return false;
    }
    return true;
  }

  if (startsWith(const [0x89, 0x50, 0x4E, 0x47])) {
    const iend = [0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82];
    for (var i = 0; i < 8; i++) {
      if (b[b.length - 8 + i] != iend[i]) return false;
    }
    return true;
  }
  if (startsWith(const [0xFF, 0xD8])) {
    var end = b.length;
    while (end > 2 && b[end - 1] == 0) {
      end--;
    }
    return b[end - 2] == 0xFF && b[end - 1] == 0xD9;
  }
  if (startsWith(const [0x47, 0x49, 0x46])) return b.last == 0x3B;
  if (startsWith(const [0x52, 0x49, 0x46, 0x46])) {
    final size = b[4] | b[5] << 8 | b[6] << 16 | b[7] << 24;
    return size + 8 == b.length;
  }
  return true;
}
