import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_ders/app/core/analytics/app_events.dart';
import 'package:flutter_ders/app/core/background/app_presence_reporter.dart';
import 'package:flutter_ders/app/core/background/background_models.dart';
import 'package:flutter_ders/app/core/background/background_service.dart';
import 'package:flutter_ders/app/core/background/background_tracker.dart';
import 'package:flutter_ders/app/core/background/notification_plan.dart';
import 'package:flutter_ders/app/core/background/notification_service.dart';
import 'package:flutter_ders/app/core/device/location_source.dart';

/// Simülasyon çizelgesinin ekrandaki bir satırı.
final class PlanRow extends Equatable {
  /// Oluşturur.
  const PlanRow(this.id, this.kind, this.seconds, this.title, this.state);

  /// Kimlik.
  final int id;

  /// Stil.
  final NotificationKind kind;

  /// Gecikme (sn).
  final int seconds;

  /// Başlık.
  final String title;

  /// Durum.
  final PlanStepState state;

  @override
  List<Object?> get props => [id, kind, seconds, title, state];
}

/// Ders 19 ekranının durumu.
final class BackgroundLabState extends Equatable {
  /// Oluşturur.
  const BackgroundLabState({
    this.ready = false,
    this.running = false,
    this.busy = false,
    this.location,
    this.notifications,
    this.stats = const BackgroundStats(),
    this.recent = const [],
    this.stored = 0,
    this.plan = const [],
    this.message,
  });

  /// İlk okuma bitti mi?
  final bool ready;

  /// Servis çalışıyor mu?
  final bool running;

  /// Başlatma / durdurma sürüyor mu?
  final bool busy;

  /// Konum izni.
  final LocationAccess? location;

  /// Bildirim izni.
  final bool? notifications;

  /// İstatistik.
  final BackgroundStats stats;

  /// Son konumlar (en yenisi başta).
  final List<GpsSample> recent;

  /// Telefonda kayıtlı toplam konum.
  final int stored;

  /// Simülasyon çizelgesi.
  final List<PlanRow> plan;

  /// Kullanıcıya kısa ileti.
  final String? message;

  /// Kopya.
  BackgroundLabState copyWith({
    bool? ready,
    bool? running,
    bool? busy,
    LocationAccess? location,
    bool? notifications,
    BackgroundStats? stats,
    List<GpsSample>? recent,
    int? stored,
    List<PlanRow>? plan,
    String? message,
    bool clearMessage = false,
  }) => BackgroundLabState(
    ready: ready ?? this.ready,
    running: running ?? this.running,
    busy: busy ?? this.busy,
    location: location ?? this.location,
    notifications: notifications ?? this.notifications,
    stats: stats ?? this.stats,
    recent: recent ?? this.recent,
    stored: stored ?? this.stored,
    plan: plan ?? this.plan,
    message: clearMessage ? null : message ?? this.message,
  );

  @override
  List<Object?> get props => [
    ready,
    running,
    busy,
    location,
    notifications,
    stats,
    recent,
    stored,
    plan,
    message,
  ];
}

/// Ders 19 ekranının ViewModel'i: servisi başlatır, raporunu dinler.
class BackgroundLabCubit extends Cubit<BackgroundLabState> {
  /// Oluşturur.
  BackgroundLabCubit({
    required this._channel,
    required this._reporter,
    required this._location,
    required this._notifications,
    required this._store,
    required this._snapshot,
    Future<void> Function()? clearShared,
  }) : _clearShared = clearShared ?? NotificationPrefs.clear,
       super(const BackgroundLabState());

  final BackgroundChannel _channel;
  final AppPresenceReporter _reporter;
  final LocationSource _location;
  final NotificationGateway _notifications;
  final TrackStore _store;
  final AppSnapshot Function() _snapshot;
  final Future<void> Function() _clearShared;
  StreamSubscription<Map<String, dynamic>>? _sub;

  List<PlanRow> _defaultPlan() => [
    for (final n in planNotifications(_snapshot()))
      PlanRow(n.id, n.kind, n.delay.inSeconds, n.title, PlanStepState.waiting),
  ];

