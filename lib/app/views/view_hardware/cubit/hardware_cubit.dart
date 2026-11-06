import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_ders/app/core/analytics/app_events.dart';
import 'package:flutter_ders/app/core/base/base_view_model_cubit.dart';
import 'package:flutter_ders/app/core/hardware/hardware_profile.dart';
import 'package:flutter_ders/app/core/hardware/hardware_source.dart';

/// Ekranın durumu.
enum HardwareStatus {
  /// Profil okunuyor.
  loading,

  /// Hazır.
  ready,

  /// Bu platformda yok.
  unsupported,

  /// Okunamadı.
  failed,
}

/// Donanım ekranının durumu.
final class HardwareState extends Equatable {
  /// Oluşturur.
  const HardwareState({
    this.status = HardwareStatus.loading,
    this.profile,
    this.live,
    this.currentHistory = const [],
    this.imei,
    this.imeiBusy = false,
    this.idRevealed = false,
    this.refreshing = false,
  });

  /// Kaç canlı ölçüm tutulur (akım grafiği).
  static const historyLength = 30;

  /// Durum.
  final HardwareStatus status;

  /// Profil.
  final DeviceProfile? profile;

  /// Son canlı ölçüm.
  final LiveReading? live;

  /// Son ölçümlerin akımı (mA), eskiden yeniye.
  final List<double> currentHistory;

  /// IMEI denemesi.
  final ImeiResult? imei;

  /// IMEI deneniyor.
  final bool imeiBusy;

  /// Android ID açık mı?
  final bool idRevealed;

  /// Profil yeniden okunuyor.
  final bool refreshing;

  /// Değiştirilmiş kopya. [imei] için `clearImei`.
  HardwareState copyWith({
    HardwareStatus? status,
    DeviceProfile? profile,
    LiveReading? live,
    List<double>? currentHistory,
    ImeiResult? imei,
    bool? imeiBusy,
    bool? idRevealed,
    bool? refreshing,
  }) => HardwareState(
    status: status ?? this.status,
    profile: profile ?? this.profile,
    live: live ?? this.live,
    currentHistory: currentHistory ?? this.currentHistory,
    imei: imei ?? this.imei,
    imeiBusy: imeiBusy ?? this.imeiBusy,
    idRevealed: idRevealed ?? this.idRevealed,
    refreshing: refreshing ?? this.refreshing,
  );

  // Bloc gözlemcisi her geçişi konsola yazar: kimlik, IMEI, operatör gibi
  // değerler log'a düşmesin.
  @override
  String toString() =>
      'HardwareState(${status.name}, canlı: ${currentHistory.length}, '
      'imei: ${imei.runtimeType})';

  @override
  List<Object?> get props => [
    status,
    profile,
    live,
    currentHistory,
    imei,
    imeiBusy,
    idRevealed,
    refreshing,
  ];
}

/// DERS 22 — Kendi donanım kanalımızdan profili okur, canlı ölçümleri dinler.
/// Hiçbir değer saklanmaz; Analytics'e yalnız eylem adı gider.
class HardwareCubit extends BaseViewModelCubit<HardwareState> {
  /// Oluşturur.
  HardwareCubit({required this._source}) : super(const HardwareState());

  final HardwareSource _source;
  StreamSubscription<LiveReading>? _live;

  /// Profili okur ve canlı ölçümü başlatır.
  Future<void> init() async {
    await _load();
    if (state.status == HardwareStatus.ready) _listen();
  }

  Future<void> _load() async {
    try {
      final profile = await _source.profile();
      stateChanger(
        state.copyWith(
          status: HardwareStatus.ready,
          profile: profile,
          refreshing: false,
        ),
      );
    } on HardwareUnsupported {
      stateChanger(state.copyWith(status: HardwareStatus.unsupported));
    } on HardwareReadException {
      stateChanger(
        state.copyWith(
          status: state.profile == null
              ? HardwareStatus.failed
              : HardwareStatus.ready,
          refreshing: false,
        ),
      );
    }
  }

  /// Profili yeniden okur.
  Future<void> refresh() async {
    stateChanger(state.copyWith(refreshing: true));
    await _load();
    track(AppEvent.hardwareRefreshed);
  }

  void _listen() {
    if (_live != null) return;
    _live = _source.live().listen(
      (r) {
        final ua = r.currentUa;
        final history = ua == null
            ? state.currentHistory
            : [
                ...state.currentHistory.skip(
                  state.currentHistory.length >= HardwareState.historyLength
                      ? 1
                      : 0,
                ),
                ua / 1000,
              ];
        stateChanger(state.copyWith(live: r, currentHistory: history));
      },
      // Akış kesilirse son ölçüm ekranda kalır.
      onError: (Object _) {},
    );
  }

  /// IMEI'yi dener; Android 10+ engeller, sonuç ekranda açıklanır.
  Future<void> tryImei() async {
    if (state.imeiBusy) return;
    stateChanger(state.copyWith(imeiBusy: true));
    final result = await _source.imei();
    stateChanger(state.copyWith(imei: result, imeiBusy: false));
    track(
      AppEvent.hardwareImeiTried,
      result is ImeiRead ? 'okundu' : 'engellendi',
    );
  }

  /// SIM ve ağ için telefon izni ister; verilirse profili yeniler.
  Future<void> requestPhoneAccess() async {
    final granted = await _source.requestPhoneAccess();
    track(AppEvent.hardwarePhoneAccess, granted ? 'verildi' : 'verilmedi');
    if (granted) await _load();
  }

  /// Android ID'yi gösterir / gizler.
  void toggleId() {
    final next = !state.idRevealed;
    stateChanger(state.copyWith(idRevealed: next));
    if (next) track(AppEvent.hardwareIdRevealed);
  }

  @override
  Future<void> close() async {
    await _live?.cancel();
    return super.close();
  }
}
