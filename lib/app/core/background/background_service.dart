import 'dart:async';
import 'dart:ui';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_ders/app/core/background/background_models.dart';
import 'package:flutter_ders/app/core/background/background_tracker.dart';
import 'package:flutter_ders/app/core/background/notification_plan.dart';
import 'package:flutter_ders/app/core/background/notification_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';

// ─────────────────────────────────────────────────────────────────────────
// DERS 19 — Arka plan servisi (flutter_background_service)
//
// Android'de "ön plan servisi" (foreground service): uygulamanın penceresi
// kapansa da süreç yaşar, karşılığında bildirim çubuğunda sürekli bir
// bildirim durur. Servis kendi Dart isolate'inde [backgroundMain] ile
// başlar; uygulamayla yalnız mesajlaşır:
//
//   uygulama → servis   'durum' {durum, ozet}   açık / arka plan / kapalı
//                       'nabiz'                 3 sn'de bir "yaşıyorum"
//                       'onizle' {ozet}         bütün bildirimler, 2 sn arayla
//                       'sessiz' {deger}        simülasyonu sustur / aç
//                       'temizle'               konumları ve sayıları sil
//                       'durdur'                servisi kapat
//   servis → uygulama   'rapor'                 3 sn'de bir istatistik
//
// Tipi "location" olduğu için (AndroidManifest) servis, uygulama açıkken
// başlatılınca "Uygulama kullanılırken" konum izniyle arkada da konum alır.
// ─────────────────────────────────────────────────────────────────────────

/// Mesaj adları.
abstract final class BgMessages {
  /// Uygulamanın durumu.
  static const presence = 'durum';

  /// Nabız.
  static const heartbeat = 'nabiz';

  /// Önizleme.
  static const preview = 'onizle';

  /// Sessiz.
  static const mute = 'sessiz';

  /// Temizle.
  static const clear = 'temizle';

  /// Durdur.
  static const stop = 'durdur';

  /// Servisin raporu.
  static const report = 'rapor';
}

/// Adım aralığı.
const kTickInterval = Duration(seconds: 3);

/// Uygulamanın servisle konuştuğu kanal; testte bellekteki sahtesi verilir.
abstract interface class BackgroundChannel {
  /// Servis çalışıyor mu?
  Future<bool> isRunning();

  /// Servisi başlatır.
  Future<bool> start();

  /// Servise mesaj.
  void send(String method, [Map<String, Object?>? args]);

  /// Servisten gelen raporlar.
  Stream<Map<String, dynamic>> reports();
}

/// Testler: servis yok, gönderilenler listede.
class MemoryBackgroundChannel implements BackgroundChannel {
  /// Çalışıyor mu?
  bool running = false;

  /// Gönderilen mesajlar.
  final List<(String, Map<String, Object?>?)> sent = [];

  final _reports = StreamController<Map<String, dynamic>>.broadcast();

  /// Servis rapor göndermiş gibi yapar.
  void emit(Map<String, dynamic> report) => _reports.add(report);

  @override
  Future<bool> isRunning() async => running;

  @override
  Future<bool> start() async => running = true;

  @override
  void send(String method, [Map<String, Object?>? args]) {
    sent.add((method, args));
    if (method == BgMessages.stop) running = false;
  }

  @override
  Stream<Map<String, dynamic>> reports() => _reports.stream;
}

/// Gerçek servis.
class PluginBackgroundChannel implements BackgroundChannel {
  final _service = FlutterBackgroundService();
  bool _configured = false;

  Future<void> _configure() async {
    if (_configured) return;
    await _service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: backgroundMain,
        // Kullanıcı başlatır; açılışta ya da telefon açılınca kendiliğinden
        // başlamaz.
        autoStart: false,
        autoStartOnBoot: false,
        isForegroundMode: true,
        notificationChannelId: kServiceChannel.id,
        initialNotificationTitle: 'Ders 19 · Arka plan servisi',
        initialNotificationContent: 'Başlıyor…',
        foregroundServiceNotificationId: 1900,
        foregroundServiceTypes: [AndroidForegroundType.location],
      ),
      iosConfiguration: IosConfiguration(autoStart: false),
    );
    _configured = true;
  }

  @override
  Future<bool> isRunning() => _service.isRunning();

  @override
  Future<bool> start() async {
    await _configure();
    return _service.startService();
  }

  @override
  void send(String method, [Map<String, Object?>? args]) =>
      _service.invoke(method, args);

  @override
  Stream<Map<String, dynamic>> reports() =>
      _service.on(BgMessages.report).where((e) => e != null).map((e) => e!);
}

