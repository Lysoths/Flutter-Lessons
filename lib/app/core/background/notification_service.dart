import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_ders/app/core/background/background_models.dart';
import 'package:flutter_ders/app/core/background/notification_plan.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────
// DERS 19 — Yerel bildirimler (flutter_local_notifications)
//
// İki kanal:
//   ders19_servis      düşük önem: servisin sürekli "çalışıyorum" bildirimi
//   ders19_simulasyon  yüksek önem: simülasyon bildirimleri (ses, açılır)
//
// Bildirime ya da düğmesine dokunulunca:
//   * Uygulamayı açan düğme (showsUserInterface: true) → uygulamanın ana
//     isolate'indeki geri çağrı → tipli rota (yol/yazı yok).
//   * Açmayan düğme (Sessize al, Yanıtla) → Android ayrı bir isolate açar,
//     [onBackgroundNotificationResponse] çalışır. Bu isolate servisle bellek
//     paylaşmaz; sonucu SharedPreferences'a yazar, servis oradan okur.
// ─────────────────────────────────────────────────────────────────────────

/// Servis bildiriminin kanalı.
const kServiceChannel = AndroidNotificationChannel(
  'ders19_servis',
  'Arka plan servisi',
  description: 'Konum izleyen servisin sürekli bildirimi',
  importance: Importance.low,
);

/// Simülasyon kanalı.
const kSimulationChannel = AndroidNotificationChannel(
  'ders19_simulasyon',
  'Bildirim simülasyonu',
  description: 'Uygulama arka plandayken gönderilen ders bildirimleri',
  importance: Importance.high,
);

const _androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');

/// Isolate'ler arasında paylaşılan küçük bildirim durumu.
///
/// `SharedPreferencesAsync` her okumada diske gider (önbellek yok); üç
/// isolate (uygulama, servis, bildirim düğmesi) aynı değeri görür.
abstract final class NotificationPrefs {
  static const _muted = 'ders19_sessiz';
  static const _actionPrefix = 'ders19_aksiyon_';

  /// Sessize alındı mı?
  static Future<bool> isMuted() async =>
      await SharedPreferencesAsync().getBool(_muted) ?? false;

  /// Sessize alır / açar.
  static Future<void> setMuted({required bool muted}) =>
      SharedPreferencesAsync().setBool(_muted, muted);

  /// Bir düğmeye basılmasını sayar. Yanıt metni saklanmaz (kişisel veri).
  static Future<void> countAction(String id) async {
    final p = SharedPreferencesAsync();
    await p.setInt(
      '$_actionPrefix$id',
      (await p.getInt('$_actionPrefix$id') ?? 0) + 1,
    );
  }

  /// Düğme sayıları.
  static Future<Map<String, int>> actions() async {
    final p = SharedPreferencesAsync();
    final keys = await p.getKeys();
    return {
      for (final k in keys.where((k) => k.startsWith(_actionPrefix)))
        k.substring(_actionPrefix.length): await p.getInt(k) ?? 0,
    };
  }

  /// Sayıları ve sessiz durumunu siler.
  static Future<void> clear() async {
    final p = SharedPreferencesAsync();
    for (final k in await p.getKeys()) {
      if (k.startsWith(_actionPrefix) || k == _muted) await p.remove(k);
    }
  }
}

/// Uygulamayı açmayan düğmeler buraya gelir (ayrı isolate).
@pragma('vm:entry-point')
Future<void> onBackgroundNotificationResponse(NotificationResponse r) async {
  final action = NotificationAction.byId(r.actionId);
  if (action == null) return;
  await NotificationPrefs.countAction(action.id);
  if (action == NotificationAction.mute) {
    await NotificationPrefs.setMuted(muted: true);
  }
}

/// Uygulama tarafında bildirime dokunma: hedef ekran.
typedef NotificationTap = void Function(NotificationTarget target);

/// Uygulamanın (ana isolate) bildirim kapısı.
abstract interface class NotificationGateway {
  /// Kanalları kurar, dokunmaları [onTap]'e verir. Uygulama bir bildirimle
  /// açıldıysa o bildirimin hedefi de hemen verilir.
  Future<void> init(NotificationTap onTap);

  /// Bildirim izni (Android 13+). İzin varsa true.
  Future<bool> requestPermission();
}

/// Testlerde: hiçbir şey göstermez.
class NoopNotificationGateway implements NotificationGateway {
  /// Verilen izin.
  bool granted = true;

  /// Son dokunma geri çağrısı.
  NotificationTap? onTap;

  @override
  Future<void> init(NotificationTap onTap) async => this.onTap = onTap;

  @override
  Future<bool> requestPermission() async => granted;
}

