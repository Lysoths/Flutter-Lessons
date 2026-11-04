import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:dio/dio.dart';
import 'package:flutter_ders/app/core/cache/image_source.dart';

/// İndirme ilerlemesi: alınan ve (biliniyorsa) toplam bayt.
typedef FetchProgress = void Function(int received, int? total);

/// DERS 17 — Görsel alınamadı.
class ImageFetchFailure implements Exception {
  /// Hata oluşturur.
  const ImageFetchFailure(this.message);

  /// Türkçe açıklama.
  final String message;

  @override
  String toString() => message;
}

/// Kaynağa göre baytları getirir.
abstract interface class ImageFetcher {
  /// [source]'un baytları. Eksik gelirse [ImageFetchFailure] fırlatır.
  Future<Uint8List> fetch(
    CachedImageSource source, {
    FetchProgress? onProgress,
  });
}

/// Üç kaynağı da bilen getirici.
class DefaultImageFetcher implements ImageFetcher {
  /// [dio] ile HTTP, `dartssh2` ile SFTP kullanır.
  DefaultImageFetcher(this._dio, {SftpConnector? sftp})
    : _sftp = sftp ?? connectSftp;

  final Dio _dio;
  final SftpConnector _sftp;

  @override
  Future<Uint8List> fetch(
    CachedImageSource source, {
    FetchProgress? onProgress,
  }) => switch (source) {
    Base64ImageSource(:final data) => Future.value(decodeBase64Image(data)),
    NetworkImageSource(:final url) => _http(url, onProgress),
    final SftpImageSource s => _sftp(s, onProgress),
  };

  Future<Uint8List> _http(String url, FetchProgress? onProgress) async {
    try {
      final r = await _dio.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
        onReceiveProgress: (got, total) =>
            onProgress?.call(got, total > 0 ? total : null),
      );
      final bytes = Uint8List.fromList(r.data ?? const []);
      // Bağlantı yarıda koptuysa gelen bayt sayısı başlıktakinden azdır:
      // yarım görseli önbelleğe yazma.
      final expected = int.tryParse(r.headers.value('content-length') ?? '');
      if (expected != null && expected != bytes.length) {
        throw ImageFetchFailure(
          'Eksik indirme: ${bytes.length} / $expected bayt.',
        );
      }
      return bytes;
    } on DioException catch (e) {
      throw ImageFetchFailure(switch (e.type) {
        DioExceptionType.badResponse =>
          'Sunucu ${e.response?.statusCode} döndürdü.',
        DioExceptionType.connectionError => 'İnternete bağlanılamadı.',
        DioExceptionType.cancel => 'İptal edildi.',
        _ => 'İndirilemedi (${e.type.name}).',
      });
    }
  }
}

/// `data:image/png;base64,...` ya da çıplak base64 metnini baytlara çevirir.
Uint8List decodeBase64Image(String data) {
  final comma = data.indexOf(',');
  final raw = data.startsWith('data:') && comma > 0
      ? data.substring(comma + 1)
      : data;
  try {
    return base64Decode(raw.replaceAll(RegExp(r'\s'), ''));
  } on FormatException {
    throw const ImageFetchFailure('Base64 metni bozuk.');
  }
}

/// SFTP'den dosya indiren fonksiyon (testte sahtesi verilir).
typedef SftpConnector = Future<Uint8List> Function(
  SftpImageSource source,
  FetchProgress? onProgress,
);

/// SSH bağlantısı kurar, sunucu anahtarını doğrular, dosyayı okur.
///
///   SSHSocket.connect → SSHClient (anahtar + şifre) → client.sftp()
///   → sftp.open(yol) → file.stat() (boyut) → file.read() (parça parça)
Future<Uint8List> connectSftp(
  SftpImageSource s,
  FetchProgress? onProgress,
) async {
  SSHClient? client;
  // dartssh2 reddedilen anahtarı bazen giriş hatası olarak iletir; hangisi
  // olduğunu buradan biliriz.
  var hostKeyRejected = false;
  try {
    final socket = await SSHSocket.connect(
      s.host,
      s.port,
      timeout: const Duration(seconds: 10),
    );
    client = SSHClient(
      socket,
      username: s.username,
      onPasswordRequest: () => s.password,
      onVerifyHostKey: (type, fingerprint) {
        final ok = s.hostKeyFingerprints.contains(utf8.decode(fingerprint));
        hostKeyRejected = !ok;
        return ok;
      },
    );
    final sftp = await client.sftp();
    final file = await sftp.open(s.path);
    final size = (await file.stat()).size;
    final out = BytesBuilder(copy: false);
    await for (final chunk in file.read(
      onProgress: (read) => onProgress?.call(read, size),
    )) {
      out.add(chunk);
    }
    await file.close();
    final bytes = out.takeBytes();
    if (size != null && size != bytes.length) {
      throw ImageFetchFailure('Eksik indirme: ${bytes.length} / $size bayt.');
    }
    return bytes;
  } on SSHHostkeyError {
    throw const ImageFetchFailure(_hostKeyMessage);
  } on SSHAuthError {
    throw ImageFetchFailure(
      hostKeyRejected ? _hostKeyMessage : 'SFTP girişi reddedildi.',
    );
  } on SftpStatusError catch (e) {
    throw ImageFetchFailure('SFTP: ${e.message}');
  } on ImageFetchFailure {
    rethrow;
  } on Object catch (e) {
    throw ImageFetchFailure(
      hostKeyRejected ? _hostKeyMessage : 'SFTP bağlantısı kurulamadı: $e',
    );
  } finally {
    if (client != null) unawaited(Future.value(client.close()));
  }
}

const _hostKeyMessage =
    'Sunucu anahtarı tanınmadı: bağlantı reddedildi (sahte sunucu olabilir).';
