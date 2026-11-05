import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_ders/app/core/background/background_models.dart';

// ─────────────────────────────────────────────────────────────────────────
// DERS 19 — Bildirim simülasyonu
//
// Uygulama arka plana atılınca servis, uygulamanın verisinden (harcama
// sayısı, bu ayın toplamı, son harcamalar) bir zaman çizelgesi kurar ve
// her bildirimi farklı bir anda gönderir. Her adım Android'in başka bir
// bildirim stilini gösterir:
//
//   +5 sn   BigText        uzun metin, açılınca tamamı görünür
//   +15 sn  BigPicture     açılınca büyük görsel + aksiyon düğmeleri
//   +30 sn  BigPicture     kapalıyken de görsel (showBigPictureWhenCollapsed)
//   +45 sn  Inbox          satır satır son harcamalar
//   +60 sn  Progress       ilerleme çubuğu (bu ay / geçen ay)
//   +90 sn  Messaging      sohbet görünümü, yanıt kutulu aksiyon
//   +120 sn Summary        hepsini tek grupta toplayan özet
//
// Uygulama öne gelirse bekleyenler iptal edilir.
// Bu dosya eklenti bilmez; gönderme işi [NotificationSender]'dadır.
// ─────────────────────────────────────────────────────────────────────────

/// Android bildirim stilleri.
enum NotificationKind {
  /// Uzun metin.
  bigText('genis_metin', 'Geniş metin (BigText)'),

  /// Açılınca büyük görsel, aksiyonlu.
  bigPicture('buyuk_gorsel', 'Büyük görsel (BigPicture)'),

  /// Kapalıyken de görsel görünen BigPicture.
  bigPictureCollapsed('gorsel_kapali', 'Kapalıyken görsel'),

  /// Satır satır liste.
  inbox('liste', 'Liste (Inbox)'),

  /// İlerleme çubuğu.
  progress('ilerleme', 'İlerleme çubuğu'),

  /// Sohbet görünümü.
  messaging('sohbet', 'Sohbet (Messaging)'),

  /// Grup özeti.
  summary('grup_ozeti', 'Grup özeti');

  const NotificationKind(this.key, this.label);

  /// İstatistik anahtarı.
  final String key;

  /// Görünen ad.
  final String label;
}

/// Bildirime dokununca açılacak yer. Yük (payload) yalnızca bu adlardan
/// biri olabilir; bilinmeyen yük yok sayılır (deep link beyaz listesi gibi).
enum NotificationTarget {
  /// Ana sayfa.
  home,

  /// Belgeler (fiş, makbuz).
  documents,

  /// Yeni harcama formu.
  newExpense,

  /// Ders 19 ekranı.
  background;

  /// Yükten bulur; bilinmeyen yükte null.
  static NotificationTarget? fromPayload(String? payload) {
    for (final t in values) {
      if (t.name == payload) return t;
    }
    return null;
  }
}

/// Bildirim düğmeleri.
enum NotificationAction {
  /// Bildirimin hedefini açar.
  open('ac', 'Aç', NotificationTarget.home),

  /// Belgeler ekranını açar.
  documents('belgeler', 'Belgeleri aç', NotificationTarget.documents),

  /// Yeni harcama formunu açar.
  addExpense('harcama_ekle', 'Harcama ekle', NotificationTarget.newExpense),

  /// Ders ekranını açar.
  stats('istatistik', 'İstatistik', NotificationTarget.background),

  /// Yanıt kutusu: yazılan not uygulamayı açmadan alınır.
  reply('yanit', 'Yanıtla', null),

  /// Kalan simülasyon bildirimlerini durdurur, uygulamayı açmaz.
  mute('sessize_al', 'Sessize al', null);

  const NotificationAction(this.id, this.title, this.target);

  /// Eklentiye giden kimlik.
  final String id;

  /// Düğme yazısı.
  final String title;

  /// Uygulamayı açıyorsa hedefi; arka planda kalıyorsa null.
  final NotificationTarget? target;

  /// Kimlikten bulur.
  static NotificationAction? byId(String? id) {
    for (final a in values) {
      if (a.id == id) return a;
    }
    return null;
  }
}

/// Zaman çizelgesindeki bir bildirim.
final class PlannedNotification extends Equatable {
  /// Oluşturur.
  const PlannedNotification({
    required this.id,
    required this.kind,
    required this.delay,
    required this.title,
    required this.body,
    this.lines = const [],
    this.progress,
    this.image,
    this.summary,
    this.target = NotificationTarget.home,
    this.actions = const [],
  });

