import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_ders/app/core/bloc/navigation/navigation_cubit.dart';
import 'package:flutter_ders/app/core/di/injection.dart';
import 'package:flutter_ders/app/core/router/app_route_parser.dart';
import 'package:flutter_ders/app/core/router/app_router_delegate.dart';
import 'package:flutter_ders/app/theme/app_theme.dart';
import 'package:flutter_ders/app/views/view_expenses/cubit/expenses_cubit.dart';

/// Kök widget: uygulama genelindeki cubit'ler, tema ve yönlendirme.
class HarcamaApp extends StatefulWidget {
  /// Uygulamayı oluşturur. Önce [configureDependencies] çağrılmalıdır.
  const HarcamaApp({super.key});

  @override
  State<HarcamaApp> createState() => _HarcamaAppState();
}

class _HarcamaAppState extends State<HarcamaApp> {
  // Ana sayfa ve kategori sayfası aynı veriyi gördüğü için harcama
  // cubit'i sayfaların üstünde, uygulama seviyesinde yaşar.
  late final ExpensesCubit _expenses = getIt<ExpensesCubit>();
  late final NavigationCubit _navigation = getIt<NavigationCubit>();
  late final AppRouterDelegate _routerDelegate = AppRouterDelegate(_navigation);

  @override
  void initState() {
    super.initState();
    unawaited(_expenses.load());
  }

  @override
  void dispose() {
    _routerDelegate.dispose();
    unawaited(_navigation.close());
    unawaited(_expenses.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<ExpensesCubit>.value(value: _expenses),
        BlocProvider<NavigationCubit>.value(value: _navigation),
      ],
      // DERS 2 — Navigation 2.0: `home:` yerine Router kullanılır.
      child: MaterialApp.router(
        title: 'Harcama Takibim',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        routerDelegate: _routerDelegate,
        // DERS 3 — Deep link: gelen link yolu → NavigationState.
        routeInformationParser: const AppRouteParser(),
        // Android geri tuşu Router'a iletilir.
        backButtonDispatcher: RootBackButtonDispatcher(),
      ),
    );
  }
}
