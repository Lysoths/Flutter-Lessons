import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';

// ─────────────────────────────────────────────────────────────────────────
// DERS 17 — Arka planda çalışan bellek denetleyicisi
//
// Çözülmüş bir görsel bellekte genişlik × yükseklik × 4 bayt yer tutar
// (1080×1080 → ~4,5 MB). Ağdan çok görsel gelince bellek dolar; Android
// uygulamayı yavaşlatır ya da kapatır, görseller yarım / titreyerek çizilir.
//
//   Bütçe      ImageCache.maximumSizeBytes cihaz RAM'ine göre ayarlanır
//              (RAM'in %2'si, 48–256 MB arası).
//   Örnekleme  Her [interval]'da önbellek boyutu, görsel sayısı, ekrandaki
//              (canlı) görseller ve uygulamanın toplam belleği (RSS) okunur.
//   Erken boşaltma  Önbellek bütçenin %90'ını geçerse boşaltılır.
//   Sistem uyarısı  Android "bellek az" dediğinde (didHaveMemoryPressure)
//              boşaltılır.
//   Arka plan  Uygulama arka plana geçince bütçe yarıya iner, dönünce geri
//              gelir.
//
// ImageCache.clear() ekranda GÖRÜNEN görselleri silmez; yalnızca o an
// kullanılmayanları atar. Bu yüzden boşaltma sırasında ekranda titreme olmaz.
// ─────────────────────────────────────────────────────────────────────────

/// Bir ölçüm anı.
typedef MemorySample = ({
  DateTime at,
  int cacheBytes,
  int cacheCount,
  int liveCount,
  int pendingCount,
  int rssBytes,
  int budgetBytes,
});

/// Önbellek neden boşaltıldı?
enum TrimReason {
  /// Bütçenin %90'ı aşıldı.
  budget('Bütçe aşıldı'),

  /// Sistem "bellek az" dedi.
  systemPressure('Sistem bellek uyarısı'),

  /// Uygulama arka plana geçti.
  background('Arka plana geçildi'),

  /// Elle (ders düğmesi).
  manual('Elle');

  const TrimReason(this.label);

  /// Görünen ad.
  final String label;
}

/// Bir boşaltma kaydı.
typedef TrimEvent = ({DateTime at, TrimReason reason, int freedBytes});

/// DERS 17 — Görsel belleğini izleyen ve sınırlayan denetleyici.
class ImageMemoryController with WidgetsBindingObserver {
  /// Denetleyici oluşturur. [totalRamMb] cihazın RAM'ini verir (bilinmiyorsa
  /// null); [cache] verilmezse Flutter'ın önbelleği kullanılır.
  ImageMemoryController({
    required this._totalRamMb,
    this._cache,
    this.interval = const Duration(seconds: 2),
    int Function()? rss,
  }) : _rss = rss ?? (() => ProcessInfo.currentRss);

  /// Örnekleme aralığı.
  final Duration interval;

  final Future<int?> Function() _totalRamMb;
  final ImageCache? _cache;
  final int Function() _rss;

  ImageCache get _imageCache => _cache ?? PaintingBinding.instance.imageCache;

  final _samples = StreamController<MemorySample>.broadcast();
  final _trims = StreamController<TrimEvent>.broadcast();
  Timer? _timer;
  int _budget = 100 << 20;
  int? _ramMb;
  bool _started = false;

  /// Her ölçüm.
  Stream<MemorySample> get samples => _samples.stream;

  /// Her boşaltma.
  Stream<TrimEvent> get trims => _trims.stream;

  /// Şimdiki bütçe (bayt).
  int get budgetBytes => _budget;

  /// Cihaz RAM'i (MB), biliniyorsa.
  int? get ramMb => _ramMb;

  /// Çalışıyor mu?
  bool get isRunning => _timer?.isActive ?? false;

  /// RAM'e göre bütçe: %2, en az 48 MB, en çok 256 MB.
  static int budgetFor(int? ramMb) {
    if (ramMb == null || ramMb <= 0) return 100 << 20;
    return ((ramMb << 20) * 0.02).round().clamp(48 << 20, 256 << 20);
  }

  /// Bütçeyi kurar ve örneklemeyi başlatır (birden çok kez çağrılabilir).
  Future<void> start() async {
    if (_started) return;
    _started = true;
    _ramMb = await _totalRamMb();
    _setBudget(budgetFor(_ramMb));
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(interval, (_) => sample());
    sample();
  }

  void _setBudget(int bytes) {
    _budget = bytes;
    _imageCache.maximumSizeBytes = bytes;
  }

  /// Şimdi bir ölçüm yapar; bütçe aşıldıysa boşaltır.
  MemorySample sample() {
    final c = _imageCache;
    final s = (
      at: DateTime.now(),
      cacheBytes: c.currentSizeBytes,
      cacheCount: c.currentSize,
      liveCount: c.liveImageCount,
      pendingCount: c.pendingImageCount,
      rssBytes: _rss(),
      budgetBytes: _budget,
    );
    if (!_samples.isClosed) _samples.add(s);
    if (s.cacheBytes > _budget * 0.9) trim(TrimReason.budget);
    return s;
  }

  /// Kullanılmayan çözülmüş görselleri bellekten atar.
  void trim(TrimReason reason) {
    final before = _imageCache.currentSizeBytes;
    _imageCache.clear();
    if (!_trims.isClosed) {
      _trims.add((
        at: DateTime.now(),
        reason: reason,
        freedBytes: before - _imageCache.currentSizeBytes,
      ));
    }
  }

  @override
  void didHaveMemoryPressure() => trim(TrimReason.systemPressure);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused || AppLifecycleState.hidden:
        _setBudget(budgetFor(_ramMb) ~/ 2);
        trim(TrimReason.background);
      case AppLifecycleState.resumed:
        _setBudget(budgetFor(_ramMb));
      case AppLifecycleState.inactive || AppLifecycleState.detached:
        break;
    }
  }

  /// Durdurur.
  Future<void> dispose() async {
    _timer?.cancel();
    if (_started) WidgetsBinding.instance.removeObserver(this);
    _started = false;
    await _samples.close();
    await _trims.close();
  }
}