  /// Bildirim kimliği (aynı kimlik eskisinin yerine geçer).
  final int id;

  /// Stil.
  final NotificationKind kind;

  /// Arka plana geçişten sonra ne zaman.
  final Duration delay;

  /// Başlık.
  final String title;

  /// Metin.
  final String body;

  /// Inbox satırları ya da sohbet mesajları.
  final List<String> lines;

  /// İlerleme (0–100).
  final int? progress;

  /// Görsel (asset yolu).
  final String? image;

  /// Açılınca görünen alt metin.
  final String? summary;

  /// Dokununca açılacak yer.
  final NotificationTarget target;

  /// Düğmeler.
  final List<NotificationAction> actions;

  @override
  List<Object?> get props => [id, kind, delay, title, body, lines, progress];
}

/// Simülasyon bildirimlerinin grubu.
const kNotificationGroup = 'ders19_simulasyon';

/// Fiş görseli (Ders 5 asset'i).
const kReceiptImage = 'assets/belgeler/fis_1969.jpg';

/// Makbuz görseli (Ders 5 asset'i).
const kInvoiceImage = 'assets/belgeler/makbuz_1920.jpg';

String _money(double v) => '${v.toStringAsFixed(v % 1 == 0 ? 0 : 2)} ₺';

/// Uygulamanın verisine göre zaman çizelgesi.
List<PlannedNotification> planNotifications(AppSnapshot s) {
  final hasData = s.expenseCount > 0;
  final ratio = s.lastMonthTotal <= 0
      ? (s.monthTotal > 0 ? 100 : 0)
      : (s.monthTotal / s.lastMonthTotal * 100).round().clamp(0, 100);
  return [
    PlannedNotification(
      id: 1901,
      kind: NotificationKind.bigText,
      delay: const Duration(seconds: 5),
      title: 'Uygulama arka planda',
      body: hasData
          ? 'Bu ay ${_money(s.monthTotal)} harcadın.'
          : 'Henüz harcama yok.',
      summary: hasData
          ? 'Toplam ${s.expenseCount} harcama kayıtlı. Bu ay en çok '
                '${s.topCategory ?? '—'} kategorisine harcadın. Arka plan '
                'servisi 3 saniyede bir konum alıyor; ayrıntılar Ders 19 '
                'ekranında.'
          : 'İlk harcamanı eklediğinde bu bildirim aylık özetini gösterir. '
                'Arka plan servisi 3 saniyede bir konum alıyor.',
      target: NotificationTarget.background,
      actions: const [NotificationAction.stats, NotificationAction.mute],
    ),
    const PlannedNotification(
      id: 1902,
      kind: NotificationKind.bigPicture,
      delay: Duration(seconds: 15),
      title: 'Fişini sakladın mı?',
      body: 'Aşağı çekince fiş görseli açılır.',
      summary: 'Fiş ve makbuzlar Belgeler ekranında.',
      image: kReceiptImage,
      target: NotificationTarget.documents,
      actions: [
        NotificationAction.documents,
        NotificationAction.addExpense,
        NotificationAction.mute,
      ],
    ),
    const PlannedNotification(
      id: 1903,
      kind: NotificationKind.bigPictureCollapsed,
      delay: Duration(seconds: 30),
      title: 'Fatura hatırlatması',
      body: 'Görsel bildirim kapalıyken de görünür.',
      summary: 'Makbuzu Belgeler ekranında aç.',
      image: kInvoiceImage,
      target: NotificationTarget.documents,
      actions: [NotificationAction.documents, NotificationAction.mute],
    ),
    PlannedNotification(
      id: 1904,
      kind: NotificationKind.inbox,
      delay: const Duration(seconds: 45),
      title: hasData ? 'Son harcamaların' : 'Liste boş',
      body: hasData
          ? '${s.recent.length} harcama'
          : 'Harcama eklenince burada görünür.',
      lines: hasData ? s.recent : const ['Henüz harcama yok'],
      summary: '${s.expenseCount} kayıt',
      actions: const [NotificationAction.open, NotificationAction.addExpense],
    ),
    PlannedNotification(
      id: 1905,
      kind: NotificationKind.progress,
      delay: const Duration(minutes: 1),
      title: 'Bu ay: %$ratio',
      body: '${_money(s.monthTotal)} / geçen ay ${_money(s.lastMonthTotal)}',
      progress: ratio,
      actions: const [NotificationAction.open],
    ),
    PlannedNotification(
      id: 1906,
      kind: NotificationKind.messaging,
      delay: const Duration(seconds: 90),
      title: 'Harcama asistanı',
      body: 'Yeni mesaj',
      lines: [
        'Merhaba! Uygulama bir buçuk dakikadır arka planda.',
        if (hasData)
          'Bu ay en çok ${s.topCategory ?? '—'} için harcadın.'
        else
          'İlk harcamanı eklemeye ne dersin?',
        'Bir not bırakmak istersen “Yanıtla”ya bas.',
      ],
      target: NotificationTarget.background,
      actions: const [NotificationAction.reply, NotificationAction.mute],
    ),
    const PlannedNotification(
      id: 1907,
      kind: NotificationKind.summary,
      delay: Duration(minutes: 2),
      title: 'Ders 19 simülasyonu',
      body: '6 bildirim gönderildi',
      summary: 'Arka plan bildirimleri',
      target: NotificationTarget.background,
    ),
  ];
}

