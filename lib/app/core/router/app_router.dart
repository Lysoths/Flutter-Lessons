import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ders/app/core/router/route_transitions.dart';
import 'package:flutter_ders/app/models/document_item.dart';
import 'package:flutter_ders/app/models/expense.dart';
import 'package:flutter_ders/app/views/view_animation_control/animation_control_view.dart';
import 'package:flutter_ders/app/views/view_animations/animation_demo_view.dart';
import 'package:flutter_ders/app/views/view_animations/animations_view.dart';
import 'package:flutter_ders/app/views/view_app_network/app_network_view.dart';
import 'package:flutter_ders/app/views/view_audio_player/audio_player_view.dart';
import 'package:flutter_ders/app/views/view_bloc_demo/bloc_demo_view.dart';
import 'package:flutter_ders/app/views/view_category/category_expenses_view.dart';
import 'package:flutter_ders/app/views/view_currency/currency_view.dart';
import 'package:flutter_ders/app/views/view_device/device_view.dart';
import 'package:flutter_ders/app/views/view_device_info/device_info_view.dart';
import 'package:flutter_ders/app/views/view_documents/documents_view.dart';
import 'package:flutter_ders/app/views/view_expense_detail/expense_detail_view.dart';
import 'package:flutter_ders/app/views/view_expenses/expenses_view.dart';
import 'package:flutter_ders/app/views/view_firebase/firebase_view.dart';
import 'package:flutter_ders/app/views/view_image_cache/image_cache_view.dart';
import 'package:flutter_ders/app/views/view_image_viewer/image_viewer_view.dart';
import 'package:flutter_ders/app/views/view_lessons/lessons_view.dart';
import 'package:flutter_ders/app/views/view_lottie/lottie_view.dart';
import 'package:flutter_ders/app/views/view_network/network_view.dart';
import 'package:flutter_ders/app/views/view_new_expense/new_expense_view.dart';
import 'package:flutter_ders/app/views/view_paged_grid/paged_grid_view.dart';
import 'package:flutter_ders/app/views/view_paged_list/paged_list_view.dart';
import 'package:flutter_ders/app/views/view_pdf_viewer/pdf_viewer_view.dart';
import 'package:flutter_ders/app/views/view_retrofit/retrofit_view.dart';
import 'package:flutter_ders/app/views/view_storage/storage_views.dart';
import 'package:flutter_ders/app/views/view_sync_async/sync_async_view.dart';

part 'app_router.gr.dart';

// ─────────────────────────────────────────────────────────────────────────
// DERS 4 — auto_route
//
// Sayfalar @RoutePage() ile işaretlenir; `dart run build_runner build`
// her sayfa için tipli bir rota sınıfı üretir (app_router.gr.dart):
//
//   ExpensesView         → ExpensesRoute()
//   CategoryExpensesView → CategoryExpensesRoute(slug: 'yemek')
//   ExpenseDetailView    → ExpenseDetailRoute(expense: e)
//   NewExpenseView       → NewExpenseRoute()
//   DocumentsView        → DocumentsRoute()
//   ImageViewerView      → ImageViewerRoute(document: d)   (Ders 5)
//   PdfViewerView        → PdfViewerRoute(document: d)     (Ders 5)
//   AudioPlayerView      → AudioPlayerRoute(document: d)   (Ders 5)
//   AnimationsView       → AnimationsRoute()               (Ders 6)
//   AnimationDemoView    → AnimationDemoRoute(senaryo: 'fade') (Ders 6)
//   PagedListView        → PagedListRoute()                (Ders 7)
//   PagedGridView        → PagedGridRoute()                (Ders 7)
//   AnimationControlView → AnimationControlRoute()         (Ders 8)
//   LottieView           → LottieRoute()                   (Ders 9)
//   SyncAsyncView        → SyncAsyncRoute()                (Ders 10)
//   StorageHubView       → StorageHubRoute()               (Ders 10)
//   SharedPreferencesView / HiveStorageView / SqfliteStorageView (Ders 10)
//   NetworkView          → NetworkRoute()                  (Ders 11)
//   DeviceView           → DeviceRoute()                   (Ders 12)
//   BlocDemoView         → BlocDemoRoute()                 (Ders 13)
//   DeviceInfoView       → DeviceInfoRoute()               (Ders 14)
//   AppNetworkView       → AppNetworkRoute()               (Ders 14)
//   CurrencyView         → CurrencyRoute()                 (Ders 15)
//   RetrofitView         → RetrofitRoute()                 (Ders 16)
//   ImageCacheView       → ImageCacheRoute()               (Ders 17)
//
// Uygulama içinde geçişler bu sınıflarla yapılır (yazı/yol yok):
//   context.router.push(ExpenseDetailRoute(expense: e));
//
// Aşağıdaki tablo hangi sayfanın hangi yolda olduğunu söyler; deep
// link'ler bu tabloyla eşlenir (önce AppDeepLinks.transform süzer).
// Bu dosya değişince: dart run build_runner build
// ─────────────────────────────────────────────────────────────────────────

/// DERS 6 — Bir rotaya [animation] geçişini verir.
///
/// `CustomRoute`, `AutoRoute`'un geçişi özelleştirilebilen hâlidir:
/// `transitionsBuilder` sayfanın nasıl gireceğini, `duration` ne kadar
/// süreceğini söyler.
CustomRoute<Object?> _animated(
  PageInfo page,
  String path,
  RouteAnimation animation,
) => CustomRoute<Object?>(
  page: page,
  path: path,
  transitionsBuilder: animation.transitionsBuilder,
  duration: animation.duration,
  reverseDuration: animation.duration,
);

