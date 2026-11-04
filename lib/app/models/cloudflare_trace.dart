import 'package:equatable/equatable.dart';
import 'package:flutter_ders/app/models/info_section.dart';

/// DERS 14 — `https://1.1.1.1/cdn-cgi/trace` cevabı.
///
/// Cevap JSON değil, düz metin; her satır `anahtar=değer`:
///
///   fl=123f45
///   h=1.1.1.1
///   ip=…            ← internete çıktığın (genel) IP
///   ts=1730700000.123
///   visit_scheme=https
///   uag=Dart/3.13 (dart:io)
///   colo=IST        ← cevap veren Cloudflare veri merkezi (havalimanı kodu)
///   http=http/1.1
///   loc=TR
///   tls=TLSv1.3
///   sni=off
///   warp=off
///   ...
///
/// Telefon kendi genel IP'sini bilemez (modem/operatör NAT'ı arkasında);
/// dışarıdaki bir sunucu "seni hangi adresten gördüm" diye söyler.
class CloudflareTrace extends Equatable {
  /// Alanlardan oluşturur.
  const CloudflareTrace(this.fields);

  /// Metni satır satır ayrıştırır; `=` içermeyen satırlar atlanır.
  factory CloudflareTrace.parse(String body) => CloudflareTrace({
    for (final line in body.split('\n'))
      if (line.indexOf('=') case final i when i > 0)
        line.substring(0, i).trim(): line.substring(i + 1).trim(),
  });

  /// Ham alanlar, geldiği sırayla.
  final Map<String, String> fields;

  /// Genel IP.
  String? get ip => fields['ip'];

  /// IPv6 mı (adreste `:` var mı)?
  bool get isIpv6 => ip?.contains(':') ?? false;

  /// Veri merkezi kodu (ör. IST).
  String? get colo => fields['colo'];

  /// Ülke kodu (ör. TR).
  String? get loc => fields['loc'];

  /// Sunucu saati.
  DateTime? get serverTime => switch (double.tryParse(fields['ts'] ?? '')) {
    final s? => DateTime.fromMicrosecondsSinceEpoch((s * 1e6).round()),
    null => null,
  };

  /// Ekranda gösterilecek iki bölüm: bağlantı ve güvenlik.
  List<InfoSection> toSections({DateTime? now}) {
    final f = Map.of(fields);
    String take(String key) => orDash(f.remove(key));
    final server = serverTime;
    final skew = server == null
        ? '—'
        : '${(now ?? DateTime.now()).difference(server).inMilliseconds} ms';
    final country = loc;
    return [
      InfoSection(
        id: 'trace',
        title: 'Dışarıdan görünen bağlantı',
        entries: [
          InfoEntry('Genel IP', take('ip'), sensitive: true),
          InfoEntry('IP türü', ip == null ? '—' : (isIpv6 ? 'IPv6' : 'IPv4')),
          InfoEntry(
            'Ülke (loc)',
            country == null ? take('loc') : '${_flag(country)} ${take('loc')}',
          ),
          InfoEntry('Veri merkezi (colo)', _colo(take('colo'))),
          InfoEntry('HTTP sürümü', take('http')),
          InfoEntry('Şema', take('visit_scheme')),
          InfoEntry('İstemci (uag)', take('uag')),
          InfoEntry('Hedef (h)', take('h')),
          InfoEntry('Sunucu saati', _time(server)),
          InfoEntry('Cihaz saat farkı', skew),
        ],
      ),
      InfoSection(
        id: 'tls',
        title: 'Güvenlik ve Cloudflare',
        entries: [
          InfoEntry('TLS sürümü', take('tls')),
          InfoEntry('Anahtar değişimi (kex)', take('kex')),
          InfoEntry('SNI', take('sni')),
          InfoEntry('WARP (Cloudflare VPN)', take('warp')),
          InfoEntry('Gateway (Zero Trust)', take('gateway')),
          InfoEntry('Tarayıcı yalıtımı (rbi)', take('rbi')),
          InfoEntry('Sliver', take('sliver')),
          InfoEntry('İstek kimliği (fl)', take('fl')),
          InfoEntry('Zaman damgası (ts)', take('ts')),
          // Yukarıda olmayan, ileride eklenecek alanlar da kaybolmasın.
          for (final e in f.entries) InfoEntry(e.key, e.value),
        ],
      ),
    ];
  }

  @override
  List<Object?> get props => [fields];

  // IP konsola yazılmasın.
  @override
  String toString() => 'CloudflareTrace(${fields.length} alan, colo=$colo)';
}

/// İki harfli ülke kodunu bayrak emojisine çevirir (TR → 🇹🇷).
String _flag(String code) => code.length != 2
    ? ''
    : String.fromCharCodes(
        code.toUpperCase().codeUnits.map((c) => 0x1F1E6 + c - 0x41),
      );

const _airports = {
  'IST': 'İstanbul',
  'ESB': 'Ankara',
  'ADB': 'İzmir',
  'FRA': 'Frankfurt',
  'AMS': 'Amsterdam',
  'SOF': 'Sofya',
  'OTP': 'Bükreş',
  'VIE': 'Viyana',
  'LHR': 'Londra',
  'CDG': 'Paris',
};

String _colo(String code) => switch (_airports[code]) {
  final city? => '$code · $city',
  null => code,
};

String _time(DateTime? d) {
  if (d == null) return '—';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.hour)}:${two(d.minute)}:${two(d.second)}';
}