/// Bildirimi gerçekten gösteren taraf (servis isolate'inde eklenti).
abstract interface class NotificationSender {
  /// Gösterir.
  Future<void> show(PlannedNotification n);

  /// Simülasyon bildirimlerini kaldırır.
  Future<void> cancelAll();
}

/// Bellekte tutan gönderici (testler).
class MemoryNotificationSender implements NotificationSender {
  /// Gösterilenler.
  final List<PlannedNotification> shown = [];

  @override
  Future<void> show(PlannedNotification n) async => shown.add(n);

  @override
  Future<void> cancelAll() async => shown.clear();
}

/// Zaman çizelgesindeki bir adımın durumu.
enum PlanStepState {
  /// Bekliyor.
  waiting,

  /// Gönderildi.
  sent,

  /// İptal edildi (uygulama öne geldi ya da sessize alındı).
  cancelled,
}

/// Arka plana geçişte çizelgeyi kurar, sırası gelince gönderir.
class NotificationSimulator {
  /// Oluşturur.
  NotificationSimulator({
    required this.sender,
    required this.onSent,
    required this.isMuted,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// Gönderici.
  final NotificationSender sender;

  /// Gönderilince (istatistik için).
  final void Function(PlannedNotification n) onSent;

  /// Sessize alındı mı?
  final Future<bool> Function() isMuted;

  final DateTime Function() _now;
  final List<Timer> _timers = [];
  List<PlannedNotification> _plan = const [];
  final Map<int, PlanStepState> _states = {};
  DateTime? _startedAt;

  /// Bekleyen bildirim var mı?
  bool get running => _timers.any((t) => t.isActive);

  /// Çizelge ve her adımın durumu (uygulamaya gönderilir).
  Map<String, Object?> report() => {
    'basladi': _startedAt?.millisecondsSinceEpoch,
    'adimlar': [
      for (final n in _plan)
        {
          'id': n.id,
          'tur': n.kind.name,
          'sn': n.delay.inSeconds,
          'baslik': n.title,
          'durum': (_states[n.id] ?? PlanStepState.waiting).name,
        },
    ],
  };

  /// Arka plana geçildi: çizelgeyi kurar. [gap] verilirse gecikmeler
  /// yerine sabit aralık kullanılır (önizleme).
  void start(AppSnapshot snapshot, {Duration? gap}) {
    cancel();
    _plan = planNotifications(snapshot);
    _states.clear();
    _startedAt = _now();
    for (final (i, n) in _plan.indexed) {
      _states[n.id] = PlanStepState.waiting;
      final delay = gap == null ? n.delay : gap * (i + 1);
      _timers.add(Timer(delay, () => _fire(n)));
    }
  }

  Future<void> _fire(PlannedNotification n) async {
    if (await isMuted()) {
      _states[n.id] = PlanStepState.cancelled;
      return;
    }
    await sender.show(n);
    _states[n.id] = PlanStepState.sent;
    onSent(n);
  }

  /// Bekleyenleri iptal eder; iptal edilen sayıyı döndürür.
  int cancel() {
    var cancelled = 0;
    for (final t in _timers) {
      if (t.isActive) {
        t.cancel();
        cancelled++;
      }
    }
    _timers.clear();
    for (final e in _states.entries.toList()) {
      if (e.value == PlanStepState.waiting) {
        _states[e.key] = PlanStepState.cancelled;
      }
    }
    return cancelled;
  }
}
