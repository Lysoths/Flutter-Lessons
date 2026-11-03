import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_ders/app/helper/money_format.dart';
import 'package:flutter_ders/app/models/expense.dart';
import 'package:flutter_ders/app/models/saving_tip.dart';
import 'package:flutter_ders/app/theme/app_theme.dart';
import 'package:flutter_ders/app/theme/category_style.dart';
import 'package:flutter_ders/app/views/view_bloc_demo/bloc/tips_bloc.dart';
import 'package:flutter_ders/app/views/view_bloc_demo/bloc/tips_event.dart';
import 'package:flutter_ders/app/views/view_bloc_demo/bloc/tips_state.dart';
import 'package:flutter_ders/app/views/view_network/widgets/network_cards.dart';
import 'package:flutter_ders/app/widgets/common.dart';

/// DERS 13 — 3. sekme: cihazın içinden (asset) veri.
class TipsTab extends StatelessWidget {
  /// Sekmeyi oluşturur.
  const TipsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final bloc = context.read<TipsBloc>();
    return SingleChildScrollView(
      padding: pagePadding(context).copyWith(top: 16, bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'İpuçları internetten değil, uygulamanın içindeki '
            'assets/data/tasarruf_ipuclari.json dosyasından gelir.',
            style: t.bodyMedium,
          ),
          const Gap(12),
          const CodeBox('''
on<TipsSearched>(_ara, transformer: restartable());
// yazarken: TipsSearched('k'), TipsSearched('ka'), TipsSearched('kah')
// yalnızca SON yazılan uygulanır (300 ms bekleme + iptal)'''),
          const Gap(14),
          TextField(
            key: const Key('tips_search'),
            decoration: const InputDecoration(
              hintText: 'İpucu ara (ör. kahve, fatura)',
              prefixIcon: Icon(Icons.search_rounded),
              isDense: true,
            ),
            onChanged: (q) => bloc.add(TipsSearched(q)),
          ),
          const Gap(10),
          // Yalnızca kategori değişince çizilir.
          BlocSelector<TipsBloc, TipsState, ExpenseCategory?>(
            selector: (state) => state.category,
            builder: (context, selected) => Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ChoiceChip(
                  key: const Key('tips_category_all'),
                  label: const Text('Hepsi'),
                  selected: selected == null,
                  onSelected: (_) => bloc.add(const TipsCategorySelected(null)),
                ),
                for (final c in ExpenseCategory.values)
                  ChoiceChip(
                    key: Key('tips_category_${c.name}'),
                    label: Text(c.label),
                    selected: selected == c,
                    onSelected: (_) => bloc.add(TipsCategorySelected(c)),
                  ),
              ],
            ),
          ),
          const Gap(14),
          BlocBuilder<TipsBloc, TipsState>(
            builder: (context, state) => switch (state.status) {
              TipsStatus.loading => const Center(
                child: CircularProgressIndicator(),
              ),
              TipsStatus.failure => Text('İpuçları okunamadı: ${state.error}'),
              TipsStatus.ready => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${state.visible.length} / ${state.all.length} ipucu · '
                    'aylık ~${formatMoney(state.visibleSaving)} tasarruf',
                    key: const Key('tips_summary'),
                    style: t.titleSmall,
                  ),
                  const Gap(10),
                  if (state.visible.isEmpty)
                    Text('Aramaya uyan ipucu yok.', style: t.bodyMedium),
                  for (final tip in state.visible) _TipCard(tip),
                ],
              ),
            },
          ),
        ],
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  const _TipCard(this.tip);

  final SavingTip tip;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final accent = tip.category.accent;
    return Container(
      key: Key('tip_${tip.id}'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MfColors.slate200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBadge(tip.category.icon, accent: accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tip.title, style: t.titleSmall),
                const SizedBox(height: 2),
                Text(tip.body, style: t.bodySmall),
                const SizedBox(height: 6),
                Text(
                  'Aylık ~${formatMoney(tip.monthlySaving)}',
                  style: TextStyle(
                    color: accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
