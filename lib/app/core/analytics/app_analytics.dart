import 'package:auto_route/auto_route.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';

// ─────────────────────────────────────────────────────────────────────────
// Firebase Analytics
//
//   Kendiliğinden gelenler   first_open, session_start, user_engagement
//   Bizim gönderdiklerimiz   screen_view  (AnalyticsRouteObserver)
//                            harcama_eklendi {kategori}
//
// Konsol: Analytics → Realtime (1-2 dk gecikme) ya da DebugView (anlık).
// DebugView için telefonda bir kez:
//   adb shell setprop debug.firebase.analytics.app com.ogzhner.flutter_ders
// ─────────────────────────────────────────────────────────────────────────

/// Uygulamanın olay gönderdiği tek yer. Ekranlar ve cubit'ler Firebase'i
/// doğrudan bilmez; testlerde Firebase başlatılmadığı için sessiz kalır.
abstract interface class AppAnalytics {
  /// Ekran açıldı.
  Future<void> logScreen(String name);

  /// Özel olay; [params] değerleri String ya da num olmalı.
  Future<void> logEvent(String name, [Map<String, Object>? params]);
}

/// Firebase Analytics'e gönderen uygulama.
class FirebaseAppAnalytics implements AppAnalytics {
  /// Oluşturur.
  const FirebaseAppAnalytics();

  // Firebase başlatılmadıysa (ör. testler) hiçbir şey gönderilmez.
  FirebaseAnalytics? get _fa =>
      Firebase.apps.isEmpty ? null : FirebaseAnalytics.instance;

  @override
  Future<void> logScreen(String name) async =>
      _fa?.logScreenView(screenName: name, screenClass: name);

  @override
  Future<void> logEvent(String name, [Map<String, Object>? params]) async =>
      _fa?.logEvent(name: name, parameters: params);
}

/// Hiçbir şey göndermeyen uygulama (varsayılan).
class NoopAnalytics implements AppAnalytics {
  /// Oluşturur.
  const NoopAnalytics();

  @override
  Future<void> logScreen(String name) async {}

  @override
  Future<void> logEvent(String name, [Map<String, Object>? params]) async {}
}

/// auto_route geçişlerini `screen_view` olarak gönderir.
/// Ad, rota sınıfının adıdır (ör. `CurrencyRoute`); parametre ve yol
/// gönderilmez.
class AnalyticsRouteObserver extends AutoRouterObserver {
  /// Oluşturur.
  AnalyticsRouteObserver(this._analytics);

  final AppAnalytics _analytics;

  void _send(Route<dynamic>? route) {
    // Diyalog ve alt sayfalar (bottom sheet) sayfa sayılmaz.
    if (route is! PageRoute) return;
    final name = route.settings.name;
    if (name != null) _analytics.logScreen(name).ignore();
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _send(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _send(previousRoute);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _send(newRoute);
}
