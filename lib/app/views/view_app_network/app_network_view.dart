import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_ders/app/core/di/injection.dart';
import 'package:flutter_ders/app/views/view_app_network/bloc/app_info_bloc.dart';
import 'package:flutter_ders/app/views/view_app_network/bloc/network_info_bloc.dart';
import 'package:flutter_ders/app/views/view_app_network/bloc/network_info_event.dart';
import 'package:flutter_ders/app/views/view_app_network/widgets/app_info_tab.dart';
import 'package:flutter_ders/app/views/view_app_network/widgets/network_info_tab.dart';

// ─────────────────────────────────────────────────────────────────────────
// DERS 14 — 2. ekran: uygulama ve ağ bilgisi
//
//   Uygulama sekmesi → AppInfoBloc     (package_info_plus, FlutterVersion)
//   Ağ sekmesi       → NetworkInfoBloc (cihaz içi + 1.1.1.1/cdn-cgi/trace)
//
// Bloc'lar sayfa seviyesinde kurulur; sekme değişince durum kaybolmaz.
// ─────────────────────────────────────────────────────────────────────────

/// Uygulama ve ağ bilgisi sayfası.
@RoutePage()
class AppNetworkView extends StatelessWidget {
  /// Sayfayı oluşturur.
  const AppNetworkView({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => getIt<AppInfoBloc>()..add(const AppInfoRequested()),
        ),
        BlocProvider(
          create: (_) =>
              getIt<NetworkInfoBloc>()..add(const NetworkInfoStarted()),
        ),
      ],
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Uygulama ve ağ'),
            titleTextStyle: t.titleLarge,
            bottom: const TabBar(
              tabs: [
                Tab(key: Key('appNetwork_tabApp'), text: 'Uygulama'),
                Tab(key: Key('appNetwork_tabNetwork'), text: 'Ağ'),
              ],
            ),
          ),
          body: const TabBarView(children: [AppInfoTab(), NetworkInfoTab()]),
        ),
      ),
    );
  }
}
