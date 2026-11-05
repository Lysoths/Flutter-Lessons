import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;

// ─────────────────────────────────────────────────────────────────────────
// DERS 19 — Arka plan servisi: ortak modeller
//
// Uygulama ile arka plan servisi ayrı Dart isolate'lerinde çalışır; bellek
// paylaşmazlar. Aralarında yalnızca JSON'a çevrilebilen Map'ler gidip gelir
// (`service.invoke('durum', {...})`). Bu dosyadaki her model bu yüzden
// toJson / fromJson taşır.
// ─────────────────────────────────────────────────────────────────────────

/// Uygulamanın servis tarafından görülen durumu.
enum AppPresence {
  /// Ekranda, kullanıcı uygulamada.
  open('Açık'),

  /// Arka plana atıldı; uygulama süreci yaşıyor.
  background('Arka planda'),

  /// Uygulama kapatıldı (görev listesinden kaydırıldı ya da sistem kapattı);
  /// yalnız servis yaşıyor.
  closed('Kapalı');

  const AppPresence(this.label);

  /// Görünen ad.
  final String label;

  /// Adından bulur; bilinmeyen ad kapalı sayılır.
  static AppPresence byName(String? name) => AppPresence.values.firstWhere(
    (p) => p.name == name,
    orElse: () => AppPresence.closed,
  );

  /// Flutter yaşam döngüsü durumunu servisin durumuna çevirir.
  ///
  /// `inactive` (bildirim perdesi, çoklu görev ekranı) hâlâ "açık"tır;
  /// `hidden` ve `paused` arka plan, `detached` kapalıdır.
  static AppPresence fromLifecycle(AppLifecycleState state) => switch (state) {
    AppLifecycleState.resumed || AppLifecycleState.inactive => open,
    AppLifecycleState.hidden || AppLifecycleState.paused => background,
    AppLifecycleState.detached => closed,
  };
}

/// Servisin 3 saniyede bir aldığı tek konum ölçümü.
///
/// Kullanıcının tercihiyle tam koordinat telefonda saklanır; hiçbir yere
/// gönderilmez, konsola yazılmaz.
final class GpsSample extends Equatable {
  /// Oluşturur.
  const GpsSample({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.speed,
    required this.time,
    required this.presence,
    required this.readMs,
  });

  /// JSON'dan okur.
  factory GpsSample.fromJson(Map<String, dynamic> j) => GpsSample(
    latitude: (j['lat'] as num).toDouble(),
    longitude: (j['lon'] as num).toDouble(),
    accuracy: (j['acc'] as num).toDouble(),
    speed: (j['hiz'] as num? ?? 0).toDouble(),
    time: DateTime.fromMillisecondsSinceEpoch(j['t'] as int),
    presence: AppPresence.byName(j['durum'] as String?),
    readMs: j['ms'] as int? ?? 0,
  );

  /// Enlem.
  final double latitude;

  /// Boylam.
  final double longitude;

  /// Doğruluk yarıçapı (metre).
  final double accuracy;

  /// Hız (m/sn).
  final double speed;

  /// Ölçüm zamanı.
  final DateTime time;

  /// Ölçüm alınırken uygulamanın durumu.
  final AppPresence presence;

  /// GPS okumasının sürdüğü zaman (ms).
  final int readMs;

  /// JSON'a çevirir.
  Map<String, Object> toJson() => {
    'lat': latitude,
    'lon': longitude,
    'acc': accuracy,
    'hiz': speed,
    't': time.millisecondsSinceEpoch,
    'durum': presence.name,
    'ms': readMs,
  };

  @override
  List<Object?> get props => [latitude, longitude, time, presence];
}

/// Durum değişikliği: ne zaman, neden neye geçildi.
final class PresenceChange extends Equatable {
  /// Oluşturur.
  const PresenceChange(this.at, this.presence, this.reason);

  /// JSON'dan okur.
  factory PresenceChange.fromJson(Map<String, dynamic> j) => PresenceChange(
    DateTime.fromMillisecondsSinceEpoch(j['t'] as int),
    AppPresence.byName(j['durum'] as String?),
    j['neden'] as String? ?? '',
  );

  /// Zaman.
  final DateTime at;

  /// Yeni durum.
  final AppPresence presence;

  /// Neden (yaşam döngüsü, nabız kesildi ...).
  final String reason;

  /// JSON'a çevirir.
  Map<String, Object> toJson() => {
    't': at.millisecondsSinceEpoch,
    'durum': presence.name,
    'neden': reason,
  };

  @override
  List<Object?> get props => [at, presence, reason];
}

