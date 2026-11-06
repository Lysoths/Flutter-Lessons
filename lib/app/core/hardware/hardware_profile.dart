import 'dart:math' as math;

import 'package:equatable/equatable.dart';

// ─────────────────────────────────────────────────────────────────────────
// DERS 22 — Kanaldan gelen haritayı tipli modele çevirmek
//
// StandardMessageCodec yalnız temel tipleri taşır: String, int, double,
// bool, List, Map, null. Kotlin'in gönderdiği `Map<String, Any?>` Dart'a
// `Map<Object?, Object?>` olarak gelir; içindeki her alanı tipiyle okuyup
// modele çevirmek bizim işimiz. [ChannelMap] bunu güvenle yapar: alan
// yoksa ya da tipi beklenmedikse `null` döner, uygulama çökmez.
//
// Bu dosya eklenti bilmez; test, Kotlin'in döndürdüğü biçimde bir harita
// vererek "sözleşmeyi" dener.
// ─────────────────────────────────────────────────────────────────────────

/// Kanal haritasını tipli okur.
extension type const ChannelMap(Map<Object?, Object?> raw) {
  /// [value] harita değilse boş harita.
  static ChannelMap of(Object? value) =>
      ChannelMap(value is Map ? value.cast<Object?, Object?>() : const {});

  /// Metin.
  String? text(String key) {
    final v = raw[key];
    return v is String && v.isNotEmpty ? v : null;
  }

  /// Tam sayı (Kotlin Int ve Long ikisi de Dart'ta int'tir).
  int? integer(String key) {
    final v = raw[key];
    return v is num ? v.toInt() : null;
  }

  /// Ondalık.
  double? decimal(String key) {
    final v = raw[key];
    return v is num ? v.toDouble() : null;
  }

  /// Doğru / yanlış.
  bool? flag(String key) {
    final v = raw[key];
    return v is bool ? v : null;
  }

  /// İç harita.
  ChannelMap child(String key) => of(raw[key]);

  /// Liste; her öğe [convert] ile çevrilir, `null` dönenler atılır.
  List<T> list<T>(String key, T? Function(Object? item) convert) {
    final v = raw[key];
    if (v is! List) return const [];
    return [for (final item in v) ?convert(item)];
  }

  /// Sırası anlamlı tam sayı listesi (çekirdek 0, 1, 2 ...): okunamayan
  /// öğe atılmaz, yerinde `null` kalır; yoksa çekirdek numaraları kayardı.
  List<int?> slots(String key) {
    final v = raw[key];
    if (v is! List) return const [];
    return [for (final item in v) item is int ? item : null];
  }
}

/// Telefonun kimliği.
final class IdentityInfo extends Equatable {
  /// Kanaldan okur.
  IdentityInfo.fromChannel(ChannelMap m)
    : manufacturer = m.text('uretici'),
      brand = m.text('marka'),
      model = m.text('model'),
      device = m.text('cihaz'),
      product = m.text('urun'),
      hardware = m.text('donanim'),
      board = m.text('kart'),
      androidId = m.text('androidId');

  /// Üretici (samsung).
  final String? manufacturer;

  /// Marka.
  final String? brand;

  /// Model kodu (SM-S938B).
  final String? model;

  /// Cihaz kod adı.
  final String? device;

  /// Ürün adı.
  final String? product;

  /// Donanım platformu.
  final String? hardware;

  /// Anakart.
  final String? board;

  /// Bu uygulamaya ve kullanıcıya özel 64 bit kimlik. Gizli tutulur.
  final String? androidId;

  /// "Samsung SM-S938B".
  String get title {
    final b = brand ?? manufacturer ?? '';
    final name = b.isEmpty ? '' : '${b[0].toUpperCase()}${b.substring(1)}';
    return [name, ?model].join(' ').trim();
  }

  @override
  List<Object?> get props => [manufacturer, brand, model, device, androidId];
}

