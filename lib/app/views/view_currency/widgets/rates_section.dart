import 'package:flutter/material.dart';
import 'package:flutter_ders/app/core/base/base_change_notifier_view_model.dart';
import 'package:flutter_ders/app/helper/money_format.dart';
import 'package:flutter_ders/app/models/currency/currency_info.dart';
import 'package:flutter_ders/app/models/currency/currency_quote.dart';
import 'package:flutter_ders/app/theme/app_theme.dart';
import 'package:flutter_ders/app/views/view_currency/view_model/currency_view_model.dart';
import 'package:flutter_ders/app/views/view_currency/view_model/rates_view_model.dart';
import 'package:flutter_ders/app/views/view_currency/widgets/section_title.dart';
import 'package:provider/provider.dart';

/// DERS 15 — 1. bölüm: 10 para birimi. Yalnızca [RatesViewModel]'i dinler.
class RatesSection extends StatelessWidget {
  /// Bölümü oluşturur.
  const RatesSection({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<RatesViewModel>();
    final date = vm.date;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CurrencySectionTitle(
          number: 1,
          title: 'Takip edilen 10 para birimi',
          trailing: date == null ? null : formatDate(date),
        ),
        if (vm.isBusy && vm.quotes.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (vm.status == ViewStatus.failure)
          CurrencyErrorRow(
            message: vm.error ?? 'Kurlar alınamadı.',
            onRetry: context.read<CurrencyViewModel>().refreshAll,
          ),
        if (vm.quotes.isNotEmpty)
          Container(
            key: const Key('currency_rates'),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: MfColors.slate200),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final (i, q) in vm.quotes.indexed) ...[
                  if (i > 0) const Divider(height: 1, color: MfColors.slate100),
                  _QuoteRow(q, selected: q.info.code == vm.selected),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _QuoteRow extends StatelessWidget {
  const _QuoteRow(this.quote, {required this.selected});

  final CurrencyQuote quote;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final change = quote.changePercent;
    return Material(
      color: selected ? MfColors.blue50 : Colors.transparent,
      child: InkWell(
        key: Key('quote_${quote.info.code}'),
        // View karar vermez; olayı üst ViewModel'e bildirir.
        onTap: () =>
            context.read<CurrencyViewModel>().selectCurrency(quote.info.code),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Text(quote.info.flag, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      quote.info.code,
                      style: t.titleSmall?.copyWith(
                        color: selected ? MfColors.blue700 : null,
                      ),
                    ),
                    Text(quote.info.name, style: t.bodySmall),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatTryRate(quote.tryPerUnit),
                    style: t.titleSmall?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text(
                    quote.previous == null ? '—' : formatChange(change),
                    style: t.bodySmall?.copyWith(
                      color: changeColor(change),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                color: selected ? MfColors.blue600 : MfColors.slate200,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
