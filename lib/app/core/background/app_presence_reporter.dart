import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_ders/app/core/background/background_models.dart';
import 'package:flutter_ders/app/core/background/background_service.dart';
import 'package:flutter_ders/app/helper/money_format.dart';
import 'package:flutter_ders/app/views/view_expenses/cubit/expenses_state.dart';

// ─────────────────────────────────────────────────────────────────────────
// DERS 19 — Uygulama tarafı: durumu servise bildirmek
//
// `WidgetsBindingObserver`, Flutter'ın yaşam döngüsü haberlerini dinler
// (resumed / inactive / hidden / paused / detached). Servis çalışıyorsa her
// değişiklik 'durum' mesajıyla, arka plana geçerken de bildirim metinleri
// için uygulamanın özetiyle birlikte gönderilir. Ayrıca 3 saniyede bir
// 'nabiz' gider: uygulama öldürülünce nabız kesilir, servis "kapalı" der.
// ─────────────────────────────────────────────────────────────────────────

/// Harcamalardan servisin bildirim özetini çıkarır. Notlar eklenmez.
AppSnapshot snapshotOf(ExpensesState s, DateTime now) {
  final top = s.categoryTotals(now);
  return AppSnapshot(
    expenseCount: s.expenses.length,
    monthTotal: s.totalInMonth(now),
    lastMonthTotal: s.totalInMonth(DateTime(now.year, now.month - 1)),
    topCategory: top.isEmpty ? null : top.first.category.label,
    recent: [
      for (final e in s.expenses.take(5))
        '${e.category.label} · ${formatMoney(e.amount)}',
    ],
  );
}

/// Yaşam döngüsünü servise iletir.
class AppPresenceReporter with WidgetsBindingObserver {
  /// Oluşturur.
  AppPresenceReporter({required this.channel, this.snapshot});

  /// Servis kanalı.
  final BackgroundChannel channel;

  /// Arka plana geçerken gönderilecek özet.
  AppSnapshot Function()? snapshot;

  bool _active = false;
  bool _observing = false;
  Timer? _heartbeat;
  AppPresence _presence = AppPresence.open;

  /// Servis çalışıyor mu (bu tarafın bildiği)?
  bool get active => _active;

  /// Dinlemeye başlar; servis zaten çalışıyorsa hemen "açık" der.
  Future<void> start() async {
    if (!_observing) {
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
    }
    if (await channel.isRunning()) serviceStarted();
  }

  /// Servis başladı.
  void serviceStarted() {
    _active = true;
    _send(_presence);
    _heartbeat ??= Timer.periodic(kTickInterval, (_) {
      if (_active) channel.send(BgMessages.heartbeat);
    });
  }

  /// Servis durdu.
  void serviceStopped() {
    _active = false;
    _heartbeat?.cancel();
    _heartbeat = null;
  }

  void _send(AppPresence presence) {
    if (!_active) return;
    channel.send(BgMessages.presence, {
      'durum': presence.name,
      if (presence == AppPresence.background) 'ozet': snapshot?.call().toJson(),
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final presence = AppPresence.fromLifecycle(state);
    if (presence == _presence) return;
    _presence = presence;
    _send(presence);
  }

  /// Bırakır.
  void dispose() {
    serviceStopped();
    if (_observing) WidgetsBinding.instance.removeObserver(this);
    _observing = false;
  }
}