/// Arka plan işlerinin istatistiği. Servis her adımda günceller, uygulamaya
/// gönderir ve diske yazar (servis yeniden başlasa da sayılar kalır).
final class BackgroundStats extends Equatable {
  /// Oluşturur.
  const BackgroundStats({
    this.startedAt,
    this.lastTickAt,
    this.lastHeartbeatAt,
    this.presence = AppPresence.open,
    this.ticks = 0,
    this.gpsOk = 0,
    this.gpsFailed = 0,
    this.skippedOpen = 0,
    this.overlapped = 0,
    this.totalReadMs = 0,
    this.maxReadMs = 0,
    this.distanceMeters = 0,
    this.presenceMs = const {},
    this.changes = const [],
    this.notificationsSent = const {},
    this.notificationsCancelled = 0,
    this.actions = const {},
    this.serviceStarts = 0,
    this.muted = false,
  });

  /// JSON'dan okur.
  factory BackgroundStats.fromJson(Map<String, dynamic> j) {
    DateTime? time(String k) =>
        j[k] == null ? null : DateTime.fromMillisecondsSinceEpoch(j[k] as int);
    Map<String, int> counts(String k) => {
      for (final e in ((j[k] as Map?) ?? const {}).entries)
        e.key as String: (e.value as num).toInt(),
    };
    return BackgroundStats(
      startedAt: time('basladi'),
      lastTickAt: time('son_adim'),
      lastHeartbeatAt: time('son_nabiz'),
      presence: AppPresence.byName(j['durum'] as String?),
      ticks: j['adim'] as int? ?? 0,
      gpsOk: j['gps_ok'] as int? ?? 0,
      gpsFailed: j['gps_hata'] as int? ?? 0,
      skippedOpen: j['atlanan'] as int? ?? 0,
      overlapped: j['cakisan'] as int? ?? 0,
      totalReadMs: j['okuma_ms'] as int? ?? 0,
      maxReadMs: j['en_uzun_ms'] as int? ?? 0,
      distanceMeters: (j['mesafe'] as num? ?? 0).toDouble(),
      presenceMs: {
        for (final e in counts('durum_ms').entries)
          AppPresence.byName(e.key): e.value,
      },
      changes: [
        for (final c in (j['gecisler'] as List?) ?? const [])
          PresenceChange.fromJson((c as Map).cast()),
      ],
      notificationsSent: counts('bildirim'),
      notificationsCancelled: j['bildirim_iptal'] as int? ?? 0,
      actions: counts('aksiyon'),
      serviceStarts: j['baslatma'] as int? ?? 0,
      muted: j['sessiz'] as bool? ?? false,
    );
  }

  /// Servisin ilk başladığı an.
  final DateTime? startedAt;

  /// Son 3 saniyelik adım.
  final DateTime? lastTickAt;

  /// Uygulamadan gelen son "yaşıyorum" sinyali.
  final DateTime? lastHeartbeatAt;

  /// Uygulamanın şimdiki durumu.
  final AppPresence presence;

  /// Toplam adım (3 sn'de bir).
  final int ticks;

  /// Başarılı GPS okuması.
  final int gpsOk;

  /// Başarısız GPS okuması (zaman aşımı, izin yok, servis kapalı).
  final int gpsFailed;

  /// Uygulama açıkken atlanan adım (GPS yalnız arkada okunur).
  final int skippedOpen;

  /// Önceki okuma bitmeden gelen, atlanan adım.
  final int overlapped;

  /// GPS okumalarının toplam süresi (ms).
  final int totalReadMs;

  /// En uzun GPS okuması (ms).
  final int maxReadMs;

  /// Arka planda kat edilen mesafe (metre).
  final double distanceMeters;

  /// Her durumda geçen süre (ms).
  final Map<AppPresence, int> presenceMs;

  /// Son durum geçişleri (en yenisi sonda, en çok [maxChanges]).
  final List<PresenceChange> changes;

  /// Türüne göre gönderilen bildirim sayısı.
  final Map<String, int> notificationsSent;

  /// Uygulama öne gelince iptal edilen, bekleyen bildirim.
  final int notificationsCancelled;

  /// Bildirim düğmelerine basılma sayısı.
  final Map<String, int> actions;

  /// Servisin kaç kez başlatıldığı.
  final int serviceStarts;

  /// "Sessize al" düğmesine basıldı mı?
  final bool muted;

  /// Saklanan en çok geçiş.
  static const maxChanges = 20;

  /// Ortalama GPS okuma süresi (ms).
  int get averageReadMs => gpsOk == 0 ? 0 : totalReadMs ~/ gpsOk;

  /// Gönderilen toplam bildirim.
  int get notificationsTotal =>
      notificationsSent.values.fold(0, (a, b) => a + b);

