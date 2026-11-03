import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_ders/app/theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────
// DERS 8 — Nabız tarzı animasyonlar
//
// Her efekt yalnızca bir sayıdan, t'den (0.0 → 1.0, bir tur) çizilir.
// t'yi AnimationController üretir ve sürekli tekrarlar (repeat). Efekt
// "t şu değerdeyken ekran nasıl görünür?" sorusunu cevaplar; React'teki
// `style={{ transform: scale(f(t)) }}` gibi.
// ─────────────────────────────────────────────────────────────────────────

/// Nabız efektleri.
enum PulseEffect {
  /// İki vuruşlu kalp atışı.
  heartbeat(
    'Kalp atışı',
    'TweenSequence: büyü, küçül, tekrar büyü, dinlen.',
    Duration(milliseconds: 1100),
    MfColors.red600,
  ),

  /// Dışa yayılan halkalar.
  ripple(
    'Dalga halkaları',
    'Üç halka sırayla büyüyüp solar (konum işareti).',
    Duration(milliseconds: 1800),
    MfColors.blue600,
  ),

  /// Yavaşça solup parlama.
  breathing(
    'Nefes',
    'Saydamlık ve boyut kosinüsle iner çıkar.',
    Duration(milliseconds: 3200),
    MfColors.emerald500,
  ),

  /// Kendini çizen EKG çizgisi.
  ecg(
    'EKG çizgisi',
    'CustomPainter: çizginin t kadarı çizilir.',
    Duration(milliseconds: 1600),
    MfColors.red600,
  ),

  /// Dönen radar ışını.
  radar(
    'Radar',
    'Tarama ışını t × 360° döner.',
    Duration(milliseconds: 2400),
    MfColors.emerald500,
  ),

  /// Sağa sola sallanan zil.
  bell(
    'Zil sallanması',
    'Sönümlenen sinüs: sallanır, durulur, bekler.',
    Duration(milliseconds: 1600),
    Color(0xFFF97316),
  ),

  /// Sırayla zıplayan noktalar.
  typing(
    'Yazıyor...',
    'Üç nokta, aralarında gecikmeyle zıplar.',
    Duration(milliseconds: 1200),
    Color(0xFF8B5CF6),
  ),

  /// Hızı ayarlanabilen nabız.
  bpm(
    'Nabız hızı (bpm)',
    'Süre = 60 / bpm saniye; kaydırıcı controller.duration\'ı değiştirir.',
    Duration(milliseconds: 833),
    MfColors.red600,
  );

  const PulseEffect(this.label, this.description, this.period, this.color);

  /// Görünen ad.
  final String label;

  /// Kısa açıklama.
  final String description;

  /// Bir turun süresi.
  final Duration period;

  /// Efekt rengi.
  final Color color;

  /// [t] anındaki görüntü.
  Widget frame(double t) => switch (this) {
    PulseEffect.heartbeat || PulseEffect.bpm => _Heartbeat(t: t, color: color),
    PulseEffect.ripple => _Ripple(t: t, color: color),
    PulseEffect.breathing => _Breathing(t: t, color: color),
    PulseEffect.ecg => CustomPaint(
      size: const Size(200, 90),
      painter: _EcgPainter(t: t, color: color),
    ),
    PulseEffect.radar => CustomPaint(
      size: const Size.square(120),
      painter: _RadarPainter(t: t, color: color),
    ),
    PulseEffect.bell => _Bell(t: t, color: color),
    PulseEffect.typing => _Typing(t: t, color: color),
  };
}

class _Heartbeat extends StatelessWidget {
  const _Heartbeat({required this.t, required this.color});

  final double t;
  final Color color;

  /// Bir turdaki ölçek: ağırlıklar turun yüzde kaçını aldığını söyler.
  static final _scale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 1,
        end: 1.3,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 12,
    ),
    TweenSequenceItem(tween: Tween(begin: 1.3, end: 1), weight: 10),
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 1,
        end: 1.18,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 12,
    ),
    TweenSequenceItem(tween: Tween(begin: 1.18, end: 1), weight: 16),
    TweenSequenceItem(tween: ConstantTween(1), weight: 50),
  ]);

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: _scale.transform(t.clamp(0, 1)),
      child: Icon(Icons.favorite_rounded, color: color, size: 64),
    );
  }
}

class _Ripple extends StatelessWidget {
  const _Ripple({required this.t, required this.color});

