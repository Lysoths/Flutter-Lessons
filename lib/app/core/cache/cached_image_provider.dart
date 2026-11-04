import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_ders/app/core/cache/app_image_cache.dart';
import 'package:flutter_ders/app/core/cache/image_source.dart';

/// DERS 17 — [AppImageCache]'ten okuyan `ImageProvider`.
///
/// `Image(image: CachedSourceImage(kaynak, cache: c))` ya da
/// `precacheImage(CachedSourceImage(...), context)` ile kullanılır.
///
/// Anahtar (==) kaynak + önbellek sürümüdür: sürüm değişince aynı adres
/// Flutter'ın bellek önbelleğinde de YENİ bir görsel sayılır.
@immutable
class CachedSourceImage extends ImageProvider<CachedSourceImage> {
  /// Görsel oluşturur.
  const CachedSourceImage(this.source, {required this.cache});

  /// Görselin kaynağı.
  final CachedImageSource source;

  /// Okunacak önbellek.
  final AppImageCache cache;

  @override
  Future<CachedSourceImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
    CachedSourceImage key,
    ImageDecoderCallback decode,
  ) {
    final chunks = StreamController<ImageChunkEvent>();
    return MultiFrameImageStreamCompleter(
      codec: _load(decode, chunks),
      chunkEvents: chunks.stream,
      scale: 1,
      debugLabel: source.label,
      informationCollector: () => [
        DiagnosticsProperty<String>('Kaynak', source.id),
      ],
    );
  }

  Future<ui.Codec> _load(
    ImageDecoderCallback decode,
    StreamController<ImageChunkEvent> chunks,
  ) async {
    try {
      final bytes = await cache.load(
        source,
        onProgress: (got, total) {
          if (!chunks.isClosed) {
            chunks.add(
              ImageChunkEvent(
                cumulativeBytesLoaded: got,
                expectedTotalBytes: total,
              ),
            );
          }
        },
      );
      return await decode(await ui.ImmutableBuffer.fromUint8List(bytes));
    } finally {
      unawaited(chunks.close());
    }
  }

  @override
  bool operator ==(Object other) =>
      other is CachedSourceImage &&
      other.source.key == source.key &&
      identical(other.cache, cache);

  @override
  int get hashCode => Object.hash(source.key, cache);

  @override
  String toString() => 'CachedSourceImage(${source.label})';
}
