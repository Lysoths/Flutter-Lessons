import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ders/app/core/analytics/app_events.dart';
import 'package:flutter_ders/app/core/di/injection.dart';
import 'package:flutter_ders/app/views/view_currency/view_model/currency_view_model.dart';
import 'package:flutter_ders/app/views/view_currency/widgets/history_section.dart';
import 'package:flutter_ders/app/views/view_currency/widgets/news_section.dart';
import 'package:flutter_ders/app/views/view_currency/widgets/rates_section.dart';
import 'package:flutter_ders/app/widgets/common.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────────────────────
// DERS 15 — MVVM klasör düzeni
//
//   views/view_currency/
//   ├── currency_view.dart              View: sayfa iskeleti
//   ├── view_model/
//   │   ├── currency_view_model.dart    üst ViewModel (koordinasyon)
//   │   ├── rates_view_model.dart       1. bölüm
//   │   ├── history_view_model.dart     2. bölüm
//   │   └── news_view_model.dart        3. bölüm
//   └── widgets/
//       ├── rates_section.dart          1. bölümün görünümü
//       ├── history_section.dart        2. bölümün görünümü
//       ├── news_section.dart           3. bölümün görünümü
//       ├── news_detail_sheet.dart      haber modalı
//       └── section_title.dart          bölümlerin ortak başlık/hata satırı
//
//   Model: models/currency/*  +  core/repository/{currency,news}_repository
//
// provider paketi:
//   ChangeNotifierProvider(create: ...)  ViewModel'i kurar, sayfa kapanınca
//                                        dispose eder (React: useState + Context)
//   ChangeNotifierProvider.value(...)    var olan alt ViewModel'i aşağı verir
//   context.watch<T>()                   T değişince bu widget'ı yeniden çizer
//   context.select<T, R>(...)            yalnızca R değişince yeniden çizer
//   context.read<T>()                    dinlemeden erişir (düğme içinde)
// ─────────────────────────────────────────────────────────────────────────

/// Döviz yönetim ekranı.
@RoutePage()
class CurrencyView extends StatelessWidget {
  /// Sayfayı oluşturur.
  const CurrencyView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => getIt<CurrencyViewModel>()..init(),
      // Alt ViewModel'ler üstün içinden aşağı verilir; her bölüm yalnızca
      // kendi ViewModel'ini dinler.
      builder: (context, _) {
        final vm = context.read<CurrencyViewModel>();
        return MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: vm.rates),
            ChangeNotifierProvider.value(value: vm.history),
            ChangeNotifierProvider.value(value: vm.news),
          ],
          child: const _CurrencyPage(),
        );
      },
    );
  }
}

class _CurrencyPage extends StatelessWidget {
  const _CurrencyPage();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final vm = context.read<CurrencyViewModel>();
    // Yalnızca üst ViewModel'in "yenileniyor" bilgisi dinlenir.
    final busy = context.select<CurrencyViewModel, bool>((m) => m.isBusy);
    final padding = pagePadding(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Döviz yönetimi'),
        titleTextStyle: t.titleLarge,
        actions: [
          IconButton(
            key: const Key('currency_refresh'),
            tooltip: 'Hepsini yenile',
            onPressed: busy
                ? null
                : () {
                    track(AppEvent.currencyRefreshed);
                    vm.refreshAll();
                  },
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () {
          track(AppEvent.currencyRefreshed);
          return vm.refreshAll();
        },
        child: CustomScrollView(
          key: const Key('currency_scroll'),
          slivers: [
            SliverPadding(
              padding: padding.copyWith(top: 16),
              sliver: const SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [RatesSection(), Gap(20), HistorySection()],
                ),
              ),
            ),
            SliverPadding(
              padding: padding.copyWith(top: 20, bottom: 32),
              sliver: const NewsSection(),
            ),
          ],
        ),
      ),
    );
  }
}