  final double t;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 130,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (var i = 0; i < 3; i++)
            Builder(
              builder: (context) {
                // Her halka turun üçte biri kadar geriden gelir.
                final p = (t + i / 3) % 1;
                return Container(
                  width: 40 + 90 * p,
                  height: 40 + 90 * p,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: color.withValues(alpha: 1 - p),
                      width: 3,
                    ),
                  ),
                );
              },
            ),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: const Icon(Icons.location_on, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _Breathing extends StatelessWidget {
  const _Breathing({required this.t, required this.color});

  final double t;
  final Color color;

  @override
  Widget build(BuildContext context) {
    // 0 → 1 → 0: kosinüs ile yumuşak iniş çıkış.
    final b = 0.5 - 0.5 * math.cos(2 * math.pi * t);
    return Opacity(
      opacity: (0.35 + 0.65 * b).clamp(0, 1),
      child: Transform.scale(
        scale: 0.85 + 0.25 * b,
        child: Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.15),
            border: Border.all(color: color, width: 3),
          ),
          child: Icon(Icons.spa_rounded, color: color, size: 44),
        ),
      ),
    );
  }
}

class _Bell extends StatelessWidget {
  const _Bell({required this.t, required this.color});

  final double t;
  final Color color;

  @override
  Widget build(BuildContext context) {
    // Turun ilk %60'ında 3 kez sallanır, giderek durulur; sonra bekler.
    final p = (t / 0.6).clamp(0.0, 1.0);
    final angle = t < 0.6
        ? math.sin(p * 2 * math.pi * 3) * 0.45 * (1 - p)
        : 0.0;
    return Transform.rotate(
      angle: angle,
      alignment: const Alignment(0, -0.8),
      child: Icon(Icons.notifications_active_rounded, color: color, size: 64),
    );
  }
}

class _Typing extends StatelessWidget {
  const _Typing({required this.t, required this.color});

  final double t;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Transform.translate(
                // Her nokta bir öncekinden %15 geç zıplar; inişte bekler.
                offset: Offset(
                  0,
                  -10 * math.max(0, math.sin(2 * math.pi * (t - i * 0.15))),
                ),
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EcgPainter extends CustomPainter {
  _EcgPainter({required this.t, required this.color});

  final double t;
  final Color color;

  /// Bir kalp atışının çizgisi (x, y; 0..1, 0.5 = düz çizgi).
  static const _points = [
    Offset(0, .5),
    Offset(.22, .5),
    Offset(.27, .42),
    Offset(.32, .5),
    Offset(.4, .5),
    Offset(.44, .62),
    Offset(.5, .04),
    Offset(.56, .9),
    Offset(.6, .5),
    Offset(.7, .5),
    Offset(.77, .36),
    Offset(.84, .5),
    Offset(1, .5),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    for (final (i, p) in _points.indexed) {
      final x = p.dx * size.width;
      final y = p.dy * size.height;
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, stroke..color = color.withValues(alpha: 0.12));

    // Yolun yalnızca t kadarını çiz; ucuna parlak bir nokta koy.
    final metric = path.computeMetrics().first;
    final length = metric.length * t.clamp(0, 1);
    canvas.drawPath(metric.extractPath(0, length), stroke..color = color);
    final tip = metric.getTangentForOffset(length)?.position;
    if (tip != null) {
      canvas
        ..drawCircle(tip, 9, Paint()..color = color.withValues(alpha: 0.25))
        ..drawCircle(tip, 4.5, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_EcgPainter old) => old.t != t || old.color != color;
}

class _RadarPainter extends CustomPainter {
  _RadarPainter({required this.t, required this.color});

  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final grid = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = color.withValues(alpha: 0.35);
    for (final r in [radius, radius * 0.66, radius * 0.33]) {
      canvas.drawCircle(center, r, grid);
    }
    canvas
      ..drawLine(center - Offset(radius, 0), center + Offset(radius, 0), grid)
      ..drawLine(center - Offset(0, radius), center + Offset(0, radius), grid);

    // Işın: t × 360° dönmüş, arkasından solan bir dilim.
    final angle = 2 * math.pi * t;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final sweep = Paint()
      ..shader = SweepGradient(
        colors: [color.withValues(alpha: 0), color.withValues(alpha: 0.55)],
        stops: const [0.75, 1],
        transform: GradientRotation(angle - 2 * math.pi),
      ).createShader(rect);
    canvas
      ..drawCircle(center, radius, sweep)
      ..drawLine(
        center,
        center + Offset(math.cos(angle), math.sin(angle)) * radius,
        Paint()
          ..color = color
          ..strokeWidth = 2,
      );

    // Işın üstünden geçince parlayan hedef nokta.
    const blipAngle = math.pi * 0.3;
    final since = (angle - blipAngle) % (2 * math.pi) / (2 * math.pi);
    final blip =
        center +
        Offset(math.cos(blipAngle), math.sin(blipAngle)) * radius * 0.6;
    canvas.drawCircle(
      blip,
      5,
      Paint()..color = color.withValues(alpha: (1 - since).clamp(0, 1)),
    );
  }

  @override
  bool shouldRepaint(_RadarPainter old) => old.t != t || old.color != color;
}
