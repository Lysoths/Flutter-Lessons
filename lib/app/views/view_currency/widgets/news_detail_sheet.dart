import 'package:flutter/material.dart';
import 'package:flutter_ders/app/core/repository/news_repository.dart';
import 'package:flutter_ders/app/models/currency/currency_info.dart';
import 'package:flutter_ders/app/models/currency/news_article.dart';
import 'package:flutter_ders/app/theme/app_theme.dart';
import 'package:flutter_ders/app/widgets/common.dart';
import 'package:url_launcher/url_launcher.dart';

/// DERS 15 — Haberin ayrıntısını alttan açılan pencerede (modal) gösterir.
///
/// Modal veriyi kendisi çekmez: dokunulan haber nesnesi verilir.
Future<void> showNewsDetail(BuildContext context, NewsArticle article) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) => NewsDetailSheet(article),
    );

/// Haber modalının içeriği.
class NewsDetailSheet extends StatelessWidget {
  /// [article] için içerik oluşturur.
  const NewsDetailSheet(this.article, {super.key});

  /// Gösterilen haber.
  final NewsArticle article;

  // Yalnızca bilinen haber sitelerine gidilir; RSS'e başka bir adres
  // karışsa bile açılmaz.
  bool get _trustedLink =>
      article.link.scheme == 'https' && kNewsHosts.contains(article.link.host);

  Future<void> _open(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok =
        _trustedLink &&
        await launchUrl(article.link, mode: LaunchMode.externalApplication);
    if (!ok) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Haber kaynağı açılamadı.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, controller) => ListView(
        key: const Key('news_detail'),
        controller: controller,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          if (article.imageUrl != null) ...[
            NewsImage(article.imageUrl, height: 190),
            const Gap(14),
          ],
          Text(article.title, style: t.titleLarge),
          const Gap(8),
          Text(
            '${article.source} · ${newsTime(article.publishedAt, full: true)}',
            style: t.bodySmall,
          ),
          if (article.currencies.isNotEmpty) ...[
            const Gap(10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final c in article.currencies)
                  Eyebrow('${currencyInfo(c).flag} ${currencyInfo(c).name}'),
              ],
            ),
          ],
          const Gap(16),
          Text(
            article.summary.isEmpty ? 'Özet yok.' : article.summary,
            style: t.bodyLarge?.copyWith(height: 1.5),
          ),
          const Gap(20),
          FilledButton.icon(
            key: const Key('news_open_source'),
            onPressed: _trustedLink ? () => _open(context) : null,
            style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
            icon: const Icon(Icons.open_in_new_rounded),
            label: Text('${article.source} sitesinde oku'),
          ),
          const Gap(8),
          Text(
            article.link.host,
            textAlign: TextAlign.center,
            style: t.bodySmall?.copyWith(color: MfColors.slate400),
          ),
        ],
      ),
    );
  }
}

/// Haber görseli; yoksa ya da yüklenemezse gazete simgesi.
class NewsImage extends StatelessWidget {
  /// Görsel oluşturur.
  const NewsImage(this.url, {super.key, this.width, this.height});

  /// Görsel adresi.
  final String? url;

  /// Genişlik (null: tüm genişlik).
  final double? width;

  /// Yükseklik.
  final double? height;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: width,
      height: height,
      color: MfColors.slate100,
      child: const Icon(Icons.newspaper_rounded, color: MfColors.slate400),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: switch (url) {
        final u? when u.startsWith('https://') => Image.network(
          u,
          width: width,
          height: height,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => placeholder,
          loadingBuilder: (_, child, progress) =>
              progress == null ? child : placeholder,
        ),
        _ => placeholder,
      },
    );
  }
}

/// Haber saati: bugünse `13:24`, değilse `03.11 13:24`; [full] ile yıl da.
String newsTime(DateTime d, {bool full = false, DateTime? now}) {
  String two(int n) => n.toString().padLeft(2, '0');
  final n = now ?? DateTime.now();
  final time = '${two(d.hour)}:${two(d.minute)}';
  final sameDay = d.year == n.year && d.month == n.month && d.day == n.day;
  if (full) return '${two(d.day)}.${two(d.month)}.${d.year} $time';
  return sameDay ? time : '${two(d.day)}.${two(d.month)} $time';
}
