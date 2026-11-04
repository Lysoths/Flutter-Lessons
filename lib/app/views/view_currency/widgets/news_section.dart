import 'package:flutter/material.dart';
import 'package:flutter_ders/app/core/base/base_change_notifier_view_model.dart';
import 'package:flutter_ders/app/models/currency/currency_info.dart';
import 'package:flutter_ders/app/models/currency/news_article.dart';
import 'package:flutter_ders/app/theme/app_theme.dart';
import 'package:flutter_ders/app/views/view_currency/view_model/news_view_model.dart';
import 'package:flutter_ders/app/views/view_currency/widgets/news_detail_sheet.dart';
import 'package:flutter_ders/app/views/view_currency/widgets/section_title.dart';
import 'package:flutter_ders/app/widgets/common.dart';
import 'package:provider/provider.dart';

/// DERS 15 — 3. bölüm: finans haberleri. Yalnızca [NewsViewModel]'i dinler.
///
/// Haberler `SliverList.builder` ile çizilir: yalnızca ekranda görünen
/// kartlar oluşturulur (Ders 7).
class NewsSection extends StatelessWidget {
  /// Bölümü oluşturur.
  const NewsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final vm = context.watch<NewsViewModel>();
    final visible = vm.visible;
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CurrencySectionTitle(
                number: 3,
                title: 'Finans haberleri',
                trailing: vm.articles.isEmpty
                    ? null
                    : '${visible.length} haber',
              ),
              Text(
                'Anadolu Ajansı ve TRT Haber ekonomi beslemeleri (RSS). '
                'Habere dokun: ayrıntı alttan açılır.',
                style: t.bodySmall,
              ),
              const Gap(10),
              if (vm.mentioned.isNotEmpty)
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ChoiceChip(
                      key: const Key('news_filter_all'),
                      label: const Text('Hepsi'),
                      selected: vm.filter == null,
                      onSelected: (_) => vm.toggleFilter(null),
                    ),
                    for (final m in vm.mentioned)
                      ChoiceChip(
                        key: Key('news_filter_${m.code}'),
                        label: Text(
                          '${currencyInfo(m.code).flag} ${m.code} (${m.count})',
                        ),
                        selected: vm.filter == m.code,
                        onSelected: (_) => vm.toggleFilter(m.code),
                      ),
                  ],
                ),
              const Gap(10),
              if (vm.failedSources.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    'Okunamayan kaynak: ${vm.failedSources.join(', ')}',
                    style: t.bodySmall?.copyWith(color: MfColors.red600),
                  ),
                ),
              if (vm.isBusy && vm.articles.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (vm.status == ViewStatus.failure)
                CurrencyErrorRow(
                  message: vm.error ?? 'Haberler alınamadı.',
                  onRetry: vm.load,
                ),
            ],
          ),
        ),
        SliverList.builder(
          itemCount: visible.length,
          itemBuilder: (context, i) => _NewsCard(visible[i]),
        ),
      ],
    );
  }
}

class _NewsCard extends StatelessWidget {
  const _NewsCard(this.article);

  final NewsArticle article;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final vm = context.read<NewsViewModel>();
    final read = context.select<NewsViewModel, bool>((m) => m.isRead(article));
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: MfColors.slate200),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: Key('news_${article.id}'),
          onTap: () {
            vm.markRead(article);
            showNewsDetail(context, article);
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                NewsImage(article.imageUrl, width: 76, height: 64),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        article.title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: t.titleSmall?.copyWith(
                          color: read ? MfColors.slate500 : MfColors.slate900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${article.source} · ${newsTime(article.publishedAt)}'
                        '${read ? ' · okundu' : ''}',
                        style: t.bodySmall,
                      ),
                      if (article.currencies.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            for (final c in article.currencies) Eyebrow(c),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
