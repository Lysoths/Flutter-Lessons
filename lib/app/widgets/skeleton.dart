import 'package:flutter/material.dart';
import 'package:flutter_ders/app/theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────
// DERS 7 — İskelet (skeleton) yükleme
//
// Veri gelene kadar gerçek kartın yerine aynı boyutta gri kutular çizilir;
// üstlerinden soldan sağa bir parıltı geçer. Kullanıcı ne geleceğini
// önceden görür, veri gelince sayfa zıplamaz.
//
// Parıltı = ShaderMask: çocuğun (gri kutuların) üstüne kayan bir renk
// geçişi (LinearGradient) boyar. BlendMode.srcATop sayesinde yalnızca
// kutuların olduğu yer boyanır, aradaki boşluklar şeffaf kalır.
// ─────────────────────────────────────────────────────────────────────────

/// İskeletin gri kutusu.
class SkeletonBox extends StatelessWidget {
  /// [width] x [height] boyutunda bir kutu oluşturur.
  const SkeletonBox({
    required this.height,
    this.width,
    this.radius = 6,
    super.key,
  });

  /// Genişlik; verilmezse bulunduğu yeri doldurur.
  final double? width;

  /// Yükseklik.
  final double height;

  /// Köşe yuvarlaklığı.
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: MfColors.slate200,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// [child] içindeki iskelet kutularının üstünden parıltı geçirir.
///
/// Sistemde "animasyonları azalt" açıksa parıltı oynamaz.
class Shimmer extends StatefulWidget {
  /// [child] için parıltı oluşturur.
  const Shimmer({required this.child, super.key});

  /// Parıltının bir kez geçme süresi.
  static const period = Duration(milliseconds: 1400);

  /// Parıldayan iskelet.
  final Widget child;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Shimmer.period,
  );

  @override
  void initState() {
    super.initState();
    // Farklı zamanda oluşan kartlar aynı anda parlasın diye başlangıç
    // noktası saatten hesaplanır.
    final ms = Shimmer.period.inMilliseconds;
    _controller
      ..value = (DateTime.now().millisecondsSinceEpoch % ms) / ms
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) => ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (bounds) => LinearGradient(
          colors: const [
            MfColors.slate200,
            MfColors.slate50,
            MfColors.slate200,
          ],
          stops: const [0.35, 0.5, 0.65],
          // -1 → 1: parıltı soldan girer, sağdan çıkar.
          transform: _SlideGradient(_controller.value * 2 - 1),
        ).createShader(bounds),
        child: child,
      ),
    );
  }
}

/// Renk geçişini yatayda [percent] kadar kaydırır.
class _SlideGradient extends GradientTransform {
  const _SlideGradient(this.percent);

  final double percent;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * percent, 0, 0);
}
