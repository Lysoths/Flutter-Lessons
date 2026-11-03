import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────
// DERS 6 — Rota geçiş animasyonları
//
// Bir sayfa açılırken Flutter iki animasyon değeri verir (0.0 → 1.0):
//   • animation          → AÇILAN sayfanın ilerlemesi
//   • secondaryAnimation → bu sayfanın ÜSTÜNE yeni sayfa açılırken ilerleme
// Geçiş = bu değeri bir "Transition" widget'ına bağlamaktır:
//   FadeTransition(opacity: animation, child: sayfa)   → solma
//   SlideTransition(position: ..., child: sayfa)       → kayma
//   ScaleTransition(scale: ..., child: sayfa)          → büyüme
// Kapanırken aynı animasyon tersine (1.0 → 0.0) oynar.
//
// auto_route'ta geçiş rota tablosunda verilir:
//   CustomRoute(page: X.page, transitionsBuilder: ..., duration: ...)
// ─────────────────────────────────────────────────────────────────────────

/// 20 geçiş senaryosu. Her biri bir ad, açıklama, süre ve geçiş tarifi
/// taşır.
enum RouteAnimation {
  /// Saydamlıktan görünür olma.
  fade('Solma', 'Sayfa saydamdan görünür hale gelir.', Icons.blur_on),

  /// Sağdan kayarak gelme.
  slideFromRight('Sağdan kayma', 'Sayfa ekranın sağından girer.', Icons.east),

  /// Soldan kayarak gelme.
  slideFromLeft('Soldan kayma', 'Sayfa ekranın solundan girer.', Icons.west),

  /// Alttan yükselme.
  slideUp('Alttan kayma', 'Sayfa aşağıdan yukarı çıkar.', Icons.north),

  /// Üstten inme.
  slideDown('Üstten kayma', 'Sayfa yukarıdan aşağı iner.', Icons.south),

  /// Ortadan büyüme.
  scale('Büyüyerek açılma', 'Sayfa ortadan küçükten büyür.', Icons.zoom_in),

  /// Büyükten küçülerek yerleşme.
  zoomOut(
    'Küçülerek yerleşme',
    'Sayfa büyük ve saydam başlar, küçülerek oturur.',
    Icons.zoom_out,
  ),

  /// Dönerek gelme.
  rotate('Dönerek gelme', 'Sayfa yarım tur dönerek büyür.', Icons.rotate_right),

  /// Solup hafifçe yükselme (Material "fade through" benzeri).
  fadeUp(
    'Solup yükselme',
    'Sayfa solarken hafifçe yukarı kayar.',
    Icons.vertical_align_top,
  ),

  /// Yukarıdan aşağı perde gibi açılma.
  curtain('Perde', 'Sayfa yukarıdan aşağı perde gibi açılır.', Icons.blinds),

  /// Ortadan büyüyen daire.
  circularReveal(
    'Dairesel açılma',
    'Sayfa ortadan büyüyen bir daire içinde görünür.',
    Icons.circle_outlined,
  ),

  /// Dikey eksende 3B çevirme.
  flipY('Kart çevirme (dikey)', 'Sayfa kart gibi yana döner.', Icons.flip),

  /// Yatay eksende 3B çevirme.
  flipX(
    'Kart çevirme (yatay)',
    'Sayfa yukarıdan aşağı devrilir.',
    Icons.flip_camera_android,
  ),

  /// Yay gibi esneyerek büyüme.
  elastic('Elastik', 'Sayfa yay gibi biraz taşıp yerine oturur.', Icons.waves),

  /// Yukarıdan düşüp zıplama.
  bounce(
    'Zıplama',
    'Sayfa yukarıdan düşer ve zıplar.',
    Icons.sports_basketball,
  ),

  /// Bulanıktan netleşme.
  blur('Netleşme', 'Sayfa bulanık başlar, netleşir.', Icons.lens_blur),

  /// Ortak öğe (Hero): ikon listeden yeni sayfaya uçar.
  hero(
    'Ortak öğe (Hero)',
    'Listedeki ikon yeni sayfadaki yerine uçar.',
    Icons.flight_takeoff,
  ),

  /// iOS tarzı (kenardan kaydırarak geri gelinebilir).
  cupertino(
    'iOS tarzı',
    'iPhone geçişi; soldan kaydırarak geri dönülür.',
    Icons.phone_iphone,
  ),

  /// Android/Material tarzı.
  material(
    'Android tarzı',
    'Platformun varsayılan Material geçişi.',
    Icons.android,
  ),

  /// Hiç animasyon yok.
  none('Animasyonsuz', 'Sayfa anında değişir.', Icons.flash_on);

  const RouteAnimation(this.label, this.description, this.icon);

  /// Görünen ad.
  final String label;

  /// Kısa açıklama.
  final String description;

  /// Liste ikonu.
  final IconData icon;

  /// Açılma süresi.
  Duration get duration => switch (this) {
    RouteAnimation.none => Duration.zero,
    RouteAnimation.elastic ||
    RouteAnimation.bounce => const Duration(milliseconds: 900),
    RouteAnimation.rotate ||
    RouteAnimation.flipX ||
    RouteAnimation.flipY ||
    RouteAnimation.circularReveal ||
    RouteAnimation.blur ||
    RouteAnimation.hero => const Duration(milliseconds: 600),
    _ => const Duration(milliseconds: 400),
  };

