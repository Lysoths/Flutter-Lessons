import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ders/app/core/router/route_transitions.dart';
import 'package:flutter_ders/app/models/document_item.dart';
import 'package:flutter_ders/app/models/expense.dart';
import 'package:flutter_ders/app/views/view_animations/animation_demo_view.dart';
import 'package:flutter_ders/app/views/view_animations/animations_view.dart';
import 'package:flutter_ders/app/views/view_audio_player/audio_player_view.dart';
import 'package:flutter_ders/app/views/view_category/category_expenses_view.dart';
import 'package:flutter_ders/app/views/view_documents/documents_view.dart';
import 'package:flutter_ders/app/views/view_expense_detail/expense_detail_view.dart';
import 'package:flutter_ders/app/views/view_expenses/expenses_view.dart';
import 'package:flutter_ders/app/views/view_image_viewer/image_viewer_view.dart';
import 'package:flutter_ders/app/views/view_new_expense/new_expense_view.dart';
import 'package:flutter_ders/app/views/view_pdf_viewer/pdf_viewer_view.dart';

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
  ];
}
