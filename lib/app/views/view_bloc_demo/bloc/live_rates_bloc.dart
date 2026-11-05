import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_ders/app/core/analytics/app_events.dart';
import 'package:flutter_ders/app/core/base/base_view_model_bloc.dart';
import 'package:flutter_ders/app/core/repository/live_rates_repository.dart';
import 'package:flutter_ders/app/helper/mock_socket.dart';
import 'package:flutter_ders/app/views/view_bloc_demo/bloc/live_rates_event.dart';
import 'package:flutter_ders/app/views/view_bloc_demo/bloc/live_rates_state.dart';

/// DERS 13 — Gerçek zamanlı veri: WebSocket akışı Bloc'ta.
///
/// `emit.forEach(akış, onData: ...)`: akıştan gelen HER mesaj bir duruma
/// çevrilip yayılır; akış bitene kadar işleyici açık kalır. Ekran
/// StreamBuilder kullanmaz, yalnızca Bloc'un durumunu dinler.
class LiveRatesBloc extends BaseViewModelBloc<LiveRatesEvent, LiveRatesState> {
  /// [repository] üzerinden çalışan Bloc oluşturur.
  LiveRatesBloc({required this.repository}) : super(const LiveRatesState()) {
    // Zaten bağlıyken gelen ikinci "Bağlan" yok sayılır.
    on<LiveConnectRequested>(_connect, transformer: droppable());
    on<LiveDisconnectRequested>(_disconnect);
    on<LiveMessageSent>(_send);
  }

  /// Canlı akışın geldiği yer.
  final LiveRatesRepository repository;

  Future<void> _connect(
    LiveConnectRequested event,
    Emitter<LiveRatesState> emit,
  ) async {
    track(AppEvent.liveToggled, 'baglan');
    emit(state.copyWith(status: LiveStatus.connecting));
    await emit.forEach<SocketMessage>(
      repository.connect(),
      onData: (m) => switch (m) {
        RateTick() => state.copyWith(
          status: LiveStatus.live,
          previous: state.last,
          last: m,
          ticks: state.ticks + 1,
        ),
        EchoReply() => state.copyWith(echoes: [m, ...state.echoes.take(4)]),
      },
      onError: (e, _) =>
          state.copyWith(status: LiveStatus.failure, error: '$e'),
    );
    // Akış bitti (bağlantı kesildi).
    if (state.status != LiveStatus.failure) {
      emit(state.copyWith(status: LiveStatus.closed));
    }
  }

  Future<void> _disconnect(
    LiveDisconnectRequested event,
    Emitter<LiveRatesState> emit,
  ) {
    track(AppEvent.liveToggled, 'kes');
    return repository.disconnect();
  }

  void _send(LiveMessageSent event, Emitter<LiveRatesState> emit) {
    final text = event.text.trim();
    if (text.isNotEmpty) repository.send(text);
  }

  @override
  Future<void> close() async {
    await repository.disconnect();
    return super.close();
  }
}