/// flutter_local_notifications ile.
class PluginNotificationGateway implements NotificationGateway {
  final _plugin = FlutterLocalNotificationsPlugin();

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  @override
  Future<void> init(NotificationTap onTap) async {
    void handle(NotificationResponse r) {
      final action = NotificationAction.byId(r.actionId);
      if (action != null) unawaited(NotificationPrefs.countAction(action.id));
      final target =
          action?.target ?? NotificationTarget.fromPayload(r.payload);
      if (target != null) onTap(target);
    }

    await _plugin.initialize(
      settings: const InitializationSettings(android: _androidInit),
      onDidReceiveNotificationResponse: handle,
      onDidReceiveBackgroundNotificationResponse:
          onBackgroundNotificationResponse,
    );
    await _android?.createNotificationChannel(kServiceChannel);
    await _android?.createNotificationChannel(kSimulationChannel);
    final launch = await _plugin.getNotificationAppLaunchDetails();
    final response = launch?.notificationResponse;
    if ((launch?.didNotificationLaunchApp ?? false) && response != null) {
      handle(response);
    }
  }

  @override
  Future<bool> requestPermission() async =>
      await _android?.requestNotificationsPermission() ?? true;
}

/// Servis isolate'inde simülasyon bildirimlerini gösterir.
class PluginNotificationSender implements NotificationSender {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  final Map<String, Uint8List> _images = {};

  Future<void> _init() async {
    if (_ready) return;
    await _plugin.initialize(
      settings: const InitializationSettings(android: _androidInit),
      onDidReceiveBackgroundNotificationResponse:
          onBackgroundNotificationResponse,
    );
    _ready = true;
  }

  // Görseller Ders 5 asset'lerinden okunur. Bildirim, Android'e bayt
  // olarak (Binder üzerinden) gider; büyük görsel 1 MB sınırını aşmasın diye
  // genişliği 1024 piksele indirilir. Küçük simge için 192 piksel yeter.
  Future<Uint8List> _image(String asset, int width) async {
    final key = '$asset@$width';
    final cached = _images[key];
    if (cached != null) return cached;
    final data = await rootBundle.load(asset);
    final codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      targetWidth: width,
    );
    final frame = await codec.getNextFrame();
    final png = await frame.image.toByteData(format: ui.ImageByteFormat.png);
    frame.image.dispose();
    return _images[key] = png!.buffer.asUint8List();
  }

  AndroidNotificationAction _action(NotificationAction a) =>
      AndroidNotificationAction(
        a.id,
        a.title,
        showsUserInterface: a.target != null,
        inputs: a == NotificationAction.reply
            ? const [AndroidNotificationActionInput(label: 'Notun')]
            : const [],
      );

  Future<StyleInformation?> _style(PlannedNotification n) async {
    switch (n.kind) {
      case NotificationKind.bigText:
        return BigTextStyleInformation(
          n.summary ?? n.body,
          contentTitle: n.title,
          summaryText: 'Ders 19',
        );
      case NotificationKind.bigPicture:
        return BigPictureStyleInformation(
          ByteArrayAndroidBitmap(await _image(n.image!, 1024)),
          largeIcon: ByteArrayAndroidBitmap(await _image(n.image!, 192)),
          contentTitle: n.title,
          summaryText: n.summary,
          // Açılınca küçük simge kaybolur, yerini büyük görsel alır.
          hideExpandedLargeIcon: true,
        );
      case NotificationKind.bigPictureCollapsed:
        return BigPictureStyleInformation(
          ByteArrayAndroidBitmap(await _image(n.image!, 1024)),
          contentTitle: n.title,
          summaryText: n.summary,
          showBigPictureWhenCollapsed: true,
        );
      case NotificationKind.inbox:
        return InboxStyleInformation(
          n.lines,
          contentTitle: n.title,
          summaryText: n.summary,
        );
      case NotificationKind.messaging:
        const me = Person(name: 'Sen', key: 'sen');
        const bot = Person(name: 'Asistan', key: 'asistan', bot: true);
        final now = DateTime.now();
        return MessagingStyleInformation(
          me,
          conversationTitle: n.title,
          groupConversation: false,
          messages: [
            for (final (i, line) in n.lines.indexed)
              Message(
                line,
                now.subtract(Duration(seconds: (n.lines.length - i) * 20)),
                bot,
              ),
          ],
        );
      case NotificationKind.summary:
        return InboxStyleInformation(
          const [],
          contentTitle: n.title,
          summaryText: n.summary,
        );
      case NotificationKind.progress:
        return null;
    }
  }

  @override
  Future<void> show(PlannedNotification n) async {
    await _init();
    final details = AndroidNotificationDetails(
      kSimulationChannel.id,
      kSimulationChannel.name,
      channelDescription: kSimulationChannel.description,
      importance: Importance.high,
      priority: Priority.high,
      styleInformation: await _style(n),
      groupKey: kNotificationGroup,
      setAsGroupSummary: n.kind == NotificationKind.summary,
      showProgress: n.progress != null,
      maxProgress: 100,
      progress: n.progress ?? 0,
      onlyAlertOnce: n.kind == NotificationKind.progress,
      category: n.kind == NotificationKind.messaging
          ? AndroidNotificationCategory.message
          : AndroidNotificationCategory.reminder,
      subText: 'Ders 19',
      actions: [for (final a in n.actions) _action(a)],
    );
    await _plugin.show(
      id: n.id,
      title: n.title,
      body: n.body,
      notificationDetails: NotificationDetails(android: details),
      payload: n.target.name,
    );
  }

  @override
  Future<void> cancelAll() async {
    await _init();
    for (final n in planNotifications(const AppSnapshot())) {
      await _plugin.cancel(id: n.id);
    }
  }
}
