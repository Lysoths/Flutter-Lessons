import 'dart:async';

import 'package:flutter/painting.dart';
import 'package:flutter_ders/app/core/analytics/app_events.dart';
import 'package:flutter_ders/app/core/base/base_view_model_cubit.dart';
import 'package:flutter_ders/app/core/cache/app_image_cache.dart';
import 'package:flutter_ders/app/core/cache/cached_image_provider.dart';
import 'package:flutter_ders/app/core/cache/image_memory_controller.dart';
import 'package:flutter_ders/app/core/cache/image_source.dart';
import 'package:flutter_ders/app/models/image_demo_sources.dart';
import 'package:flutter_ders/app/views/view_image_cache/cubit/image_cache_lab_state.dart';

/// DERS 17 — Görsel önbelleği ekranının view model'i.
class ImageCacheLabCubit extends BaseViewModelCubit<ImageCacheLabState> {
  /// Cubit oluşturur.
  ImageCacheLabCubit({
    required this.cache,
    required this.memory,
    Future<List<Base64ImageSource>> Function()? base64Sources,
  }) : _base64Sources = base64Sources ?? loadBase64Sources,
       super(const ImageCacheLabState());

  /// Görsel önbelleği.
  final AppImageCache cache;

  /// Bellek denetleyicisi (uygulama açılınca başlar, burada yalnızca izlenir).
  final ImageMemoryController memory;

  final Future<List<Base64ImageSource>> Function() _base64Sources;
  final _subs = <StreamSubscription<Object?>>[];

  /// Ekran açıldı.
  Future<void> init() async {
    _subs
      ..add(memory.samples.listen(_onSample))
      ..add(memory.trims.listen(_onTrim));
    await memory.start();
    final version = await cache.ensureReady();
    final base64 = await _base64Sources();
    stateChanger(
      state.copyWith(
        ready: true,
        version: version,
        base64: base64,
        ramMb: memory.ramMb,
      ),
    );
    _refreshCounters();
  }

  /// Bu kaynağın `ImageProvider`'ı (ekran da aynısını kullanır).
  CachedSourceImage providerFor(CachedImageSource source) =>
      CachedSourceImage(source, cache: cache);

  /// Kaynak sekmesini değiştirir.
  void showKind(ImageSourceKind kind) =>
      stateChanger(state.copyWith(kind: kind));

  /// Seçili kaynağın bütün görsellerini ekrana gelmeden önce hazırlar.
  Future<void> precacheAll() async {
    track(AppEvent.precached, state.kind.name);
    await Future.wait(state.sources.map(precache));
    final failed = state.sources
        .where((s) => state.items[s.key]?.phase == ItemPhase.failed)
        .length;
    _say(
      failed == 0
          ? '${state.sources.length} görsel hazır: artık anında çizilir.'
          : '$failed görsel yüklenemedi.',
    );
  }

  /// Bellek denetleyicisini zorlamak için 24 büyük karo yükler.
  Future<void> stressTest() async {
    track(AppEvent.stressTest);
    _say('Yük testi: 24 karo yükleniyor…');
    await Future.wait(kS3StressSources.map(precache));
    final s = memory.sample();
    _say(
      'Yük testi bitti: önbellekte ${s.cacheCount} görsel, '
      '${(s.cacheBytes / (1 << 20)).toStringAsFixed(1)} MB.',
    );
  }

  /// Tek görseli yükler ve çözer (precacheImage'ın yaptığı iş).
  Future<void> precache(CachedImageSource source) async {
    final provider = providerFor(source);
    final inMemory = PaintingBinding.instance.imageCache.containsKey(provider);
    final watch = Stopwatch()..start();
    _setItem(source, const ItemStatus(phase: ItemPhase.loading));
    final done = Completer<void>();
    final stream = provider.resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (image, sync) {
        if (!done.isCompleted) done.complete();
      },
      onChunk: (e) => _setItem(
        source,
        ItemStatus(
          phase: ItemPhase.loading,
          progress: e.expectedTotalBytes == null
              ? null
              : e.cumulativeBytesLoaded / e.expectedTotalBytes!,
        ),
      ),
      onError: (Object error, _) {
        if (!done.isCompleted) done.completeError(error);
      },
    );
    stream.addListener(listener);
    try {
      await done.future;
      _setItem(
        source,
        ItemStatus(
          phase: ItemPhase.ready,
          progress: 1,
          origin: inMemory ? CacheOrigin.memory : cache.lastLoadOrigin(source),
          took: watch.elapsed,
        ),
      );
    } on Object catch (e) {
      _setItem(
        source,
        ItemStatus(phase: ItemPhase.failed, error: '$e', took: watch.elapsed),
      );
    } finally {
      stream.removeListener(listener);
      _refreshCounters();
    }
  }

  /// Çözülmüş görselleri bellekten atar (ekrandakiler kalır).
  void clearMemory() {
    track(AppEvent.memoryCleared);
    memory.trim(TrimReason.manual);
    _resetItems();
    _say('Bellek önbelleği boşaltıldı; sıradaki yükleme diskten gelir.');
  }

  /// Diski ve belleği boşaltır.
  Future<void> clearDisk() async {
    track(AppEvent.diskCleared);
    await cache.clearDisk();
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
    _resetItems();
    _say('Disk ve bellek boşaltıldı; sıradaki yükleme kaynaktan gelir.');
  }

  /// Seçili sekmedeki ilk disk dosyasını bozar; sonra yeniden yükler.
  Future<void> corruptFirst() async {
    track(AppEvent.fileCorrupted);
    for (final s in state.sources) {
      if (await cache.corrupt(s)) {
        PaintingBinding.instance.imageCache.clear();
        await precache(s);
        _say(
          '"${s.label}" diskte yarıya kesildi. Önbellek bozuk dosyayı fark '
          'edip sildi ve yeniden indirdi (bozuk: ${cache.stats.corrupted}).',
        );
        return;
      }
    }
    _say('Diskte bozulacak dosya yok: önce "Önceden yükle".');
  }

  /// "Yeni sürüm çıktı" senaryosu: kayıtlı sürüm eskisiyle değiştirilir,
  /// denetim yeniden çalışır.
  Future<void> simulateUpgrade() async {
    track(AppEvent.upgradeSimulated);
    await cache.pretendOldVersion('0.9.0+1');
    final check = await cache.ensureReady();
    _resetItems();
    stateChanger(state.copyWith(version: check));
    _say(
      'Sürüm ${check.previous} → ${check.current}: eski önbellek '
      '(${check.removedFiles} dosya) silindi, bellek boşaltıldı.',
    );
  }

  void _resetItems() => stateChanger(
    state.copyWith(items: const {}, revision: state.revision + 1),
  );

  void _setItem(CachedImageSource source, ItemStatus status) =>
      stateChanger(state.copyWith(items: {...state.items, source.key: status}));

  void _refreshCounters() =>
      stateChanger(state.copyWith(stats: cache.stats, disk: cache.diskUsage()));

  void _say(String message) {
    _refreshCounters();
    stateChanger(state.copyWith(message: () => message));
  }

  void _onSample(MemorySample s) {
    final list = [...state.samples, s];
    stateChanger(
      state.copyWith(
        samples: list.length > 40 ? list.sublist(list.length - 40) : list,
      ),
    );
  }

  void _onTrim(TrimEvent e) =>
      stateChanger(state.copyWith(trims: [e, ...state.trims.take(5)]));

  @override
  Future<void> close() async {
    for (final s in _subs) {
      await s.cancel();
    }
    return super.close();
  }
}
