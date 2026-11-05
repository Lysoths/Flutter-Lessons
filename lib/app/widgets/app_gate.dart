import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_ders/app/core/firebase/app_config_cubit.dart';
import 'package:flutter_ders/app/core/firebase/remote_app_config.dart';
import 'package:flutter_ders/app/core/firebase/session_cubit.dart';
import 'package:flutter_ders/app/views/view_auth/auth_view.dart';
import 'package:flutter_ders/app/views/view_update/update_views.dart';

/// DERS 18 — Uygulamanın kapısı (`MaterialApp.builder` içinde).
///
///   1. Sürüm < min_surum             → ForceUpdateView (kilit)
///   2. Oturum yok                    → AuthView
///   3. Hepsi tamam                   → uygulama (+ son_surum altındaysa kart)
///
/// main.dart ayarları runApp'ten önce yükler; yüklenmemişse (testler)
/// kapı varsayılanlarla çalışır.
///
/// Kapı rota değildir: içerideki yönlendirme (auto_route) ve deep link'ler
/// olduğu gibi kalır; giriş yapılınca kullanıcı bıraktığı yere döner.
class AppGate extends StatelessWidget {
  /// Oluşturur; [child] yönlendiricinin Navigator'ıdır.
  const AppGate({required this.child, super.key});

  /// Uygulamanın kendisi.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final config = context.watch<AppConfigCubit>().state;
    final signedIn = context.select<SessionCubit, bool>(
      (c) => c.state.signedIn,
    );
    final media = MediaQuery.of(context);
    // Tasarımdaki yazı ölçeği, cihazın ayarıyla çarpılır.
    return MediaQuery(
      data: media.copyWith(
        textScaler: config.config.design.textScale == 1
            ? media.textScaler
            : TextScaler.linear(
                media.textScaler.scale(14) /
                    14 *
                    config.config.design.textScale,
              ),
      ),
      child: switch (config) {
        _ when config.updateStatus == UpdateStatus.forced => const _Own(
          child: ForceUpdateView(),
        ),
        _ when !signedIn => const _Own(child: AuthView()),
        _ => Stack(
          children: [
            child,
            if (config.updateStatus == UpdateStatus.optional &&
                !config.optionalDismissed)
              Positioned(
                left: 12,
                right: 12,
                bottom: 12 + media.padding.bottom,
                child: const OptionalUpdateCard(),
              ),
          ],
        ),
      },
    );
  }
}

/// Kapı ekranları için kendi Navigator'ı: metin alanı menüsü ve diyaloglar
/// bir Overlay ister. Rotası yoktur (path kullanılmaz).
class _Own extends StatelessWidget {
  const _Own({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Navigator(
    key: ValueKey(child.runtimeType),
    onGenerateInitialRoutes: (_, _) => [
      MaterialPageRoute<void>(builder: (_) => child),
    ],
  );
}