  /// Servis çalışıyor mu bakar; çalışmıyorsa son kaydı diskten okur.
  Future<void> init() async {
    _sub = _channel.reports().listen(_onReport);
    final running = await _channel.isRunning();
    var next = state.copyWith(
      ready: true,
      running: running,
      plan: _defaultPlan(),
    );
    if (!running) {
      final (stats, samples) = await _store.load();
      next = next.copyWith(
        stats: stats,
        stored: samples.length,
        recent: samples.reversed.take(30).toList(),
      );
    }
    if (!isClosed) emit(next);
  }

  void _onReport(Map<String, dynamic> r) {
    if (isClosed) return;
    final plan = (r['simulasyon'] as Map?)?['adimlar'] as List?;
    emit(
      state.copyWith(
        running: true,
        stats: BackgroundStats.fromJson(
          ((r['istatistik'] as Map?) ?? const {}).cast(),
        ),
        stored: r['kayitli'] as int? ?? state.stored,
        recent: [
          for (final s in (r['son_konumlar'] as List?) ?? const [])
            GpsSample.fromJson((s as Map).cast()),
        ],
        plan: plan == null || plan.isEmpty
            ? null
            : [
                for (final p in plan.cast<Map<Object?, Object?>>())
                  PlanRow(
                    p['id']! as int,
                    NotificationKind.values.byName(p['tur']! as String),
                    p['sn']! as int,
                    p['baslik']! as String,
                    PlanStepState.values.byName(p['durum']! as String),
                  ),
              ],
      ),
    );
  }

  /// İzinleri alır, servisi başlatır.
  Future<void> start() async {
    track(AppEvent.backgroundStarted);
    emit(state.copyWith(busy: true, clearMessage: true));
    final access = await _location.requestAccess();
    if (access != LocationAccess.granted) {
      emit(
        state.copyWith(
          busy: false,
          location: access,
          message: 'Konum izni olmadan servis başlamaz.',
        ),
      );
      return;
    }
    final notify = await _notifications.requestPermission();
    final ok = await _channel.start();
    if (ok) _reporter.serviceStarted();
    emit(
      state.copyWith(
        busy: false,
        running: ok,
        location: access,
        notifications: notify,
        message: ok
            ? notify
                  ? 'Servis çalışıyor. Uygulamayı arka plana at.'
                  : 'Servis çalışıyor ama bildirim izni yok; simülasyon '
                        'bildirimleri görünmez.'
            : 'Servis başlatılamadı.',
      ),
    );
  }

  /// Servisi durdurur.
  void stop() {
    track(AppEvent.backgroundStopped);
    _channel.send(BgMessages.stop);
    _reporter.serviceStopped();
    emit(state.copyWith(running: false, message: 'Servis durduruldu.'));
  }

  /// Bütün bildirim türlerini 2 saniye arayla gönderir.
  void preview() {
    track(AppEvent.backgroundPreview);
    _channel.send(BgMessages.preview, {'ozet': _snapshot().toJson()});
    emit(state.copyWith(message: 'Bildirimler 2 saniye arayla geliyor.'));
  }

  /// Simülasyonu susturur / açar.
  void setMuted({required bool muted}) {
    track(AppEvent.backgroundMuted, muted ? 'acik' : 'kapali');
    _channel.send(BgMessages.mute, {'deger': muted});
    emit(state.copyWith(stats: state.stats.copyWith(muted: muted)));
  }

  /// Konumları ve sayıları siler.
  Future<void> clear() async {
    track(AppEvent.backgroundCleared);
    if (state.running) {
      _channel.send(BgMessages.clear);
    } else {
      await _store.clear();
      await _clearShared();
    }
    emit(
      state.copyWith(
        stats: const BackgroundStats(),
        recent: const [],
        stored: 0,
        plan: _defaultPlan(),
        message: 'Konumlar ve istatistik silindi.',
      ),
    );
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}