/// İşletim sistemi.
final class SystemInfo extends Equatable {
  /// Kanaldan okur.
  SystemInfo.fromChannel(ChannelMap m)
    : release = m.text('surum'),
      sdk = m.integer('sdk'),
      securityPatch = m.text('yama'),
      build = m.text('derleme'),
      fingerprint = m.text('parmakIzi'),
      bootloader = m.text('bootloader'),
      kernel = m.text('cekirdek'),
      buildTime = switch (m.integer('derlemeZamani')) {
        final ms? when ms > 0 => DateTime.fromMillisecondsSinceEpoch(ms),
        _ => null,
      },
      uptime = Duration(milliseconds: m.integer('acikKalma') ?? 0),
      locale = m.text('dil'),
      timeZone = m.text('saatDilimi');

  /// Android sürümü ("16").
  final String? release;

  /// API düzeyi (36).
  final int? sdk;

  /// Güvenlik yaması (2026-10-01).
  final String? securityPatch;

  /// Derleme numarası.
  final String? build;

  /// Derleme parmak izi.
  final String? fingerprint;

  /// Bootloader sürümü.
  final String? bootloader;

  /// Linux çekirdeği.
  final String? kernel;

  /// Derleme zamanı.
  final DateTime? buildTime;

  /// Son açılıştan beri geçen süre.
  final Duration uptime;

  /// Dil etiketi (tr-TR).
  final String? locale;

  /// Saat dilimi.
  final String? timeZone;

  @override
  List<Object?> get props => [release, sdk, securityPatch, build, uptime];
}

/// İşlemci.
final class CpuInfo extends Equatable {
  /// Kanaldan okur.
  CpuInfo.fromChannel(ChannelMap m)
    : cores = m.integer('cekirdekSayisi') ?? 0,
      abis = m.list('abiler', (v) => v is String ? v : null),
      socMaker = m.text('socUretici'),
      socModel = m.text('socModel'),
      maxKhz = m.slots('enYuksekKhz'),
      minKhz = m.slots('enDusukKhz');

  /// Çekirdek sayısı.
  final int cores;

  /// Desteklenen ABI'ler (arm64-v8a ...).
  final List<String> abis;

  /// Yonga üreticisi (Android 12+).
  final String? socMaker;

  /// Yonga modeli (Android 12+).
  final String? socModel;

  /// Okunabilen çekirdeklerin en yüksek frekansı (kHz).
  final List<int?> maxKhz;

  /// Okunabilen çekirdeklerin en düşük frekansı (kHz).
  final List<int?> minKhz;

  /// Çekirdek kümeleri: aynı en yüksek frekansa sahip çekirdekler bir
  /// küme sayılır (ör. 2 × 4,47 GHz + 6 × 3,53 GHz).
  List<({int count, int khz})> get clusters {
    final counts = <int, int>{};
    for (final f in maxKhz) {
      if (f != null && f > 0) counts[f] = (counts[f] ?? 0) + 1;
    }
    final list = [
      for (final MapEntry(:key, :value) in counts.entries)
        (count: value, khz: key),
    ];
    return list..sort((a, b) => b.khz.compareTo(a.khz));
  }

  /// En hızlı çekirdeğin frekansı.
  int? get peakKhz => clusters.isEmpty ? null : clusters.first.khz;

  @override
  List<Object?> get props => [cores, abis, socMaker, socModel, maxKhz];
}

/// Bellek.
final class MemoryInfo extends Equatable {
  /// Kanaldan okur.
  MemoryInfo.fromChannel(ChannelMap m)
    : total = m.integer('toplam') ?? 0,
      free = m.integer('bos') ?? 0,
      threshold = m.integer('esik') ?? 0,
      low = m.flag('dusuk') ?? false,
      appLimitMb = m.integer('uygulamaSiniriMb');

  /// Toplam RAM (bayt).
  final int total;

  /// Kullanılabilir RAM (bayt).
  final int free;

  /// Sistemin "bellek az" saydığı eşik (bayt).
  final int threshold;

