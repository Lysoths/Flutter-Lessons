import 'package:flutter_ders/app/core/base/base_change_notifier_view_model.dart';
import 'package:flutter_ders/app/core/repository/currency_repository.dart';
import 'package:flutter_ders/app/models/currency/currency_info.dart';
import 'package:flutter_ders/app/models/currency/currency_quote.dart';

/// DERS 15 — 1. bölüm: takip edilen 10 para biriminin güncel kuru.
///
/// Son gün ve bir önceki gün aynı anda istenir; değişim yüzdesi ikisinden
/// hesaplanır.
class RatesViewModel extends BaseChangeNotifierViewModel {
  /// [repository] üzerinden çalışan ViewModel oluşturur.
  RatesViewModel({required this._repository});

  final CurrencyRepository _repository;

  List<CurrencyQuote> _quotes = const [];
  DateTime? _date;
  String _selected = kTrackedCurrencies.first.code;

  /// Kurlar, [kTrackedCurrencies] sırasıyla.
  List<CurrencyQuote> get quotes => _quotes;

  /// Kurların yayın günü.
  DateTime? get date => _date;

  /// Seçili para birimi kodu.
  String get selected => _selected;

  /// Kurları getirir.
  Future<void> load() => runTask(() async {
    final latest = await _repository.latest();
    final previous = await _repository.onDate(
      latest.date.subtract(const Duration(days: 1)),
    );
    _date = latest.date;
    _quotes = [
      for (final c in kTrackedCurrencies)
        if (latest.tryPerUnit[c.code] case final v?)
          CurrencyQuote(
            info: c,
            tryPerUnit: v,
            previous: previous.tryPerUnit[c.code],
          ),
    ];
  }, describe: (e) => e is CurrencyFailure ? e.message : 'Kurlar alınamadı.');

  /// [code]'u seçer. Diğer bölümleri üst ViewModel haberdar eder.
  void select(String code) {
    if (code == _selected) return;
    _selected = code;
    notifyListeners();
  }
}
