import 'package:flutter/material.dart';
import 'package:flutter_ders/app/theme/app_theme.dart';

/// Sayfa kenar boşluğu: 20pt + yatay güvenli alan (duo'daki `pagePadding`).
EdgeInsets pagePadding(BuildContext context) {
  final pad = MediaQuery.paddingOf(context);
  return EdgeInsets.only(left: pad.left + 20, right: pad.right + 20);
}

/// Küçük yuvarlak etiket (masterfabric.co'daki "eyebrow" çipleri).
class Eyebrow extends StatelessWidget {
  /// Bir etiket oluşturur.
  const Eyebrow(
    this.text, {
    super.key,
    this.color = MfColors.blue700,
    this.background = MfColors.blue50,
  });

  /// Etiket metni.
  final String text;

  /// Metin rengi.
  final Color color;

  /// Arka plan rengi.
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

/// Bir bölümün etiketi, başlığı ve isteğe bağlı açıklaması.
class SectionHeader extends StatelessWidget {
  /// Bir bölüm başlığı oluşturur.
  const SectionHeader({
    required this.title,
    super.key,
    this.eyebrow,
    this.body,
  });

  /// Başlığın üstündeki küçük etiket.
  final String? eyebrow;

  /// Bölüm başlığı.
  final String title;

  /// Başlığın altındaki açıklama.
  final String? body;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (eyebrow != null) ...[Eyebrow(eyebrow!), const Gap(12)],
        Text(title, style: t.headlineSmall),
        if (body != null) ...[const Gap(6), Text(body!, style: t.bodyMedium)],
      ],
    );
  }
}

/// Renkli kare ikon rozeti (duo'daki `FeatureCard` ikonu).
class IconBadge extends StatelessWidget {
  /// [icon] için [accent] renkli bir rozet oluşturur.
  const IconBadge(
    this.icon, {
    super.key,
    this.accent = MfColors.blue600,
    this.size = 40,
  });

  /// Gösterilen ikon.
  final IconData icon;

  /// Vurgu rengi.
  final Color accent;

  /// Kenar uzunluğu.
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(size / 4),
      ),
      child: Icon(icon, color: accent, size: size * 0.55),
    );
  }
}

/// Dikey boşluk.
class Gap extends StatelessWidget {
  /// [size] yüksekliğinde boşluk oluşturur.
  const Gap(this.size, {super.key});

  /// Boşluğun yüksekliği.
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(height: size);
}
