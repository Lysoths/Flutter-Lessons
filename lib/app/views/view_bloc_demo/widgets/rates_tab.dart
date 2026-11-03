import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_ders/app/helper/money_format.dart';
import 'package:flutter_ders/app/models/exchange_rates.dart';
import 'package:flutter_ders/app/theme/app_theme.dart';
import 'package:flutter_ders/app/views/view_bloc_demo/bloc/rates_bloc.dart';
import 'package:flutter_ders/app/views/view_bloc_demo/bloc/rates_event.dart';
import 'package:flutter_ders/app/views/view_bloc_demo/bloc/rates_state.dart';
import 'package:flutter_ders/app/views/view_network/widgets/network_cards.dart';
import 'package:flutter_ders/app/widgets/common.dart';

/// DERS 13 — 1. sekme: servis isteği (Frankfurter).
class RatesTab extends StatefulWidget {
  /// Sekmeyi oluşturur.
  const RatesTab({super.key});

  @override
  State<RatesTab> createState() => _RatesTabState();
}

class _RatesTabState extends State<RatesTab> {
  /// "Yenile"ye kaç kez basıldı (Bloc'un kaçını işlediğiyle karşılaştırmak
  /// için).
  int _presses = 0;

  void _refresh() {
    setState(() => _presses++);
    context.read<RatesBloc>().add(const RatesRefreshed());
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    // BlocListener: çizim yapmaz, tek seferlik iş yapar (bildirim göster).
    return BlocListener<RatesBloc, RatesState>(
      listenWhen: (previous, current) => current is RatesError,
      listener: (context, state) => ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text((state as RatesError).message))),
      child: SingleChildScrollView(
        key: const Key('rates_list'),
        padding: pagePadding(context).copyWith(top: 16, bottom: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Avrupa Merkez Bankası kurları, internetten gerçek bir servis '
              'isteğiyle (dio) gelir. Ekran yalnızca OLAY gönderir.',
              style: t.bodyMedium,
            ),
            const Gap(12),
            const CodeBox('''
context.read<RatesBloc>().add(const RatesRefreshed());

BlocBuilder<RatesBloc, RatesState>(
  builder: (context, state) => switch (state) {
    RatesInitial() => ...,
    RatesLoading() => CircularProgressIndicator(),
    RatesLoaded(:final rates) => KurListesi(rates),
    RatesError(:final message) => Text(message),
  },
)'''),
            const Gap(12),
            Row(
              children: [
                FilledButton.icon(
                  key: const Key('rates_refresh'),
                  onPressed: _refresh,
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Yenile'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: BlocBuilder<RatesBloc, RatesState>(
                    builder: (context, state) {
                      final handled = switch (state) {
                        RatesLoaded(:final handled) => handled,
                        RatesError(:final handled) => handled,
                        _ => null,
                      };
                      return Text(
                        'Basılan: $_presses · işlenen istek: ${handled ?? '…'}\n'
                        'İstek sürerken basılanlar yok sayılır (droppable).',
                        key: const Key('rates_counts'),
                        style: t.bodySmall,
                      );
                    },
                  ),
                ),
              ],
            ),
            const Gap(16),
            BlocBuilder<RatesBloc, RatesState>(
              builder: (context, state) => switch (state) {
                RatesInitial() => const Text('Henüz istek gönderilmedi.'),
                RatesLoading(:final previous) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const LinearProgressIndicator(key: Key('rates_loading')),
                    if (previous != null) ...[
                      const Gap(10),
                      Opacity(opacity: 0.4, child: _RatesList(previous)),
                    ],
                  ],
                ),
                RatesLoaded(:final rates, :final fetchedAt) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'ECB · ${formatDate(rates.date)} tarihli · alındı '
                      '${fetchedAt.hour.toString().padLeft(2, '0')}:'
                      '${fetchedAt.minute.toString().padLeft(2, '0')}:'
                      '${fetchedAt.second.toString().padLeft(2, '0')}',
                      style: t.bodySmall,
                    ),
                    const Gap(8),
                    _RatesList(rates),
                  ],
                ),
                RatesError(:final message, :final previous) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      key: const Key('rates_error'),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.cloud_off_rounded,
                            color: MfColors.red600,
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Text(message, style: t.titleSmall)),
                          TextButton(
                            onPressed: _refresh,
                            child: const Text('Tekrar dene'),
                          ),
                        ],
                      ),
                    ),
                    if (previous != null) ...[
                      const Gap(10),
                      Opacity(opacity: 0.4, child: _RatesList(previous)),
                    ],
                  ],
                ),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _RatesList extends StatelessWidget {
  const _RatesList(this.rates);

  final ExchangeRates rates;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      children: [
        for (final e in kCurrencies.entries)
          if (rates.tryPerUnit[e.key] case final value?)
            Container(
              key: Key('rate_${e.key}'),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: MfColors.slate200),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: MfColors.blue50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      e.key,
                      style: t.labelMedium?.copyWith(color: MfColors.blue700),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(e.value, style: t.bodyMedium)),
                  Text(
                    '1 ${e.key} = ${formatMoney(value)}',
                    style: t.titleSmall?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}
