import 'dart:convert';
import 'dart:ui';

import 'package:equatable/equatable.dart';

// ─────────────────────────────────────────────────────────────────────────
// DERS 18 — Remote Config'ten gelen uygulama ayarları
//
//   tasarim          JSON    renkler, köşe yarıçapları, yazı ölçeği
//   dil_metinleri    JSON    {"tr": {anahtar: metin}, "en": {...}}
//   varsayilan_dil   STRING  tr | en | cihaz
//   min_surum        STRING  altı → zorunlu güncelleme (kilit)
//   son_surum        STRING  altı → kapatılabilir uyarı
//   guncelleme_adresi STRING Güncelle düğmesinin adresi
//
// Varsayılanlar repodaki remoteconfig.template.json'dan okunur; konsola
// yayınlanan şablonla uygulamanın içindeki varsayılan aynı dosyadır.
// Gelen değer bozuksa o alan varsayılanda kalır, uygulama açılmaya devam
// eder.
// ─────────────────────────────────────────────────────────────────────────

/// Remote Config parametre adları.
abstract final class RcKeys {
  /// Tasarım belirteçleri (JSON).
  static const design = 'tasarim';

  /// Dil metinleri (JSON).
  static const texts = 'dil_metinleri';

  /// Varsayılan dil.
  static const language = 'varsayilan_dil';

  /// En düşük desteklenen sürüm.
  static const minVersion = 'min_surum';

  /// En son sürüm.
  static const latestVersion = 'son_surum';

  /// Mağaza adresi.
  static const updateUrl = 'guncelleme_adresi';
}

/// Desteklenen diller.
const kSupportedLanguages = ['tr', 'en'];

/// Güncelleme adresinde izin verilen sunucular.
const kUpdateHosts = {'play.google.com'};

/// Şablon dosyasından (`remoteconfig.template.json`) varsayılanları çıkarır.
Map<String, String> defaultsFromTemplate(String templateJson) {
  final params =
      (jsonDecode(templateJson) as Map<String, Object?>)['parameters']!
          as Map<String, Object?>;
  return {
    for (final MapEntry(:key, :value) in params.entries)
      key:
          ((value! as Map<String, Object?>)['defaultValue']!
                  as Map<String, Object?>)['value']!
              as String,
  };
}

/// Renkler, köşeler ve yazı ölçeği.
class DesignTokens extends Equatable {
  /// Belirteçleri oluşturur.
  const DesignTokens({
    this.primary = const Color(0xFF2563EB),
    this.accent = const Color(0xFFD97757),
    this.button = const Color(0xFF0F172A),
    this.radius = 12,
    this.cardRadius = 16,
    this.textScale = 1,
  });

  /// JSON'dan okur; geçersiz alan varsayılanda kalır.
  factory DesignTokens.fromJson(Map<String, Object?> j) {
    const d = DesignTokens();
    return DesignTokens(
      primary: parseHexColor(j['birincil']) ?? d.primary,
      accent: parseHexColor(j['vurgu']) ?? d.accent,
      button: parseHexColor(j['dugme']) ?? d.button,
      radius: _num(j['kose'], 0, 32) ?? d.radius,
      cardRadius: _num(j['kart_kose'], 0, 40) ?? d.cardRadius,
      textScale: _num(j['yazi_olcegi'], 0.8, 1.4) ?? d.textScale,
    );
  }

  /// Ana renk (seçim, odak, bağlantı).
  final Color primary;

  /// İkincil renk.
  final Color accent;

  /// Dolu düğme rengi.
  final Color button;

  /// Düğme ve alan köşesi.
  final double radius;

  /// Kart köşesi.
  final double cardRadius;

  /// Yazı ölçeği (0.8–1.4).
  final double textScale;

  @override
  List<Object?> get props => [
    primary,
    accent,
    button,
    radius,
    cardRadius,
    textScale,
  ];
}

/// `#RRGGBB` ya da `#AARRGGBB` → renk; geçersizse null.
Color? parseHexColor(Object? v) {
  if (v is! String) return null;
  final m = RegExp(r'^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$').firstMatch(v.trim());
  if (m == null) return null;
  final hex = m.group(1)!;
  return Color(int.parse(hex.length == 6 ? 'FF$hex' : hex, radix: 16));
}

double? _num(Object? v, double min, double max) =>
    v is num && v >= min && v <= max ? v.toDouble() : null;

/// `1.2.3` biçimli sürüm; `+derleme` ve `-ek` yok sayılır.
class SemVer implements Comparable<SemVer> {
  /// Sürüm oluşturur.
  const SemVer(this.major, this.minor, this.patch);

  /// Metinden okur; geçersizse null.
  static SemVer? tryParse(String? s) {
    final m = RegExp(r'^(\d+)(?:\.(\d+))?(?:\.(\d+))?')
        .firstMatch(s?.trim() ?? '');
    if (m == null) return null;
    int g(int i) => int.parse(m.group(i) ?? '0');
    return SemVer(g(1), g(2), g(3));
  }

  /// Ana numara.
  final int major;