/// Uygulamanın rota tablosu.
@AutoRouterConfig(replaceInRouteName: 'View,Route')
class AppRouter extends RootStackRouter {
  @override
  List<AutoRoute> get routes => [
    AutoRoute(page: ExpensesRoute.page, path: '/', initial: true),
    // DERS 6 — Mevcut sayfaların geçişleri:
    _animated(
      CategoryExpensesRoute.page,
      '/kategori/:slug',
      RouteAnimation.slideFromRight,
    ),
    // Detay ekranı nesne ister; dışarıdan gelen link buraya ulaşamaz.
    _animated(ExpenseDetailRoute.page, '/harcama', RouteAnimation.fadeUp),
    // Yeni harcama formu alttan açılan pencere (bottom sheet) olarak.
    CustomRoute<void>(
      page: NewExpenseRoute.page,
      path: '/yeni',
      customRouteBuilder: <T>(context, child, page) => ModalBottomSheetRoute<T>(
        settings: page,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => child,
      ),
    ),
    // DERS 5 — Belgeler: liste deep link ile açılır (/belgeler);
    // görüntüleyiciler DocumentItem nesnesi ister, dışarıdan açılamaz.
    _animated(DocumentsRoute.page, '/belgeler', RouteAnimation.slideFromRight),
    _animated(ImageViewerRoute.page, '/belge/gorsel', RouteAnimation.zoomOut),
    _animated(PdfViewerRoute.page, '/belge/pdf', RouteAnimation.slideUp),
    _animated(
      AudioPlayerRoute.page,
      '/belge/ses',
      RouteAnimation.circularReveal,
    ),
    // DERS 6 — Animasyon vitrini.
    _animated(
      AnimationsRoute.page,
      '/animasyonlar',
      RouteAnimation.slideFromRight,
    ),
    // Tek rota, 20 farklı geçiş: animasyonu gönderilen senaryo seçer.
    // Her senaryo kendi yolunda (/animasyon/fade ...) ve yoluyla tanınır;
    // yoksa 20 senaryo aynı adı taşıdığı için tek sayfa sanılırdı.
    CustomRoute<Object?>(
      page: AnimationDemoRoute.page,
      path: '/animasyon/:senaryo',
      usesPathAsKey: true,
      customRouteBuilder: <T>(context, child, page) => routeAnimationNamed(
        page.routeData.argsAs<AnimationDemoRouteArgs>().senaryo,
      ).buildRoute<T>(page, child),
    ),
    // DERS 7 — Sayfalı liste. Deep link beyaz listesinde yok; yalnızca
    // uygulama içinden açılır.
    _animated(
      PagedListRoute.page,
      '/ornek-liste',
      RouteAnimation.slideFromRight,
    ),
    // Ders dizini. Deep link beyaz listesinde yok.
    _animated(LessonsRoute.page, '/dersler', RouteAnimation.slideFromRight),
    // DERS 18 — Firebase. Deep link beyaz listesinde yok.
    _animated(FirebaseRoute.page, '/firebase', RouteAnimation.slideFromRight),
    // DERS 17 — Görsel önbelleği. Deep link beyaz listesinde yok.
    _animated(
      ImageCacheRoute.page,
      '/gorsel-onbellek',
      RouteAnimation.slideFromRight,
    ),
    // DERS 16 — retrofit. Deep link beyaz listesinde yok.
    _animated(RetrofitRoute.page, '/retrofit', RouteAnimation.slideFromRight),
    // DERS 15 — MVVM döviz ekranı. Deep link beyaz listesinde yok.
    _animated(CurrencyRoute.page, '/doviz', RouteAnimation.slideFromRight),
    // DERS 14 — Cihaz / uygulama / ağ bilgisi. Deep link beyaz listesinde
    // yok: kişiyi tanıtan bilgi gösterir, yalnızca uygulama içinden açılır.
    _animated(
      DeviceInfoRoute.page,
      '/cihaz-bilgisi',
      RouteAnimation.slideFromRight,
    ),
    _animated(
      AppNetworkRoute.page,
      '/uygulama-ag',
      RouteAnimation.slideFromRight,
    ),
    // DERS 13 — Bloc. Deep link beyaz listesinde yok.
    _animated(BlocDemoRoute.page, '/bloc', RouteAnimation.slideFromRight),
    // DERS 12 — GPS ve sensörler. Deep link beyaz listesinde yok.
    _animated(DeviceRoute.page, '/konum-sensor', RouteAnimation.slideFromRight),
    // DERS 11 — Ağ kontrolü. Deep link beyaz listesinde yok.
    _animated(NetworkRoute.page, '/ag', RouteAnimation.slideFromRight),
    // DERS 10 — Sync/async ve yerel depolama. Deep link beyaz listesinde yok.
    _animated(
      SyncAsyncRoute.page,
      '/sync-async',
      RouteAnimation.slideFromRight,
    ),
    _animated(StorageHubRoute.page, '/depolama', RouteAnimation.slideFromRight),
    _animated(
      SharedPreferencesRoute.page,
      '/depolama/prefs',
      RouteAnimation.slideFromRight,
    ),
    _animated(
      HiveStorageRoute.page,
      '/depolama/hive',
      RouteAnimation.slideFromRight,
    ),
    _animated(
      SqfliteStorageRoute.page,
      '/depolama/sqflite',
      RouteAnimation.slideFromRight,
    ),
    // DERS 9 — Lottie. Deep link beyaz listesinde yok.
    _animated(LottieRoute.page, '/lottie', RouteAnimation.slideFromRight),
    // DERS 8 — AnimationController. Deep link beyaz listesinde yok.
    _animated(
      AnimationControlRoute.page,
      '/animasyon-kontrolu',
      RouteAnimation.slideFromRight,
    ),
    _animated(
      PagedGridRoute.page,
      '/ornek-izgara',
      RouteAnimation.slideFromRight,
    ),
  ];
}
