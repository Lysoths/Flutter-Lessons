import 'dart:math' as math;

import 'package:flutter/material.dart';

/// DERS 8 — 3B objenin biçimi: hepsi en, boy ve derinliği farklı bir
/// kutudur.
enum Shape3D {
  /// Eşit kenarlı küp.
  cube('Küp', 130, 130, 130),

  /// İnce, geniş bir kart (banka kartı gibi).
  card('Kart', 180, 112, 10),

  /// Uzun, ince bir kule.
  tower('Kule', 80, 170, 80);

  const Shape3D(this.label, this.width, this.height, this.depth);

  /// Görünen ad.
  final String label;

  /// En (x).
  final double width;

  /// Boy (y).
  final double height;

  /// Derinlik (z).
  final double depth;
}

/// Paket kullanmadan çizilen 3B kutu.
///
/// Altı yüzün her biri düz bir `Container`'dır. `Matrix4` ile önce kendi
/// yerine döndürülüp ötelenir (ör. sağ yüz Y ekseninde 90°), sonra bütün
/// kutu [rotationX] / [rotationY] kadar döndürülür. Arkada kalan yüzler
/// önce çizilsin diye yüzler derinliğe göre sıralanır (ressam algoritması).
class Box3D extends StatelessWidget {
  /// [shape] biçiminde, verilen açılarla döndürülmüş bir kutu oluşturur.
  const Box3D({
    required this.shape,
    required this.rotationX,
    required this.rotationY,
    this.color = const Color(0xFF2563EB),
    super.key,
  });

  /// Kutunun ölçüleri.
  final Shape3D shape;

  /// X ekseni etrafında açı (radyan): öne/arkaya yatma.
  final double rotationX;

  /// Y ekseni etrafında açı (radyan): sağa/sola dönme.
  final double rotationY;

  /// Ana renk; yüzler bu rengin açık/koyu tonlarıdır.
  final Color color;

  @override
  Widget build(BuildContext context) {
    final w = shape.width;
    final h = shape.height;
    final d = shape.depth;
    // Perspektif: uzaktaki noktalar küçülür (3. satır 2. sütun).
    final view = Matrix4.identity()
      ..setEntry(3, 2, 0.0012)
      ..rotateX(rotationX)
      ..rotateY(rotationY);

    // (yüzün boyutu, yerine koyan dönüş, merkezden uzaklık, ton, etiket)
    final faces =
        <
          ({
            Size size,
            Matrix4 turn,
            double distance,
            double tone,
            String label,
          })
        >[
          (
            size: Size(w, h),
            turn: Matrix4.identity(),
            distance: d / 2,
            tone: 0,
            label: 'Ön',
          ),
          (
            size: Size(w, h),
            turn: Matrix4.rotationY(math.pi),
            distance: d / 2,
            tone: 0.35,
            label: 'Arka',
          ),
          (
            size: Size(d, h),
            turn: Matrix4.rotationY(math.pi / 2),
            distance: w / 2,
            tone: 0.2,
            label: 'Sağ',
          ),
          (
            size: Size(d, h),
            turn: Matrix4.rotationY(-math.pi / 2),
            distance: w / 2,
            tone: 0.2,
            label: 'Sol',
          ),
          (
            size: Size(w, d),
            turn: Matrix4.rotationX(-math.pi / 2),
            distance: h / 2,
            tone: -0.25,
            label: 'Üst',
          ),
          (
            size: Size(w, d),
            turn: Matrix4.rotationX(math.pi / 2),
            distance: h / 2,
            tone: 0.45,
            label: 'Alt',
          ),
        ];

    final placed = [
      for (final f in faces)
        (
          face: f,
          // Ekrana doğru eksi z: yüz merkezden "öne" itilir.
          matrix: view.clone()
            ..multiply(f.turn)
            ..translateByDouble(0, 0, -f.distance, 1),
        ),
    ]..sort((a, b) => b.matrix.storage[14].compareTo(a.matrix.storage[14]));

    final extent = [w, h, d].reduce(math.max) * 1.5;
    return SizedBox.square(
      dimension: extent,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (final p in placed)
            Transform(
              alignment: Alignment.center,
              transform: p.matrix,
              child: _Face(
                size: p.face.size,
                color: _shade(color, p.face.tone),
                label: p.face.label,
              ),
            ),
        ],
      ),
    );
  }

  /// [tone] > 0 koyulaştırır, < 0 açar.
  static Color _shade(Color c, double tone) => tone >= 0
      ? Color.lerp(c, Colors.black, tone)!
      : Color.lerp(c, Colors.white, -tone)!;
}

class _Face extends StatelessWidget {
  const _Face({required this.size, required this.color, required this.label});

  final Size size;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final small = size.shortestSide < 30;
    return Container(
      width: size.width,
      height: size.height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
      ),
      child: small
          ? null
          : Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
    );
  }
}
