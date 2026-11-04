import 'dart:convert';

import 'package:crypto/crypto.dart';

/// DERS 17 — Bir görselin nereden geldiği.
///
/// Önbellek anahtarı ([key]) kaynağın kendisinden üretilir: aynı adres her
/// zaman aynı dosyaya düşer.
sealed class CachedImageSource {
  const CachedImageSource();

  /// Kaynağı tekil tanımlayan metin.
  String get id;

  /// Ekranda görünen kısa ad.
  String get label;

  /// Disk dosyasının adı: [id]'nin SHA-1 özeti (adreste `/`, `?` olabilir).
  String get key => sha1.convert(utf8.encode(id)).toString();
}

/// Metnin içine gömülü görsel: `data:image/png;base64,iVBORw0...`
///
/// API'ler küçük görselleri (avatar, imza, QR) JSON içinde böyle gönderir.
final class Base64ImageSource extends CachedImageSource {
  /// Kaynak oluşturur.
  const Base64ImageSource(this.data, {required this.name});

  /// `data:` adresi ya da çıplak base64 metni.
  final String data;

  /// Görselin adı.
  final String name;

  @override
  String get id => 'base64:${sha1.convert(utf8.encode(data))}';

  @override
  String get label => name;
}

/// HTTP(S) üzerinden bir adres (ör. herkese açık S3 kovası).
final class NetworkImageSource extends CachedImageSource {
  /// Kaynak oluşturur.
  const NetworkImageSource(this.url, {required this.name});

  /// Tam adres.
  final String url;

  /// Görselin adı.
  final String name;

  @override
  String get id => url;

  @override
  String get label => name;
}

/// SFTP sunucusundaki bir dosya.
final class SftpImageSource extends CachedImageSource {
  /// Kaynak oluşturur.
  const SftpImageSource({
    required this.host,
    required this.path,
    required this.username,
    required this.password,
    required this.hostKeyFingerprints,
    this.port = 22,
  });

  /// Sunucu.
  final String host;

  /// Port.
  final int port;

  /// Dosya yolu.
  final String path;

  /// Kullanıcı adı.
  final String username;

  /// Şifre.
  final String password;

  /// Kabul edilen sunucu anahtarları (`SHA256:...`). Başka bir anahtarla
  /// cevap veren sunucuya bağlanılmaz (araya giren sahte sunucu).
  final Set<String> hostKeyFingerprints;

  @override
  String get id => 'sftp://$username@$host:$port$path';

  @override
  String get label => path.split('/').last;
}
