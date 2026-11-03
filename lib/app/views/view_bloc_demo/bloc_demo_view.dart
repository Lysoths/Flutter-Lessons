import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_ders/app/core/di/injection.dart';
import 'package:flutter_ders/app/views/view_bloc_demo/bloc/live_rates_bloc.dart';
import 'package:flutter_ders/app/views/view_bloc_demo/bloc/rates_bloc.dart';
import 'package:flutter_ders/app/views/view_bloc_demo/bloc/rates_event.dart';
import 'package:flutter_ders/app/views/view_bloc_demo/bloc/tips_bloc.dart';
import 'package:flutter_ders/app/views/view_bloc_demo/bloc/tips_event.dart';
import 'package:flutter_ders/app/views/view_bloc_demo/widgets/live_rates_tab.dart';
import 'package:flutter_ders/app/views/view_bloc_demo/widgets/rates_tab.dart';
import 'package:flutter_ders/app/views/view_bloc_demo/widgets/tips_tab.dart';

// ─────────────────────────────────────────────────────────────────────────
// DERS 13 — Bloc ile durum yönetimi
//
//   Ekran ──add(Olay)──▶ Bloc ──on<Olay>──▶ emit(Durum) ──▶ Ekran çizer
//
// Üç veri kaynağı, üç Bloc, aynı kalıp:
//   Servis   → RatesBloc      (dio ile Frankfurter API)
//   Canlı    → LiveRatesBloc  (WebSocket akışı, emit.forEach)
//   Asset    → TipsBloc       (rootBundle ile JSON)
//
// Bloc'lar sayfa seviyesinde kurulur (MultiBlocProvider); sekmeler arası
// geçişte durumları kaybolmaz, sayfa kapanınca hepsi kapanır.
// ─────────────────────────────────────────────────────────────────────────

/// Bloc dersinin sayfası.
@RoutePage()
class BlocDemoView extends StatelessWidget {
  /// Sayfayı oluşturur.
  const BlocDemoView({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => getIt<RatesBloc>()..add(const RatesRequested()),
        ),
        BlocProvider(create: (_) => getIt<LiveRatesBloc>()),
        BlocProvider(create: (_) => getIt<TipsBloc>()..add(const TipsLoaded())),
      ],
      child: DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Bloc ile veri'),
            titleTextStyle: t.titleLarge,
            bottom: const TabBar(
              tabs: [
                Tab(key: Key('bloc_tabRates'), text: 'Servis'),
                Tab(key: Key('bloc_tabLive'), text: 'Canlı'),
                Tab(key: Key('bloc_tabTips'), text: 'Asset'),
              ],
            ),
          ),
          body: const TabBarView(
            children: [RatesTab(), LiveRatesTab(), TipsTab()],
          ),
        ),
      ),
    );
  }
}
