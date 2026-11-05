import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_ders/app/core/analytics/app_events.dart';
import 'package:flutter_ders/app/core/base/base_view_model_bloc.dart';
import 'package:flutter_ders/app/core/device/location_source.dart';
import 'package:flutter_ders/app/core/repository/network_info_repository.dart';
import 'package:flutter_ders/app/views/view_app_network/bloc/network_info_event.dart';
import 'package:flutter_ders/app/views/view_app_network/bloc/network_info_state.dart';

/// DERS 14 — Ağ bilgisi.
///
///   NetworkInfoStarted ─┬─▶ yerel bilgi (cihaz)       ─▶ emit
///                       └─▶ trace (1.1.1.1, internet) ─▶ emit
///   connectivity akışı ──▶ NetworkConnectivityChanged ─▶ ikisini yeniden oku
///
/// İki okuma aynı anda başlar; hangisi önce biterse o önce ekrana gelir.
class NetworkInfoBloc
    extends BaseViewModelBloc<NetworkInfoEvent, NetworkInfoState> {
  /// Kaynaklarla Bloc oluşturur.
  NetworkInfoBloc({
    required this.local,
    required this.trace,
    required this.location,
  }) : super(const NetworkInfoState()) {
    on<NetworkInfoStarted>(_start);
    on<NetworkInfoRefreshed>((_, emit) {
      track(AppEvent.networkInfoRefreshed);
      return _loadAll(emit);
    }, transformer: droppable());
    // Wi-Fi ↔ mobil geçişinde art arda olay gelebilir; yalnızca sonuncusu
    // işlenir, öncekinin okuması iptal edilir.
    on<NetworkConnectivityChanged>(_changed, transformer: restartable());
    on<NetworkWifiAccessRequested>(_askWifiAccess);
  }

  /// Cihaz içi ağ bilgisi.
  final LocalNetworkSource local;

  /// Dışarıdan görünen bağlantı bilgisi.
  final TraceRepository trace;

  /// Wi-Fi adı için konum izni.
  final LocationSource location;

  StreamSubscription<Object?>? _changes;

  Future<void> _start(
    NetworkInfoStarted event,
    Emitter<NetworkInfoState> emit,
  ) async {
    // Akışın ilk değeri şu anki bağlantıdır; onu atla, gerisini olay yap.
    _changes ??= local
        .changes()
        .skip(1)
        .listen((c) => add(NetworkConnectivityChanged(c)));
    await _loadAll(emit);
  }

  Future<void> _changed(
    NetworkConnectivityChanged event,
    Emitter<NetworkInfoState> emit,
  ) async {
    emit(
      state.copyWith(
        connection: event.connection,
        connectionChanges: state.connectionChanges + 1,
      ),
    );
    // Ağ yeni değişti; arayüzlerin adres alması için kısa bekle.
    await Future<void>.delayed(const Duration(milliseconds: 800));
    await _loadAll(emit);
  }

  Future<void> _askWifiAccess(
    NetworkWifiAccessRequested event,
    Emitter<NetworkInfoState> emit,
  ) async {
    track(AppEvent.wifiAccessRequested);
    final access = await location.requestAccess();
    emit(state.copyWith(wifiAccess: access));
    await _loadLocal(emit);
  }

  Future<void> _loadAll(Emitter<NetworkInfoState> emit) =>
      Future.wait([_loadLocal(emit), _loadTrace(emit)]);

  Future<void> _loadLocal(Emitter<NetworkInfoState> emit) async {
    emit(state.copyWith(localStatus: PartStatus.loading));
    try {
      final r = await local.read();
      if (emit.isDone) return;
      emit(
        state.copyWith(
          localStatus: PartStatus.ready,
          connection: r.connection,
          localSections: r.sections,
        ),
      );
    } on Exception {
      if (!emit.isDone) emit(state.copyWith(localStatus: PartStatus.failure));
    }
  }

  Future<void> _loadTrace(Emitter<NetworkInfoState> emit) async {
    emit(
      state.copyWith(
        traceStatus: PartStatus.loading,
        traceCount: state.traceCount + 1,
      ),
    );
    final watch = Stopwatch()..start();
    try {
      final result = await trace.fetch();
      if (emit.isDone) return;
      emit(
        state.copyWith(
          traceStatus: PartStatus.ready,
          trace: result,
          traceLatency: watch.elapsed,
          traceAt: DateTime.now(),
          traceError: () => null,
        ),
      );
    } on TraceFailure catch (e) {
      if (emit.isDone) return;
      emit(
        state.copyWith(
          traceStatus: PartStatus.failure,
          traceError: () => e.message,
        ),
      );
    }
  }

  @override
  Future<void> close() async {
    await _changes?.cancel();
    return super.close();
  }
}
