import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_ders/app/core/di/injection.dart';
import 'package:flutter_ders/app/core/router/app_deep_links.dart';
import 'package:flutter_ders/app/core/router/app_router.dart';
import 'package:flutter_ders/app/theme/app_theme.dart';
import 'package:flutter_ders/app/views/view_expenses/cubit/expenses_cubit.dart';

/// Kök widget: uygulama genelindeki cubit, tema ve yönlendirme.
class HarcamaApp extends StatefulWidget {
  /// Uygulamayı oluşturur. Önce [configureDependencies] çağrılmalıdır.
  const HarcamaApp({super.key});

  @override
  State<HarcamaApp> createState() => _HarcamaAppState();
}

class _HarcamaAppState extends State<HarcamaApp> {
  // Tüm sayfalar aynı veriyi gördüğü için harcama cubit'i sayfaların
  // üstünde, uygulama seviyesinde yaşar.
  late final ExpensesCubit _expenses = getIt<ExpensesCubit>();

  // DERS 4 — auto_route: rota tablosu (app_router.dart).
  final AppRouter _router = AppRouter();

  @override
  void initState() {
    super.initState();
    unawaited(_expenses.load());
  }

  @override
  void dispose() {
    _router.dispose();
    unawaited(_expenses.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ExpensesCubit>.value(
      value: _expenses,
      child: MaterialApp.router(
        title: 'Harcama Takibim',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        // auto_route; RouterDelegate, parser ve geri tuşunu kendisi kurar.
        // Gelen linkler önce beyaz listeden geçer (app_deep_links.dart).
        routerConfig: _router.config(
          deepLinkTransformer: AppDeepLinks.transform,
        ),
      ),
    );
  }
}