  /// [page] ayarlarıyla [child] için bu senaryonun rotasını kurar.
  /// auto_route'un `customRouteBuilder`'ından çağrılır.
  Route<T> buildRoute<T>(Page<T> page, Widget child) => switch (this) {
    RouteAnimation.cupertino => CupertinoPageRoute<T>(
      settings: page,
      builder: (_) => child,
    ),
    RouteAnimation.material => MaterialPageRoute<T>(
      settings: page,
      builder: (_) => child,
    ),
    _ => PageRouteBuilder<T>(
      settings: page,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      pageBuilder: (_, _, _) => child,
      transitionsBuilder: transitionsBuilder,
    ),
  };

  /// Açılan sayfayı [animation] değerine göre saran geçiş.
  Widget transitionsBuilder(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    Animation<double> curved(Curve curve) =>
        CurvedAnimation(parent: animation, curve: curve);
    Animation<Offset> slideFrom(
      Offset begin, [
      Curve c = Curves.easeOutCubic,
    ]) => Tween(begin: begin, end: Offset.zero).animate(curved(c));

    switch (this) {
      case RouteAnimation.fade:
      case RouteAnimation.hero:
        return FadeTransition(opacity: animation, child: child);
      case RouteAnimation.slideFromRight:
        return SlideTransition(
          position: slideFrom(const Offset(1, 0)),
          child: child,
        );
      case RouteAnimation.slideFromLeft:
        return SlideTransition(
          position: slideFrom(const Offset(-1, 0)),
          child: child,
        );
      case RouteAnimation.slideUp:
        return SlideTransition(
          position: slideFrom(const Offset(0, 1)),
          child: child,
        );
      case RouteAnimation.slideDown:
        return SlideTransition(
          position: slideFrom(const Offset(0, -1)),
          child: child,
        );
      case RouteAnimation.scale:
        return ScaleTransition(
          scale: curved(Curves.easeOutCubic),
          child: child,
        );
      case RouteAnimation.zoomOut:
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween(
              begin: 1.3,
              end: 1.0,
            ).animate(curved(Curves.easeOutCubic)),
            child: child,
          ),
        );
      case RouteAnimation.rotate:
        return RotationTransition(
          turns: Tween(
            begin: -0.5,
            end: 0.0,
          ).animate(curved(Curves.easeOutBack)),
          child: ScaleTransition(scale: curved(Curves.easeOut), child: child),
        );
      case RouteAnimation.fadeUp:
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: slideFrom(const Offset(0, 0.06)),
            child: child,
          ),
        );
      case RouteAnimation.curtain:
        return Align(
          alignment: Alignment.topCenter,
          child: SizeTransition(
            sizeFactor: curved(Curves.easeInOutCubic),
            alignment: Alignment.topCenter,
            child: child,
          ),
        );
      case RouteAnimation.circularReveal:
        return AnimatedBuilder(
          animation: curved(Curves.easeInOut),
          builder: (context, child) => ClipPath(
            clipper: _CircleRevealClipper(
              Curves.easeInOut.transform(animation.value),
            ),
            child: child,
          ),
          child: child,
        );
      case RouteAnimation.flipY:
      case RouteAnimation.flipX:
        final horizontal = this == RouteAnimation.flipY;
        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            final t = Curves.easeOutCubic.transform(animation.value);
            final angle = (1 - t) * math.pi / 2;
            final matrix = Matrix4.identity()..setEntry(3, 2, 0.0015);
            if (horizontal) {
              matrix.rotateY(angle);
            } else {
              matrix.rotateX(angle);
            }
            return Transform(
              alignment: Alignment.center,
              transform: matrix,
              child: child,
            );
          },
          child: child,
        );
      case RouteAnimation.elastic:
        return ScaleTransition(scale: curved(Curves.elasticOut), child: child);
      case RouteAnimation.bounce:
        return SlideTransition(
          position: slideFrom(const Offset(0, -1), Curves.bounceOut),
          child: child,
        );
      case RouteAnimation.blur:
        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            final sigma = (1 - animation.value) * 20;
            return Opacity(
              opacity: animation.value,
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                child: child,
              ),
            );
          },
          child: child,
        );
      case RouteAnimation.cupertino:
      case RouteAnimation.material:
      case RouteAnimation.none:
        return child;
    }
  }
}

/// Adından senaryoyu bulur; bilinmeyen ad için [RouteAnimation.fade].
RouteAnimation routeAnimationNamed(String name) =>
    RouteAnimation.values.asNameMap()[name] ?? RouteAnimation.fade;

/// Ortadan büyüyen daire biçiminde kırpar.
class _CircleRevealClipper extends CustomClipper<Path> {
  _CircleRevealClipper(this.fraction);

  final double fraction;

  @override
  Path getClip(Size size) {
    final center = size.center(Offset.zero);
    final maxRadius = math.sqrt(
      size.width * size.width + size.height * size.height,
    );
    return Path()
      ..addOval(Rect.fromCircle(center: center, radius: maxRadius * fraction));
  }

  @override
  bool shouldReclip(_CircleRevealClipper oldClipper) =>
      oldClipper.fraction != fraction;
}
