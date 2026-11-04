import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_ders/app/models/cloudflare_trace.dart';
import 'package:flutter_ders/app/models/info_section.dart';
import 'package:network_info_plus/network_info_plus.dart';

// ─────────────────────────────────────────────────────────────────────────
// DERS 14 — Ağ bilgisi iki yerden gelir:
//
//   İçeriden (cihaz)   connectivity_plus  → bağlantı türü (Wi-Fi, mobil, VPN)
//                      network_info_plus  → Wi-Fi adı, yerel IP, ağ geçidi
//                      dart:io            → ağ arayüzleri (wlan0, rmnet ...)
//   Dışarıdan (sunucu) 1.1.1.1/cdn-cgi/trace → genel IP, ülke, veri merkezi
//
// Genel IP'yi telefon bilemez: modem/operatör adres çevirisi (NAT) yapar.
// IP'ler ekranda gizli başlar; kaydedilmez, konsola yazılmaz.
// ─────────────────────────────────────────────────────────────────────────

/// Cihazın kendi gördüğü ağ bilgisi.
typedef LocalNetworkReport = ({
  List<ConnectivityResult> connection,
  List<InfoSection> sections,
});

/// Wi-Fi adı satırının etiketi.
const kSsidLabel = 'Ağ adı (SSID)';

/// Cihaz içi ağ bilgisinin kaynağı; testte sahtesi verilir.
abstract interface class LocalNetworkSource {
  /// Bağlantı türü, Wi-Fi ve arayüzleri okur.
  Future<LocalNetworkReport> read();

  /// Bağlantı türü her değiştiğinde yeni liste yayar (STREAM).
  Stream<List<ConnectivityResult>> changes();
}

/// Dışarıdan görünen bağlantı bilgisinin kaynağı.
abstract interface class TraceRepository {
  /// Trace ister; olmazsa [TraceFailure] fırlatır.
  Future<CloudflareTrace> fetch();
}

/// Trace isteği başarısız oldu.
class TraceFailure implements Exception {
  /// Hata oluşturur.
  const TraceFailure(this.message);

  /// Kullanıcıya gösterilecek açıklama.
  final String message;

  @override
  String toString() => message;
}

/// `connectivity_plus`, `network_info_plus` ve `dart:io` ile okur.
class DeviceLocalNetworkSource implements LocalNetworkSource {
  /// Kaynak oluşturur.
  DeviceLocalNetworkSource({Connectivity? connectivity, NetworkInfo? wifi})
    : _connectivity = connectivity ?? Connectivity(),
      _wifi = wifi ?? NetworkInfo();

  final Connectivity _connectivity;
  final NetworkInfo _wifi;

  @override
  Stream<List<ConnectivityResult>> changes() =>
      _connectivity.onConnectivityChanged;

  @override
  Future<LocalNetworkReport> read() async {
    final connection = await _connectivity.checkConnectivity();
    // Her çağrı ayrı bir kanal çağrısı; hata verirse yalnızca o alan "—".
    Future<String?> safe(Future<String?> Function() f) async {
      try {
        return await f();
      } on Exception {
        return null;
      }
    }

    final values = await Future.wait([
      safe(_wifi.getWifiName),
      safe(_wifi.getWifiBSSID),
      safe(_wifi.getWifiIP),
      safe(_wifi.getWifiIPv6),
      safe(_wifi.getWifiSubmask),
      safe(_wifi.getWifiGatewayIP),
      safe(_wifi.getWifiBroadcast),
    ]);
    // Android adı tırnakla döndürür: "EvAgi" → EvAgi. İzin yoksa adın
    // yerine '<unknown ssid>', BSSID yerine sahte bir adres verir.
    final ssid = switch (values[0]?.replaceAll('"', '')) {
      '<unknown ssid>' => null,
      final name => name,
    };
    final bssid = values[1] == '02:00:00:00:00:00' ? null : values[1];
    final interfaces = await NetworkInterface.list(includeLinkLocal: true);
    return (
      connection: connection,
      sections: [
        InfoSection(
          id: 'connectivity',
          title: 'Bağlantı türü (connectivity_plus)',
          entries: [
            InfoEntry(
              'Etkin bağlantılar',
              connection.map(connectivityLabel).join(', '),
            ),
            InfoEntry(
              'VPN',
              connection.contains(ConnectivityResult.vpn) ? 'Açık' : 'Kapalı',
            ),
            InfoEntry('Arayüz sayısı', '${interfaces.length}'),
          ],
        ),
        InfoSection(
          id: 'wifi',
          title: 'Wi-Fi (network_info_plus)',
          entries: [
            InfoEntry(kSsidLabel, orDash(ssid), sensitive: true),
            InfoEntry('Erişim noktası (BSSID)', orDash(bssid), sensitive: true),
            InfoEntry('Yerel IPv4', orDash(values[2]), sensitive: true),
            InfoEntry('Yerel IPv6', orDash(values[3]), sensitive: true),
            InfoEntry('Alt ağ maskesi', orDash(values[4])),
            InfoEntry('Ağ geçidi (modem)', orDash(values[5]), sensitive: true),
            InfoEntry('Yayın adresi', orDash(values[6])),
          ],
        ),
        InfoSection(
          id: 'interfaces',
          title: 'Ağ arayüzleri (dart:io)',
          entries: [
            for (final i in interfaces)
              InfoEntry(
                '${i.name} (#${i.index})',
                i.addresses
                    .map(
                      (a) =>
                          '${a.type == InternetAddressType.IPv6 ? 'v6' : 'v4'} ${a.address}',
                    )
                    .join('\n'),
                sensitive: true,
              ),
          ],
        ),
      ],
    );
  }
}

/// Bağlantı türünün Türkçe adı.
String connectivityLabel(ConnectivityResult r) => switch (r) {
  ConnectivityResult.wifi => 'Wi-Fi',
  ConnectivityResult.mobile => 'Mobil veri',
  ConnectivityResult.ethernet => 'Ethernet',
  ConnectivityResult.vpn => 'VPN',
  ConnectivityResult.bluetooth => 'Bluetooth',
  ConnectivityResult.satellite => 'Uydu',
  ConnectivityResult.other => 'Diğer',
  ConnectivityResult.none => 'Bağlantı yok',
};

/// Cloudflare'in herkese açık trace sayfası. Anahtar istemez; isteğe
/// kişisel veri eklenmez.
class CloudflareTraceRepository implements TraceRepository {
  /// [dio] üzerinden çalışan depo oluşturur.
  CloudflareTraceRepository(this._dio);

  /// İstek adresi. Tam adres verildiği için Dio'nun kök adresi kullanılmaz.
  static const url = 'https://1.1.1.1/cdn-cgi/trace';

  final Dio _dio;

  @override
  Future<CloudflareTrace> fetch() async {
    try {
      final response = await _dio.get<String>(
        url,
        // Cevap JSON değil düz metin.
        options: Options(responseType: ResponseType.plain),
      );
      return CloudflareTrace.parse(response.data ?? '');
    } on DioException catch (e) {
      throw TraceFailure(switch (e.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.receiveTimeout ||
        DioExceptionType.sendTimeout => 'Cloudflare zamanında cevap vermedi.',
        DioExceptionType.connectionError => 'İnternete bağlanılamadı.',
        DioExceptionType.badResponse =>
          'Cloudflare hata döndürdü (${e.response?.statusCode}).',
        _ => 'Trace alınamadı.',
      });
    }
  }
}