  /// Şu an bellek az mı?
  final bool low;

  /// Bir uygulamanın kullanabileceği yığın sınırı (MB).
  final int? appLimitMb;

  @override
  List<Object?> get props => [total, free, low];
}

/// Dahili depolama.
final class StorageInfo extends Equatable {
  /// Kanaldan okur.
  StorageInfo.fromChannel(ChannelMap m)
    : total = m.integer('toplam') ?? 0,
      free = m.integer('bos') ?? 0;

  /// Toplam (bayt).
  final int total;

  /// Boş (bayt).
  final int free;

  @override
  List<Object?> get props => [total, free];
}

/// Pil.
final class BatteryInfo extends Equatable {
  /// Kanaldan okur.
  BatteryInfo.fromChannel(ChannelMap m)
    : percent = m.integer('yuzde'),
      status = m.text('durum') ?? 'bilinmiyor',
      health = m.text('saglik') ?? 'bilinmiyor',
      source = m.text('kaynak'),
      temperature = m.decimal('sicaklik'),
      voltageMv = m.integer('voltajMv'),
      technology = m.text('teknoloji'),
      cycles = m.integer('dongu'),
      chargeMah = m.integer('sarjMah'),
      currentUa = m.integer('akimUa');

  /// Doluluk (%).
  final int? percent;

  /// sarj_oluyor | dolu | desarj | bilinmiyor.
  final String status;

  /// iyi | asiri_isinma | olu | yuksek_voltaj | soguk | bilinmiyor.
  final String health;

  /// priz | usb | kablosuz | null (takılı değil).
  final String? source;

  /// Sıcaklık (°C).
  final double? temperature;

  /// Voltaj (mV).
  final int? voltageMv;

  /// Kimya (Li-ion).
  final String? technology;

  /// Şarj döngüsü (Android 14+, üretici verirse).
  final int? cycles;

  /// Kalan şarj (mAh).
  final int? chargeMah;

  /// Anlık akım (µA); eksi: pilden çekiliyor.
  final int? currentUa;

  @override
  List<Object?> get props => [percent, status, health, temperature, cycles];
}

/// Ekran.
final class DisplayInfo extends Equatable {
  /// Kanaldan okur.
  DisplayInfo.fromChannel(ChannelMap m)
    : width = m.integer('genislik') ?? 0,
      height = m.integer('yukseklik') ?? 0,
      dpi = m.integer('dpi'),
      xdpi = m.decimal('xdpi'),
      ydpi = m.decimal('ydpi'),
      refreshRate = m.decimal('yenileme'),
      refreshRates = m.list(
        'yenilemeler',
        (v) => v is num ? v.toDouble() : null,
      ),
      hdr = m.list('hdr', (v) => v is String ? v : null),
      fontScale = m.decimal('yaziOlcegi');

  /// Fiziksel genişlik (piksel).
  final int width;

  /// Fiziksel yükseklik (piksel).
  final int height;

  /// Yoğunluk sınıfı (dpi).
  final int? dpi;

  /// Gerçek yatay piksel yoğunluğu.
  final double? xdpi;

  /// Gerçek dikey piksel yoğunluğu.
  final double? ydpi;

  /// Şu anki yenileme hızı (Hz).
  final double? refreshRate;

  /// Desteklenen yenileme hızları.
  final List<double> refreshRates;

  /// HDR türleri.
  final List<String> hdr;

  /// Yazı ölçeği.
  final double? fontScale;

  /// Köşegen (inç); yoğunluk bilinmiyorsa `null`.
  double? get diagonalInches {
    final x = xdpi;
    final y = ydpi;
    if (x == null || y == null || x <= 0 || y <= 0) return null;
    final w = math.min(width, height) / x;
    final h = math.max(width, height) / y;
    return math.sqrt(w * w + h * h);
  }

  @override
  List<Object?> get props => [width, height, dpi, refreshRate, hdr];
}

