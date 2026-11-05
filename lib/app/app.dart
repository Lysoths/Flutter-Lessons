import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_ders/app/core/analytics/app_analytics.dart';
import 'package:flutter_ders/app/core/di/injection.dart';
import 'package:flutter_ders/app/core/firebase/app_config_cubit.dart';
import 'package:flutter_ders/app/core/firebase/session_cubit.dart';
import 'package:flutter_ders/app/core/router/app_deep_links.dart';
import 'package:flutter_ders/app/core/router/app_router.dart';
import 'package:flutter_ders/app/helper/network_checker.dart';
import 'package:flutter_ders/app/theme/app_theme.dart';
import 'package:flutter_ders/app/views/view_expenses/cubit/expenses_cubit.dart';
import 'package:flutter_ders/app/widgets/app_gate.dart';

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

  // DERS 18 — Remote Config ayarları ve oturum: tüm uygulamanın üstünde.
  final AppConfigCubit _config = getIt<AppConfigCubit>();
  final SessionCubit _session = getIt<SessionCubit>();
  StreamSubscription<String?>? _sessionSub;

  @override
  void initState() {
    super.initState();
    unawaited(_config.start());
    unawaited(_expenses.load());
    // Harcamalar oturuma bağlı (Firestore): giriş/çıkışta yeniden okunur.
    _sessionSub = _session.stream
        .map((s) => s.user?.uid)
        .distinct()
        .listen((_) => _expenses.load());
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
    unawaited(_sessionSub?.cancel());
    _router.dispose();
    unawaited(_expenses.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<ExpensesCubit>.value(value: _expenses),
        BlocProvider<AppConfigCubit>.value(value: _config),
        BlocProvider<SessionCubit>.value(value: _session),
      ],
      child: BlocBuilder<AppConfigCubit, AppConfigState>(
        // Yalnız tasarım ya da uygulama adı değişince tema yeniden kurulur.
        buildWhen: (a, b) =>
            a.config.design != b.config.design ||
            a.t('uygulama.ad') != b.t('uygulama.ad'),
        builder: (context, config) => MaterialApp.router(
          title: config.t('uygulama.ad'),
          debugShowCheckedModeBanner: false,
          scaffoldMessengerKey: _messenger,
          theme: AppTheme.light(config.config.design),
          // Sürüm kilidi ve giriş ekranı yönlendiricinin önünde durur.
          builder: (context, child) => AppGate(child: child!),
          // auto_route; RouterDelegate, parser ve geri tuşunu kendisi kurar.
          // Gelen linkler önce beyaz listeden geçer (app_deep_links.dart).
          routerConfig: _router.config(
            deepLinkTransformer: AppDeepLinks.transform,
            // Ekran geçişleri Firebase Analytics'e screen_view olarak gider.
            navigatorObservers: () => [AnalyticsRouteObserver(getIt())],
          ),
        ),
      ),
    );
  }
}
