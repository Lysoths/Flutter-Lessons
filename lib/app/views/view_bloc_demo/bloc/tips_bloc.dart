import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_ders/app/core/analytics/app_events.dart';
import 'package:flutter_ders/app/core/base/base_view_model_bloc.dart';
import 'package:flutter_ders/app/core/repository/tips_repository.dart';
import 'package:flutter_ders/app/views/view_bloc_demo/bloc/tips_event.dart';
import 'package:flutter_ders/app/views/view_bloc_demo/bloc/tips_state.dart';

/// DERS 13 — Cihazın içinden (asset) veri: tasarruf ipuçları.
///
///   TipsLoaded           → asset okunur (rootBundle), liste hazır
///   TipsSearched(q)      → arama; yazarken her harfte değil, durunca
///   TipsCategorySelected → kategori filtresi
class TipsBloc extends BaseViewModelBloc<TipsEvent, TipsState> {
  /// [repository] üzerinden çalışan Bloc oluşturur.
  TipsBloc({
    required this.repository,
    this.debounce = const Duration(milliseconds: 300),
  }) : super(const TipsState()) {
    on<TipsLoaded>(_load);
    // restartable(): yeni bir arama gelince süren aramanın işleyicisi
    // iptal edilir. Başta kısa bir bekleme olduğu için hızlı yazarken
    // yalnızca SON yazılan uygulanır (debounce).
    on<TipsSearched>(_search, transformer: restartable());
    on<TipsCategorySelected>(_selectCategory);
  }

  /// İpuçlarının geldiği yer.
  final TipsRepository repository;

  /// Aramadan önce beklenen süre.
  final Duration debounce;

  Future<void> _load(TipsLoaded event, Emitter<TipsState> emit) async {
    emit(state.copyWith(status: TipsStatus.loading));
    try {
      final all = await repository.loadAll();
      emit(state.copyWith(status: TipsStatus.ready, all: all));
    } on Object catch (e) {
      emit(state.copyWith(status: TipsStatus.failure, error: '$e'));
    }
  }

  Future<void> _search(TipsSearched event, Emitter<TipsState> emit) async {
    await Future<void>.delayed(debounce);
    // Bu sırada yeni bir arama geldiyse işleyici iptal edilmiştir.
    if (emit.isDone) return;
    emit(state.copyWith(query: event.query));
  }

  void _selectCategory(TipsCategorySelected event, Emitter<TipsState> emit) {
    track(AppEvent.tipCategorySelected, event.category?.name ?? 'tumu');
    emit(
      state.copyWith(
        category: event.category,
        clearCategory: event.category == null,
      ),
    );
  }
}