/// Bir kamera.
final class CameraInfo extends Equatable {
  /// Kanaldan okur.
  CameraInfo.fromChannel(ChannelMap m)
    : id = m.text('id') ?? '?',
      facing = m.text('yon') ?? 'harici',
      megapixels = m.decimal('megapiksel'),
      focalLengths = m.list(
        'odakUzakliklari',
        (v) => v is num ? v.toDouble() : null,
      ),
      flash = m.flag('flas') ?? false,
      stabilized = m.flag('ois') ?? false;

  /// Kamera kimliği.
  final String id;

  /// on | arka | harici.
  final String facing;

  /// Sensör çözünürlüğü (MP).
  final double? megapixels;

  /// Odak uzaklıkları (mm).
  final List<double> focalLengths;

  /// Flaş var mı?
  final bool flash;

  /// Optik sabitleme (OIS) var mı?
  final bool stabilized;

  @override
  List<Object?> get props => [id, facing, megapixels];
}

/// Bir sensör.
final class SensorInfo extends Equatable {
  /// Kanaldan okur.
  SensorInfo.fromChannel(ChannelMap m)
    : name = m.text('ad') ?? '?',
      vendor = m.text('uretici'),
      type = m.text('tur'),
      powerMa = m.decimal('gucMa'),
      range = m.decimal('aralik'),
      wakeUp = m.flag('uyandirir') ?? false;

  /// Ad.
  final String name;

  /// Üretici.
  final String? vendor;

  /// Tür (android.sensor.accelerometer).
  final String? type;

  /// Güç tüketimi (mA).
  final double? powerMa;

  /// En büyük ölçüm.
  final double? range;

  /// Telefonu uyandırabilen sensör mü?
  final bool wakeUp;

  /// "android.sensor.step_counter" → "step_counter".
  String get shortType => (type ?? '').split('.').last;

  @override
  List<Object?> get props => [name, vendor, type];
}

/// SIM ve mobil ağ.
final class TelephonyInfo extends Equatable {
  /// Kanaldan okur.
  TelephonyInfo.fromChannel(ChannelMap m)
    : present = m.flag('var') ?? false,
      granted = m.flag('izin') ?? false,
      operatorName = m.text('operator'),
      simOperator = m.text('simOperator'),
      simCountry = m.text('simUlke'),
      networkCountry = m.text('agUlke'),
      roaming = m.flag('dolasim') ?? false,
      slots = m.integer('yuva'),
      activeSims = m.integer('aktifSim'),
      network = m.text('ag'),
      phoneType = m.text('tur');

  /// Telefon donanımı var mı?
  final bool present;

  /// READ_PHONE_STATE verildi mi?
  final bool granted;

  /// Bağlı şebeke.
  final String? operatorName;

  /// SIM'in operatörü.
  final String? simOperator;

  /// SIM ülkesi (TR).
  final String? simCountry;

  /// Şebeke ülkesi.
  final String? networkCountry;

  /// Dolaşımda mı?
  final bool roaming;

  /// SIM yuvası sayısı.
  final int? slots;

  /// Etkin SIM sayısı (izin gerekir).
  final int? activeSims;

  /// Veri ağı (5G, 4G ...; izin gerekir).
  final String? network;

  /// GSM | CDMA | SIP | Yok.
  final String? phoneType;

  @override
  List<Object?> get props => [present, granted, operatorName, network];
}

/// Telefonun bütün profili.
final class DeviceProfile extends Equatable {
  /// Kanaldan okur.
  DeviceProfile.fromChannel(Object? value) : this._(ChannelMap.of(value));

