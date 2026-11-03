import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_ders/app/core/di/injection.dart';
import 'package:flutter_ders/app/core/router/app_deep_links.dart';
import 'package:flutter_ders/app/core/router/app_router.dart';
import 'package:flutter_ders/app/helper/network_checker.dart';
import 'package:flutter_ders/app/theme/app_theme.dart';
import 'package:flutter_ders/app/views/view_expenses/cubit/expenses_cubit.dart';

/// Kök widget: uygulama genelindeki cubit, tema ve yönlendirme.
class HarcamaApp extends StatefulWidget {
  /// Uygulamayı oluşturur. Önce [configureDependencies] çağrılmalıdır.
  const HarcamaApp({super.key, this.watchNetwork = true});

  /// İnternet durumu izlensin ve bağlantı yokken üstte uyarı çıksın mı?
  /// (Testlerde gerçek ağa çıkmamak için kapatılır.)
  final bool watchNetwork;

  @override
  State<HarcamaApp> createState() => _HarcamaAppState();
}

class _HarcamaAppState extends State<HarcamaApp> {
  // Tüm sayfalar aynı veriyi gördüğü için harcama cubit'i sayfaların
  // üstünde, uygulama seviyesinde yaşar.
  late final ExpensesCubit _expenses = getIt<ExpensesCubit>();

  // DERS 4 — auto_route: rota tablosu (app_router.dart).
  final AppRouter _router = AppRouter();

  // DERS 11 — Ağ uyarısı. ScaffoldMessenger tüm sayfaların ortak
  // "bildirim yöneticisi"dir; anahtarı sayesinde sayfa bilmeden banner
  // gösterebiliriz.
  final GlobalKey<ScaffoldMessengerState> _messenger = GlobalKey();
  StreamSubscription<NetworkResult>? _network;
  bool _bannerShown = false;

  @override
  void initState() {
    super.initState();
    unawaited(_expenses.load());
    if (widget.watchNetwork) {
      _network = getIt<NetworkChecker>().watch().listen(_onNetwork);
    }
  }

  void _onNetwork(NetworkResult r) {
    final messenger = _messenger.currentState;
    if (messenger == null) return;
    if (!r.online && !_bannerShown) {
      _bannerShown = true;
      messenger.showMaterialBanner(_offlineBanner(r));
    } else if (r.online && _bannerShown) {
      _bannerShown = false;
      messenger
        ..hideCurrentMaterialBanner()
        ..showSnackBar(
          const SnackBar(
            key: Key('networkBanner_back'),
            content: Text('İnternet bağlantısı geri geldi'),
          ),
        );
    }
  }

  MaterialBanner _offlineBanner(NetworkResult r) => MaterialBanner(
    key: const Key('networkBanner'),
    backgroundColor: const Color(0xFFFEF2F2),
    leading: const Icon(Icons.wifi_off_rounded, color: MfColors.red600),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'İnternet bağlantısı yok',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        Text(r.detail, style: const TextStyle(fontSize: 12)),
      ],
    ),
    actions: [
      TextButton(
        key: const Key('networkBanner_retry'),
        onPressed: getIt<NetworkChecker>().refresh,
        child: const Text('Tekrar dene'),
      ),
    ],
  );

  @override
  void dispose() {
    unawaited(_network?.cancel());
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
        scaffoldMessengerKey: _messenger,
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
