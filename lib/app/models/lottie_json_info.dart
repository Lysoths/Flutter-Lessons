import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter/services.dart';

/// DERS 9 — Bir Lottie JSON dosyasının üst bilgileri.
///
/// Lottie dosyası sıradan bir JSON'dur; kökteki kısa anahtarlar:
///
/// | Anahtar | Anlamı |
/// |---|---|
/// | `v` | dosyayı üreten Bodymovin sürümü |
/// | `fr` | saniyedeki kare sayısı (frame rate) |
/// | `ip` / `op` | başlangıç / bitiş karesi (in / out point) |
/// | `w` / `h` | tuvalin eni / boyu (piksel) |
/// | `layers` | katmanlar: her biri şekiller + zamana bağlı değerler |
/// | `assets` | tekrar kullanılan parçalar (ör. iç kompozisyonlar) |
final class LottieJsonInfo extends Equatable {
  /// Bilgileri oluşturur.
  const LottieJsonInfo({
    required this.version,
    required this.frameRate,
    required this.inPoint,
    required this.outPoint,
    required this.width,
    required this.height,
    required this.layerNames,
    required this.byteSize,
    required this.preview,
  });

  /// Çözümlenmiş JSON'dan ([raw] metninden) bilgileri çıkarır.
  factory LottieJsonInfo.parse(String raw) {
    final json = jsonDecode(raw) as Map<String, Object?>;
    final layers = (json['layers'] as List<Object?>?) ?? const [];
    return LottieJsonInfo(
      version: '${json['v'] ?? '?'}',
      frameRate: (json['fr']! as num).toDouble(),
      inPoint: (json['ip']! as num).toDouble(),
      outPoint: (json['op']! as num).toDouble(),
      width: (json['w']! as num).toInt(),
      height: (json['h']! as num).toInt(),
      layerNames: [
        for (final l in layers)
          '${(l! as Map<String, Object?>)['nm'] ?? 'adsız'}',
      ],
      byteSize: utf8.encode(raw).length,
      preview: raw.length > 220 ? '${raw.substring(0, 220)}…' : raw,
    );
  }

  /// Uygulamaya gömülü [assetPath] dosyasını okuyup çözümler.
  static Future<LottieJsonInfo> load(
    String assetPath, {
    AssetBundle? bundle,
  }) async {
    final raw = await (bundle ?? rootBundle).loadString(assetPath);
    return LottieJsonInfo.parse(raw);
  }

  /// `v`.
  final String version;

  /// `fr`.
  final double frameRate;

  /// `ip`.
  final double inPoint;

  /// `op`.
  final double outPoint;

  /// `w`.
  final int width;

  /// `h`.
  final int height;

  /// Katmanların adları (`layers[].nm`).
  final List<String> layerNames;

  /// Dosya boyutu (bayt).
  final int byteSize;

  /// Dosyanın ilk karakterleri.
  final String preview;

  /// Toplam kare sayısı.
  double get frameCount => outPoint - inPoint;

  /// Süre = kare sayısı / saniyedeki kare.
  Duration get duration =>
      Duration(milliseconds: (frameCount / frameRate * 1000).round());

  @override
  List<Object?> get props => [
    version,
    frameRate,
    inPoint,
    outPoint,
    width,
    height,
    layerNames,
    byteSize,
  ];
}