/// GPS'i yalnız uygulama arkadayken açık tutar; her adımda son ölçümü verir.
///
/// Her adımda baştan konum istemek (getCurrentPosition) GPS'i her seferinde
/// soğuktan başlatır, 3 saniyeye sığmayabilir. Akış açık kalınca alıcı
/// sıcak kalır; adım yalnız en son gelen ölçümü alır.
class StreamGpsReader {
  StreamSubscription<Position>? _sub;
  Position? _latest;
  bool _consumed = true;
  Completer<void>? _next;

  /// Uygulama durumuna göre akışı açar / kapatır.
  void follow(AppPresence presence) {
    if (presence == AppPresence.open) {
      unawaited(_sub?.cancel());
      _sub = null;
      return;
    }
    _sub ??=
        Geolocator.getPositionStream(
          locationSettings: AndroidSettings(intervalDuration: kTickInterval),
        ).listen((p) {
          _latest = p;
          _consumed = false;
          _next?.complete();
          _next = null;
        }, onError: (Object _) {});
  }

  /// Son ölçüm; bu adımda yeni ölçüm yoksa en çok 2,5 sn bekler.
  Future<GpsSample> read(AppPresence presence) async {
    follow(presence);
    if (_consumed) {
      _next ??= Completer<void>();
      await _next!.future.timeout(const Duration(milliseconds: 2500));
    }
    final p = _latest!;
    _consumed = true;
    return GpsSample(
      latitude: p.latitude,
      longitude: p.longitude,
      accuracy: p.accuracy,
      speed: p.speed,
      time: p.timestamp.toLocal(),
      presence: presence,
      readMs: 0,
    );
  }

  /// Kapatır.
  Future<void> dispose() async => _sub?.cancel();
}

/// Servis isolate'inin giriş noktası.
@pragma('vm:entry-point')
Future<void> backgroundMain(ServiceInstance service) async {
  // Bu isolate'te eklentiler (geolocator, bildirim, path_provider) ayrıca
  // kaydedilir.
  DartPluginRegistrant.ensureInitialized();
  final gps = StreamGpsReader();
  final tracker = BackgroundTracker(
    readGps: gps.read,
    store: FileTrackStore(getApplicationSupportDirectory),
  );
  await tracker.load();
  final sender = PluginNotificationSender();
  final simulator = NotificationSimulator(
    sender: sender,
    onSent: (n) => tracker.recordNotification(n.kind.key),
    isMuted: NotificationPrefs.isMuted,
  );

  Future<void> report() async {
    tracker
      ..setMuted(muted: await NotificationPrefs.isMuted())
      ..syncActions(await NotificationPrefs.actions());
    service.invoke(BgMessages.report, {
      ...tracker.report(),
      'simulasyon': simulator.report(),
    });
    if (service is AndroidServiceInstance) {
      final s = tracker.stats;
      await service.setForegroundNotificationInfo(
        title: 'Ders 19 · Uygulama ${s.presence.label.toLowerCase()}',
        content:
            '${s.gpsOk} konum · ${s.notificationsTotal} bildirim · '
            '${s.ticks} adım',
      );
    }
  }

  service
    ..on(BgMessages.presence).listen((args) {
      final presence = AppPresence.byName(args?['durum'] as String?);
      final changed = tracker.setPresence(presence, 'yaşam döngüsü');
      gps.follow(presence);
      if (!changed) return;
      if (presence == AppPresence.background) {
        simulator.start(AppSnapshot.fromJson((args?['ozet'] as Map?)?.cast()));
      } else if (presence == AppPresence.open) {
        tracker.recordCancelled(simulator.cancel());
      }
      unawaited(report());
    })
    ..on(BgMessages.heartbeat).listen((_) => tracker.heartbeat())
    ..on(BgMessages.preview).listen((args) {
      simulator.start(
        AppSnapshot.fromJson((args?['ozet'] as Map?)?.cast()),
        gap: const Duration(seconds: 2),
      );
    })
    ..on(BgMessages.mute).listen((args) async {
      final muted = args?['deger'] == true;
      await NotificationPrefs.setMuted(muted: muted);
      if (muted) tracker.recordCancelled(simulator.cancel());
      unawaited(report());
    })
    ..on(BgMessages.clear).listen((_) async {
      await NotificationPrefs.clear();
      await tracker.clear();
      unawaited(report());
    })
    ..on(BgMessages.stop).listen((_) async {
      simulator.cancel();
      await gps.dispose();
      await service.stopSelf();
    });

  Timer.periodic(kTickInterval, (_) async {
    if (tracker.checkHeartbeat()) gps.follow(AppPresence.closed);
    await tracker.tick();
    await report();
  });
  await report();
}
