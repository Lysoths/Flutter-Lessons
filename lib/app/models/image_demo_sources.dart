import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_ders/app/core/cache/image_source.dart';

/// DERS 17 — Görsel önbelleği dersinin üç kaynağı.
enum ImageSourceKind {
  /// API cevabına gömülü base64.
  base64('Base64', 'JSON içinde gömülü'),

  /// Herkese açık S3 kovası.
  s3('S3', 'AWS herkese açık kova'),

  /// SFTP sunucusu.
  sftp('SFTP', 'SSH üzerinden dosya');

  const ImageSourceKind(this.label, this.description);

  /// Kısa ad.
  final String label;

  /// Açıklama.
  final String description;
}

/// Base64 görsellerin bulunduğu dosya (bir API cevabını taklit eder).
const kBase64Asset = 'assets/data/base64_gorseller.json';

/// `assets/data/base64_gorseller.json` → base64 kaynakları.
Future<List<Base64ImageSource>> loadBase64Sources({AssetBundle? bundle}) async {
  final text = await (bundle ?? rootBundle).loadString(kBase64Asset);
  final json = jsonDecode(text) as Map<String, Object?>;
  return [
    for (final item
        in (json['gorseller']! as List).cast<Map<String, Object?>>())
      Base64ImageSource(item['veri']! as String, name: item['ad']! as String),
  ];
}

/// AWS Open Data: Mapzen arazi karoları (`elevation-tiles-prod`).
/// Herkese açık S3 kovası; anahtar istemez, her karo 256×256 PNG.
const kS3Bucket = 'https://elevation-tiles-prod.s3.amazonaws.com';

/// S3'teki örnek karolar.
final List<NetworkImageSource> kS3Sources = [
  for (final (z, x, y) in const [(2, 2, 1), (2, 1, 1), (3, 4, 3), (3, 2, 3)])
    NetworkImageSource(
      '$kS3Bucket/terrarium/$z/$x/$y.png',
      name: 'terrarium $z/$x/$y',
    ),
  for (final (z, x, y) in const [(2, 2, 1), (3, 4, 3)])
    NetworkImageSource(
      '$kS3Bucket/normal/$z/$x/$y.png',
      name: 'normal $z/$x/$y',
    ),
];

/// Bellek denetleyicisini zorlamak için 24 büyük karo (yük testi).
final List<NetworkImageSource> kS3StressSources = [
  for (var x = 0; x < 8; x++)
    for (var y = 2; y < 5; y++)
      NetworkImageSource('$kS3Bucket/normal/3/$x/$y.png', name: 'yük $x/$y'),
];

/// Rebex'in herkese açık test sunucusu (yalnızca okuma). Kullanıcı adı ve
/// şifre sunucunun kendi sayfasında herkese açık yazılı demo hesabıdır.
const kSftpHost = 'test.rebex.net';

/// test.rebex.net'in SSH anahtarları (`ssh-keyscan test.rebex.net |
/// ssh-keygen -lf -`). Başka anahtarla cevap veren sunucu reddedilir.
const kSftpHostKeys = {
  'SHA256:d7Te2DHmvBNSWJNBWik2KbDTjmWtYHe2bvXTMM9lVg4', // ED25519
  'SHA256:OzvpQxRUzSfV9F/ECMXbQ7B7zbK0aTngrhFCBUno65c', // ECDSA
  'SHA256:FFMFsBkaSJbqAeiMb+4c2OJI765czqp6ArYO0GznBJo', // RSA
};

/// SFTP'deki örnek görseller.
final List<SftpImageSource> kSftpSources = [
  for (final name in const [
    'KeyGenerator.png',
    'pocketftp.png',
    'WinFormClient.png',
    'mime-explorer.png',
  ])
    SftpImageSource(
      host: kSftpHost,
      path: '/pub/example/$name',
      username: 'demo',
      password: 'password',
      hostKeyFingerprints: kSftpHostKeys,
    ),
];
