import 'package:equatable/equatable.dart';
import 'package:flutter_ders/app/core/cache/app_image_cache.dart';
import 'package:flutter_ders/app/core/cache/image_memory_controller.dart';
import 'package:flutter_ders/app/core/cache/image_source.dart';
import 'package:flutter_ders/app/models/image_demo_sources.dart';

/// Bir görselin yükleme durumu.
enum ItemPhase {
  /// Henüz istenmedi.
  idle,

  /// Yükleniyor.
  loading,

  /// Hazır (çözülmüş, bellekte).
  ready,

  /// Hata.
  failed,
}

/// DERS 17 — Tek görselin son yüklenişi.
class ItemStatus extends Equatable {
  /// Durum oluşturur.
  const ItemStatus({
    this.phase = ItemPhase.idle,
    this.progress,
    this.origin,
    this.took,
    this.error,
  });

  /// Aşama.
  final ItemPhase phase;

  /// 0–1 ilerleme.
  final double? progress;

  /// Nereden geldi.
  final CacheOrigin? origin;

  /// Süre.
  final Duration? took;

  /// Hata açıklaması.
  final String? error;

  @override
  List<Object?> get props => [phase, progress, origin, took, error];
}

/// DERS 17 — Görsel önbelleği ekranının durumu.
class ImageCacheLabState extends Equatable {
  /// Durum oluşturur.
  const ImageCacheLabState({
    this.ready = false,
    this.kind = ImageSourceKind.base64,
    this.base64 = const [],
    this.version,
    this.items = const {},
    this.stats,
    this.disk = (files: 0, bytes: 0),
    this.samples = const [],
    this.trims = const [],
    this.ramMb,
    this.message,
    this.revision = 0,
  });

  /// Sürüm denetimi bitti mi?
  final bool ready;

  /// Seçili kaynak.
  final ImageSourceKind kind;

  /// Asset'ten okunan base64 kaynakları.
  final List<Base64ImageSource> base64;

  /// Açılıştaki sürüm denetimi.
  final VersionCheck? version;

  /// Kaynak anahtarı → durum.
  final Map<String, ItemStatus> items;

  /// Önbellek sayaçları.
  final ImageCacheStats? stats;

  /// Disk kullanımı.
  final ({int files, int bytes}) disk;

  /// Son ölçümler (en çok 40).
  final List<MemorySample> samples;

  /// Son boşaltmalar (en çok 6), yeniden eskiye.
  final List<TrimEvent> trims;

  /// Cihaz RAM'i.
  final int? ramMb;

  /// Kısa bilgi (son işlemin sonucu).
  final String? message;

  /// Görsellerin yeniden çizilmesi için sayaç (önbellek boşaltılınca artar).
  final int revision;

  /// Seçili kaynağın görselleri.
  List<CachedImageSource> get sources => switch (kind) {
    ImageSourceKind.base64 => base64,
    ImageSourceKind.s3 => kS3Sources,
    ImageSourceKind.sftp => kSftpSources,
  };

  /// Değişen alanlarla yeni durum.
  ImageCacheLabState copyWith({
    bool? ready,
    ImageSourceKind? kind,
    List<Base64ImageSource>? base64,
    VersionCheck? version,
    Map<String, ItemStatus>? items,
    ImageCacheStats? stats,
    ({int files, int bytes})? disk,
    List<MemorySample>? samples,
    List<TrimEvent>? trims,
    int? ramMb,
    String? Function()? message,
    int? revision,
  }) => ImageCacheLabState(
    ready: ready ?? this.ready,
    kind: kind ?? this.kind,
    base64: base64 ?? this.base64,
    version: version ?? this.version,
    items: items ?? this.items,
    stats: stats ?? this.stats,
    disk: disk ?? this.disk,
    samples: samples ?? this.samples,
    trims: trims ?? this.trims,
    ramMb: ramMb ?? this.ramMb,
    message: message == null ? this.message : message(),
    revision: revision ?? this.revision,
  );

  @override
  List<Object?> get props => [
    ready,
    kind,
    base64,
    version,
    items,
    stats,
    disk,
    samples.length,
    samples.lastOrNull?.at,
    trims.length,
    ramMb,
    message,
    revision,
  ];

  @override
  String toString() =>
      'ImageCacheLabState(${kind.name}, ${items.length} görsel, '
      'disk ${disk.files} dosya, rev $revision)';
}
