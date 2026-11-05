import 'package:flutter_ders/app/core/analytics/app_events.dart';
import 'package:flutter_ders/app/core/base/base_change_notifier_view_model.dart';
import 'package:flutter_ders/app/core/repository/currency_repository.dart';
import 'package:flutter_ders/app/models/currency/currency_info.dart';
import 'package:flutter_ders/app/models/currency/rate_history.dart';

/// DERS 15 — 2. bölüm: seçili para biriminin haftalık / aylık / 3 aylık
/// geçmişi.
///
/// Kullanıcı hızlı hızlı aralık ya da para birimi değiştirirse yalnızca SON
/// isteğin sonucu ekrana yazılır (Bloc'taki `restartable()`'ın elle hâli).
class HistoryViewModel extends BaseChangeNotifierViewModel {
  /// [repository] üzerinden çalışan ViewModel oluşturur.
  HistoryViewModel({required this._repository});

  final CurrencyRepository _repository;

  String _code = kTrackedCurrencies.first.code;
  HistoryPeriod _period = HistoryPeriod.week;
  RateHistory? _history;
  DateTime? _end;
  int _request = 0;
  Duration? _took;

  /// Gösterilen para birimi.
  String get code => _code;

  /// Seçili aralık.
  HistoryPeriod get period => _period;

  /// Son yüklenen geçmiş (yüklenirken öncekisi soluk gösterilir).
  RateHistory? get history => _history;

  /// Son yüklemenin süresi.
  Duration? get took => _took;

  /// Yüklemeden ayarlar: para birimi ve aralığın son günü (kurların yayın
  /// günü; null ise bugün).
  void configure({required String code, DateTime? endDate}) {
    _code = code;
    _end = endDate;
  }

  /// Para birimini değiştirir ve yükler.
  Future<void> showCurrency(String code) async {
    if (code == _code && _history != null) return;
    _code = code;
    await load();
  }

  /// Aralığı değiştirir ve yükler.
  Future<void> showPeriod(HistoryPeriod period) async {
    track(AppEvent.periodSelected, period.name);
    if (period == _period && _history != null) return;
    _period = period;
    await load();
  }

  /// Seçili para birimi ve aralığı yükler.
  Future<void> load() async {
    final request = ++_request;
    final code = _code;
    final period = _period;
    final watch = Stopwatch()..start();
    setStatus(ViewStatus.busy);
    try {
      final days = await Future.wait(
        period.datesUntil(_end ?? DateTime.now()).map(_repository.onDate),
      );
      // Hafta sonu ve tatilde aynı gün tekrar eder: bir kez al.
      final seen = <DateTime>{};
      final points = [
        for (final d in days)
          if (d.tryPerUnit[code] case final v? when seen.add(d.date))
            (date: d.date, value: v),
      ];
      // Daha yeni bir istek başladıysa bu sonuç eski: yazma.
      if (request != _request) return;
      if (points.isEmpty) {
        setStatus(ViewStatus.failure, error: 'Bu aralıkta veri yok.');
        return;
      }
      _history = RateHistory(code: code, period: period, points: points);
      _took = watch.elapsed;
      setStatus(ViewStatus.ready);
    } on CurrencyFailure catch (e) {
      if (request == _request) setStatus(ViewStatus.failure, error: e.message);
    }
  }
}
