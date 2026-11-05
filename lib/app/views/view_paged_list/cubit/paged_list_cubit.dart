import 'package:flutter_ders/app/core/analytics/app_events.dart';
import 'package:flutter_ders/app/core/base/base_view_model_cubit.dart';
import 'package:flutter_ders/app/core/repository/sample_expense_repository.dart';
import 'package:flutter_ders/app/views/view_paged_list/cubit/paged_list_state.dart';

/// DERS 7 — Sayfalı listenin view model'i.
///
/// Kayıtları [pageSize]'ar ister ve gelen her sayfayı listenin sonuna
/// ekler. Bir istek sürerken veya kayıtlar bittiyse yeni istek atmaz;
/// böylece kullanıcı hızlı kaydırsa da aynı sayfa iki kez gelmez.
class PagedListCubit extends BaseViewModelCubit<PagedListState> {
  /// [repository] üzerinden çalışan bir cubit oluşturur.
  PagedListCubit({required this.repository, this.pageSize = 20})
    : super(const PagedListState());

  /// Kayıtların geldiği yer.
  final SampleExpenseRepository repository;

  /// Bir sayfadaki kayıt sayısı.
  final int pageSize;

  /// Bir istek sürüyor mu (aynı anda yalnızca bir istek).
  bool _inFlight = false;

  /// Listeyi baştan, boş hâlden yükler.
  Future<void> loadFirstPage() async {
    if (_inFlight) return;
    stateChanger(const PagedListState());
    await _fetch(1, replace: true);
  }

  /// Sonraki sayfayı ister; zaten istek sürüyorsa, hata varsa veya
  /// kayıtlar bittiyse bir şey yapmaz.
  Future<void> loadNextPage() async {
    if (_inFlight) return;
    if (state.status != PagedListStatus.ready || !state.hasMore) return;
    stateChanger(state.copyWith(status: PagedListStatus.loadingMore));
    await _fetch(state.page + 1);
  }

  /// Aşağı çekip yenileme: liste görünür kalır, 1. sayfa yeniden gelir.
  Future<void> refresh() async {
    track(AppEvent.pagedRefreshed);
    if (_inFlight) return;
    await _fetch(1, replace: true);
  }

  /// Hatadan sonra "Tekrar dene".
  Future<void> retry() async {
    track(AppEvent.pagedRetried);
    if (_inFlight) return;
    if (state.items.isEmpty) return loadFirstPage();
    stateChanger(state.copyWith(status: PagedListStatus.ready));
    await loadNextPage();
  }

  Future<void> _fetch(int page, {bool replace = false}) async {
    _inFlight = true;
    try {
      final result = await repository.fetchPage(page: page, pageSize: pageSize);
      stateChanger(
        PagedListState(
          status: PagedListStatus.ready,
          items: replace ? result.items : [...state.items, ...result.items],
          page: page,
          hasMore: result.hasMore,
          total: result.total,
        ),
      );
    } on Object {
      stateChanger(state.copyWith(status: PagedListStatus.failure));
    } finally {
      _inFlight = false;
    }
  }
}
