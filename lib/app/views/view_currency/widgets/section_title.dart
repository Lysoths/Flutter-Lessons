import 'package:flutter/material.dart';
import 'package:flutter_ders/app/theme/app_theme.dart';

/// DERS 15 — Bölüm başlığı: numara, başlık, sağda isteğe bağlı bilgi.
class CurrencySectionTitle extends StatelessWidget {
  /// Başlık oluşturur.
  const CurrencySectionTitle({
    required this.number,
    required this.title,
    super.key,
    this.trailing,
  });

  /// Bölüm numarası.
  final int number;

  /// Başlık.
  final String title;

  /// Sağdaki küçük bilgi.
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: MfColors.blue600,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: t.titleMedium)),
          if (trailing case final text?)
            Text(text, style: t.bodySmall?.copyWith(color: MfColors.slate500)),
        ],
      ),
    );
  }
}

/// Hata satırı ve "Tekrar dene" düğmesi.
class CurrencyErrorRow extends StatelessWidget {
  /// Satır oluşturur.
  const CurrencyErrorRow({
    required this.message,
    required this.onRetry,
    super.key,
  });

  /// Açıklama.
  final String message;

  /// Tekrar deneme.
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded, color: MfColors.red600),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: t.titleSmall)),
          TextButton(onPressed: onRetry, child: const Text('Tekrar dene')),
        ],
      ),
    );
  }
}

/// Değişim yüzdesinin rengi: artış kırmızı (₺ değer kaybetti), düşüş yeşil.
Color changeColor(double percent) => percent > 0
    ? MfColors.red600
    : percent < 0
    ? MfColors.emerald500
    : MfColors.slate500;