  /// Ara numara.
  final int minor;

  /// Yama numarası.
  final int patch;

  @override
  int compareTo(SemVer o) => major != o.major
      ? major.compareTo(o.major)
      : minor != o.minor
      ? minor.compareTo(o.minor)
      : patch.compareTo(o.patch);

  /// Küçük mü?
  bool operator <(SemVer o) => compareTo(o) < 0;

  @override
  String toString() => '$major.$minor.$patch';
}

/// Sürüm denetiminin sonucu.
enum UpdateStatus {
  /// Güncel.
  upToDate,

  /// Yeni sürüm var, kapatılabilir.
  optional,

  /// Desteklenmiyor: uygulama kilitlenir.
  forced,
}

/// Sürüm kuralları.
class VersionPolicy extends Equatable {
  /// Kuralları oluşturur.
  const VersionPolicy({
    required this.min,
    required this.latest,
    required this.updateUrl,
  });

  /// En düşük desteklenen sürüm (null: kural yok).
  final SemVer? min;

  /// En son sürüm (null: kural yok).
  final SemVer? latest;

  /// Güncelle düğmesinin adresi; izinli sunucuda değilse null.
  final Uri? updateUrl;

  /// [installed] sürüme göre durum.
  UpdateStatus statusFor(SemVer? installed) {
    if (installed == null) return UpdateStatus.upToDate;
    if (min case final m? when installed < m) return UpdateStatus.forced;
    if (latest case final l? when installed < l) return UpdateStatus.optional;
    return UpdateStatus.upToDate;
  }

  @override
  List<Object?> get props => [min?.toString(), latest?.toString(), updateUrl];
}

/// Remote Config değerlerinin çözülmüş hali.
class RemoteAppConfig extends Equatable {
  /// Ayarları oluşturur.
  const RemoteAppConfig({
    required this.design,
    required this.texts,
    required this.defaultLanguage,
    required this.policy,
  });

  /// Ham değerlerden okur. [fallback] her alan için yedek kaynaktır
  /// (genelde uygulamanın içindeki varsayılanlar).
  factory RemoteAppConfig.parse(
    Map<String, String> values, {
    Map<String, String> fallback = const {},
  }) {
    String? raw(String k) => values[k] ?? fallback[k];
    Map<String, Object?>? json(String k) {
      for (final s in [values[k], fallback[k]]) {
        try {
          if (s != null) return jsonDecode(s) as Map<String, Object?>;
        } on Object {
          continue;
        }
      }
      return null;
    }

    final textsJson = json(RcKeys.texts) ?? const {};
    final fallbackTexts = () {
      try {
        return jsonDecode(fallback[RcKeys.texts] ?? '{}')
            as Map<String, Object?>;
      } on Object {
        return const <String, Object?>{};
      }
    }();
    final texts = <String, Map<String, String>>{
      for (final lang in kSupportedLanguages)
        lang: {
          // Uzaktaki metinde eksik anahtar varsa uygulamadaki kullanılır.
          ..._stringMap(fallbackTexts[lang]),
          ..._stringMap(textsJson[lang]),
        },
    };
    final url = Uri.tryParse(raw(RcKeys.updateUrl) ?? '');
    return RemoteAppConfig(
      design: DesignTokens.fromJson(json(RcKeys.design) ?? const {}),
      texts: texts,
      defaultLanguage: raw(RcKeys.language)?.trim() ?? 'cihaz',
      policy: VersionPolicy(
        min: SemVer.tryParse(raw(RcKeys.minVersion)),
        latest: SemVer.tryParse(raw(RcKeys.latestVersion)),
        updateUrl:
            url != null &&
                url.scheme == 'https' &&
                kUpdateHosts.contains(url.host)
            ? url
            : null,
      ),
    );
  }

  /// Tasarım belirteçleri.
  final DesignTokens design;

  /// Dil → anahtar → metin.
  final Map<String, Map<String, String>> texts;

  /// `tr`, `en` ya da `cihaz`.
  final String defaultLanguage;

  /// Sürüm kuralları.
  final VersionPolicy policy;

  /// [deviceLanguage] ve kullanıcı seçimi ([override]) ile geçerli dil.
  String resolveLanguage({String? override, String? deviceLanguage}) {
    for (final c in [override, defaultLanguage]) {
      if (c != null && kSupportedLanguages.contains(c)) return c;
    }
    return kSupportedLanguages.contains(deviceLanguage)
        ? deviceLanguage!
        : kSupportedLanguages.first;
  }

  /// [lang] dilinde [key] metni; yoksa Türkçesi, o da yoksa anahtarın kendisi.
  String text(String lang, String key) =>
      texts[lang]?[key] ?? texts[kSupportedLanguages.first]?[key] ?? key;

  @override
  List<Object?> get props => [design, texts, defaultLanguage, policy];
}

Map<String, String> _stringMap(Object? v) => v is Map
    ? {
        for (final MapEntry(:key, :value) in v.entries)
          if (key is String && value is String) key: value,
      }
    : const {};