  DeviceProfile._(ChannelMap m)
    : identity = IdentityInfo.fromChannel(m.child('kimlik')),
      system = SystemInfo.fromChannel(m.child('sistem')),
      cpu = CpuInfo.fromChannel(m.child('islemci')),
      memory = MemoryInfo.fromChannel(m.child('bellek')),
      storage = StorageInfo.fromChannel(m.child('depolama')),
      battery = BatteryInfo.fromChannel(m.child('pil')),
      display = DisplayInfo.fromChannel(m.child('ekran')),
      cameras = m.list(
        'kameralar',
        (v) => CameraInfo.fromChannel(ChannelMap.of(v)),
      ),
      sensors = m.list(
        'sensorler',
        (v) => SensorInfo.fromChannel(ChannelMap.of(v)),
      ),
      features = {
        for (final MapEntry(:key, :value) in m.child('ozellikler').raw.entries)
          if (key is String && value is bool) key: value,
      },
      telephony = TelephonyInfo.fromChannel(m.child('telefon'));

  /// Kimlik.
  final IdentityInfo identity;

  /// Sistem.
  final SystemInfo system;

  /// İşlemci.
  final CpuInfo cpu;

  /// RAM.
  final MemoryInfo memory;

  /// Depolama.
  final StorageInfo storage;

  /// Pil.
  final BatteryInfo battery;

  /// Ekran.
  final DisplayInfo display;

  /// Kameralar.
  final List<CameraInfo> cameras;

  /// Sensörler.
  final List<SensorInfo> sensors;

  /// Donanım özellikleri (nfc → true ...).
  final Map<String, bool> features;

  /// SIM ve ağ.
  final TelephonyInfo telephony;

  // Bloc gözlemcisi durumları konsola yazar: kimlik ve parmak izi gibi
  // değerler log'a düşmesin.
  @override
  String toString() =>
      'DeviceProfile(${cpu.cores} çekirdek, ${cameras.length} kamera, '
      '${sensors.length} sensör)';

  @override
  List<Object?> get props => [
    identity,
    system,
    cpu,
    memory,
    storage,
    battery,
    display,
    cameras,
    sensors,
    features,
    telephony,
  ];
}

/// Saniyede bir gelen canlı ölçüm.
final class LiveReading extends Equatable {
  /// Kanaldan okur; bozuksa `null`.
  static LiveReading? fromChannel(Object? value) {
    final m = ChannelMap.of(value);
    final ms = m.integer('zaman');
    if (ms == null) return null;
    return LiveReading(
      time: DateTime.fromMillisecondsSinceEpoch(ms),
      battery: m.integer('pil'),
      temperature: m.decimal('sicaklik'),
      currentUa: m.integer('akimUa'),
      charging: m.flag('sarjOluyor') ?? false,
      freeRam: m.integer('bosRam'),
      coreKhz: m.slots('anlikKhz'),
    );
  }

  /// Oluşturur.
  const LiveReading({
    required this.time,
    this.battery,
    this.temperature,
    this.currentUa,
    this.charging = false,
    this.freeRam,
    this.coreKhz = const [],
  });

  /// Ölçüm zamanı.
  final DateTime time;

  /// Pil (%).
  final int? battery;

  /// Pil sıcaklığı (°C).
  final double? temperature;

  /// Akım (µA).
  final int? currentUa;

  /// Şarj oluyor mu?
  final bool charging;

  /// Boş RAM (bayt).
  final int? freeRam;

  /// Çekirdeklerin anlık frekansı (kHz; okunamayan `null`).
  final List<int?> coreKhz;

  @override
  List<Object?> get props => [time, battery, temperature, currentUa, freeRam];
}

/// IMEI denemesinin sonucu.
sealed class ImeiResult {
  const ImeiResult();
}

/// Okundu (yalnız sistem uygulamalarında ya da eski Android'de).
final class ImeiRead extends ImeiResult {
  /// Oluşturur.
  const ImeiRead(this.value);

  /// IMEI.
  final String value;
}

/// Android vermedi.
final class ImeiBlocked extends ImeiResult {
  /// Oluşturur.
  const ImeiBlocked({required this.code, this.message, this.sdk});

  /// Kanal hata kodu (sistem_izni, telefon_yok, bos).
  final String code;

  /// Android'in hata mesajı.
  final String? message;

  /// Cihazın API düzeyi.
  final int? sdk;
}
