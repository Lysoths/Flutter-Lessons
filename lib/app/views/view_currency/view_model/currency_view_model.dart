import 'package:flutter_ders/app/core/analytics/app_events.dart';
import 'package:flutter_ders/app/core/base/base_change_notifier_view_model.dart';
import 'package:flutter_ders/app/views/view_currency/view_model/history_view_model.dart';
import 'package:flutter_ders/app/views/view_currency/view_model/news_view_model.dart';
import 'package:flutter_ders/app/views/view_currency/view_model/rates_view_model.dart';

// ─────────────────────────────────────────────────────────────────────────
// DERS 15 — MVVM: tek ekran, tek üst ViewModel, üç alt ViewModel
//
//   CurrencyView (View)
//        │  context.read<CurrencyViewModel>()
//        ▼
//   CurrencyViewModel ── ekran düzeyi: ilk yükleme, hepsini yenile,
//        │                bölümler arası koordinasyon
//        ├── RatesViewModel    1. bölüm: 10 para birimi
//        ├── HistoryViewModel  2. bölüm: haftalık / aylık / 3 aylık
//        └── NewsViewModel     3. bölüm: haberler + modal
//
// Her bölüm yalnızca KENDİ ViewModel'ini dinler: haber süzgeci değişince
// kur listesi yeniden çizilmez. Bölümler birbirini tanımaz; "USD seçildi,
// grafiği USD'ye çevir" kararını üst ViewModel verir.
// ─────────────────────────────────────────────────────────────────────────

/// Döviz yönetim ekranının üst ViewModel'i.
class CurrencyViewModel extends BaseChangeNotifierViewModel {
  /// Alt ViewModel'lerle oluşturur.
  CurrencyViewModel({
    required this.rates,
    required this.history,
    required this.news,
  });

  /// 1. bölüm.
  final RatesViewModel rates;

  /// 2. bölüm.
  final HistoryViewModel history;

  /// 3. bölüm.
  final NewsViewModel news;

  DateTime? _refreshedAt;

  /// Son tam yenileme zamanı.
  DateTime? get refreshedAt => _refreshedAt;

  /// Ekran açıldı: kurlar ve haberler aynı anda istenir; grafik, kurların
  /// yayın gününü bekler (aralığın son günü odur).
  Future<void> init() => refreshAll();

  /// Üç bölümü yeniler.
  Future<void> refreshAll() => runTask(() async {
    await Future.wait([_ratesThenHistory(), news.load()]);
    _refreshedAt = DateTime.now();
  }, describe: (_) => 'Yenilenemedi.');

  Future<void> _ratesThenHistory() async {
    await rates.load();
    history.configure(code: rates.selected, endDate: rates.date);
    await history.load();
  }

  /// Kullanıcı 1. bölümde bir para birimine dokundu.
  Future<void> selectCurrency(String code) async {
    track(AppEvent.currencySelected, code);
    rates.select(code);
    await history.showCurrency(code);
  }

  // Üst ViewModel kapanınca altları da kapanır.
  @override
  void dispose() {
    rates.dispose();
    history.dispose();
    news.dispose();
    super.dispose();
  }
}
