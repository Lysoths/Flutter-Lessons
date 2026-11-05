import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_ders/app/core/analytics/app_events.dart';
import 'package:flutter_ders/app/core/base/base_view_model_bloc.dart';
import 'package:flutter_ders/app/core/repository/rates_repository.dart';
import 'package:flutter_ders/app/models/exchange_rates.dart';
import 'package:flutter_ders/app/views/view_bloc_demo/bloc/rates_event.dart';
import 'package:flutter_ders/app/views/view_bloc_demo/bloc/rates_state.dart';

/// DERS 13 — Servis isteği: Frankfurter'dan döviz kurları.
///
///   RatesRequested / RatesRefreshed
///        ↓
///   RatesLoading → (await repository.latest()) → RatesLoaded | RatesError
///
/// `droppable()`: bir istek sürerken gelen "Yenile" olayları YOK SAYILIR;
/// kullanıcı düğmeye beş kez bassa da tek istek gider.
class RatesBloc extends BaseViewModelBloc<RatesEvent, RatesState> {
  /// [repository] üzerinden çalışan Bloc oluşturur.
  RatesBloc({required this.repository}) : super(const RatesInitial()) {
    on<RatesRequested>(_fetch);
    on<RatesRefreshed>((e, emit) {
      track(AppEvent.ratesRefreshed);
      return _fetch(e, emit);
    }, transformer: droppable());
  }

  /// Kurların geldiği yer.
  final RatesRepository repository;

  int _handled = 0;

  /// Ekranda tutulacak son başarılı sonuç.
  ExchangeRates? get _last => switch (state) {
    RatesLoaded(:final rates) => rates,
    RatesLoading(:final previous) => previous,
    RatesError(:final previous) => previous,
    RatesInitial() => null,
  };

  Future<void> _fetch(RatesEvent event, Emitter<RatesState> emit) async {
    _handled++;
    emit(RatesLoading(previous: _last));
    try {
      final rates = await repository.latest();
      emit(
        RatesLoaded(rates: rates, fetchedAt: DateTime.now(), handled: _handled),
      );
    } on RatesFailure catch (e) {
      emit(RatesError(message: e.message, handled: _handled, previous: _last));
    }
  }
}