  /// JSON'a çevirir.
  Map<String, Object?> toJson() => {
    'basladi': startedAt?.millisecondsSinceEpoch,
    'son_adim': lastTickAt?.millisecondsSinceEpoch,
    'son_nabiz': lastHeartbeatAt?.millisecondsSinceEpoch,
    'durum': presence.name,
    'adim': ticks,
    'gps_ok': gpsOk,
    'gps_hata': gpsFailed,
    'atlanan': skippedOpen,
    'cakisan': overlapped,
    'okuma_ms': totalReadMs,
    'en_uzun_ms': maxReadMs,
    'mesafe': distanceMeters,
    'durum_ms': {for (final e in presenceMs.entries) e.key.name: e.value},
    'gecisler': [for (final c in changes) c.toJson()],
    'bildirim': notificationsSent,
    'bildirim_iptal': notificationsCancelled,
    'aksiyon': actions,
    'baslatma': serviceStarts,
    'sessiz': muted,
  };

  /// Değiştirilmiş kopya.
  BackgroundStats copyWith({
    DateTime? startedAt,
    DateTime? lastTickAt,
    DateTime? lastHeartbeatAt,
    AppPresence? presence,
    int? ticks,
    int? gpsOk,
    int? gpsFailed,
    int? skippedOpen,
    int? overlapped,
    int? totalReadMs,
    int? maxReadMs,
    double? distanceMeters,
    Map<AppPresence, int>? presenceMs,
    List<PresenceChange>? changes,
    Map<String, int>? notificationsSent,
    int? notificationsCancelled,
    Map<String, int>? actions,
    int? serviceStarts,
    bool? muted,
  }) => BackgroundStats(
    startedAt: startedAt ?? this.startedAt,
    lastTickAt: lastTickAt ?? this.lastTickAt,
    lastHeartbeatAt: lastHeartbeatAt ?? this.lastHeartbeatAt,
    presence: presence ?? this.presence,
    ticks: ticks ?? this.ticks,
    gpsOk: gpsOk ?? this.gpsOk,
    gpsFailed: gpsFailed ?? this.gpsFailed,
    skippedOpen: skippedOpen ?? this.skippedOpen,
    overlapped: overlapped ?? this.overlapped,
    totalReadMs: totalReadMs ?? this.totalReadMs,
    maxReadMs: maxReadMs ?? this.maxReadMs,
    distanceMeters: distanceMeters ?? this.distanceMeters,
    presenceMs: presenceMs ?? this.presenceMs,
    changes: changes ?? this.changes,
    notificationsSent: notificationsSent ?? this.notificationsSent,
    notificationsCancelled:
        notificationsCancelled ?? this.notificationsCancelled,
    actions: actions ?? this.actions,
    serviceStarts: serviceStarts ?? this.serviceStarts,
    muted: muted ?? this.muted,
  );

  @override
  List<Object?> get props => [
    startedAt,
    lastTickAt,
    lastHeartbeatAt,
    presence,
    ticks,
    gpsOk,
    gpsFailed,
    skippedOpen,
    overlapped,
    totalReadMs,
    maxReadMs,
    distanceMeters,
    presenceMs,
    changes,
    notificationsSent,
    notificationsCancelled,
    actions,
    serviceStarts,
    muted,
  ];
}

/// Uygulamanın arka plana geçerken servise verdiği özet. Bildirim
/// simülasyonu metinlerini buradan kurar (servis Firestore'a bağlanmaz).
final class AppSnapshot extends Equatable {
  /// Oluşturur.
  const AppSnapshot({
    this.expenseCount = 0,
    this.monthTotal = 0,
    this.lastMonthTotal = 0,
    this.topCategory,
    this.recent = const [],
  });

  /// JSON'dan okur.
  factory AppSnapshot.fromJson(Map<String, dynamic>? j) => j == null
      ? const AppSnapshot()
      : AppSnapshot(
          expenseCount: j['adet'] as int? ?? 0,
          monthTotal: (j['bu_ay'] as num? ?? 0).toDouble(),
          lastMonthTotal: (j['gecen_ay'] as num? ?? 0).toDouble(),
          topCategory: j['en_cok'] as String?,
          recent: [for (final r in (j['son'] as List?) ?? const []) '$r'],
        );

  /// Toplam harcama sayısı.
  final int expenseCount;

  /// Bu ayın toplamı.
  final double monthTotal;

  /// Geçen ayın toplamı.
  final double lastMonthTotal;

  /// Bu ay en çok harcanan kategori.
  final String? topCategory;

  /// Son harcamalar ("Yemek · 120 ₺" gibi, en çok 5).
  final List<String> recent;

  /// JSON'a çevirir.
  Map<String, Object?> toJson() => {
    'adet': expenseCount,
    'bu_ay': monthTotal,
    'gecen_ay': lastMonthTotal,
    'en_cok': topCategory,
    'son': recent,
  };

  @override
  List<Object?> get props => [
    expenseCount,
    monthTotal,
    lastMonthTotal,
    topCategory,
    recent,
  ];
}
