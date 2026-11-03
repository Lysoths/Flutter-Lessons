import 'package:flutter/animation.dart';

/// DERS 8 — Seçilebilen eğriler (Curves).
///
/// Eğri, 0 → 1 giden düz zamanı "nasıl" ilerleyeceğine çevirir:
/// doğrusal hep aynı hızda, yumuşak yavaş başlayıp yavaş biter, elastik
/// hedefi geçip geri döner, zıplama hedefe çarpıp seker.
enum CurveOption {
  /// Hep aynı hız.
  linear('Doğrusal', Curves.linear),

  /// Yavaş başla, hızlan, yavaş bitir.
  easeInOut('Yumuşak', Curves.easeInOutCubic),

  /// Hızlı başla, yavaşlayarak dur.
  decelerate('Yavaşlayan', Curves.decelerate),

  /// Biraz geri çekilip ileri atıl, hedefi aşıp geri dön.
  back('Geri yaylanma', Curves.easeInOutBack),

  /// Yay gibi titreyerek otur.
  elastic('Elastik', Curves.elasticOut),

  /// Top gibi sekerek dur.
  bounce('Zıplama', Curves.bounceOut);

  const CurveOption(this.label, this.curve);

  /// Görünen ad.
  final String label;

  /// Flutter eğrisi.
  final Curve curve;
}
