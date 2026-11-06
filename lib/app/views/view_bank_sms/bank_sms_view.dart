import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_ders/app/core/di/injection.dart';
import 'package:flutter_ders/app/core/sms/bank_sms.dart';
import 'package:flutter_ders/app/core/sms/sms_source.dart';
import 'package:flutter_ders/app/helper/money_format.dart';
import 'package:flutter_ders/app/models/expense.dart';
import 'package:flutter_ders/app/views/view_bank_sms/cubit/bank_sms_cubit.dart';
import 'package:flutter_ders/app/views/view_bank_sms/widgets/bank_sms_widgets.dart';
import 'package:flutter_ders/app/views/view_expenses/cubit/expenses_cubit.dart';
import 'package:flutter_ders/app/widgets/common.dart';

/// DERS 21 — Platform channel ile banka SMS'leri.
@RoutePage()
class BankSmsView extends StatelessWidget {
  /// Sayfayı oluşturur.
  const BankSmsView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => BankSmsCubit(
        source: getIt<SmsSource>(),
        expenses: context.read<ExpensesCubit>(),
      )..init(),
      child: const _BankSmsBody(),
    );
  }
}

class _BankSmsBody extends StatelessWidget {
  const _BankSmsBody();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text("Banka SMS'leri"),
        titleTextStyle: t.titleLarge,
        actions: [
          BlocBuilder<BankSmsCubit, BankSmsState>(
            buildWhen: (a, b) => a.status != b.status,
            builder: (context, s) => s.status == BankSmsStatus.ready
                ? IconButton(
                    key: const Key('bankSms_refresh'),
                    tooltip: 'Yenile',
                    onPressed: context.read<BankSmsCubit>().refresh,
                    icon: const Icon(Icons.refresh_rounded),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
      body: BlocBuilder<BankSmsCubit, BankSmsState>(
        builder: (context, s) {
          final cubit = context.read<BankSmsCubit>();
          return switch (s.status) {
            BankSmsStatus.checking || BankSmsStatus.loading
                when s.items.isEmpty =>
              const Center(child: CircularProgressIndicator()),
            BankSmsStatus.needsPermission => SmsPermissionCard(
              onAllow: cubit.requestAccess,
            ),
            BankSmsStatus.permanentlyDenied => SmsPermissionCard(
              permanent: true,
              onAllow: cubit.openSettings,
            ),
            BankSmsStatus.unsupported => const SmsMessage(
              icon: Icons.phone_android_rounded,
              text: 'SMS okuma yalnız Android telefonda çalışır.',
            ),
            BankSmsStatus.failed => SmsMessage(
              icon: Icons.error_outline_rounded,
              text: 'Gelen kutusu okunamadı.',
              action: 'Tekrar dene',
              onAction: cubit.refresh,
            ),
            _ => _SmsList(state: s),
          };
        },
      ),
    );
  }
}

class _SmsList extends StatelessWidget {
  const _SmsList({required this.state});

  final BankSmsState state;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cubit = context.read<BankSmsCubit>();
    // Harcama eklenince/silinince "Eklendi" rozeti güncellensin.
    context.watch<ExpensesCubit>();
    final visible = state.visible;
    final now = DateTime.now();
    final rows = <Widget>[];
    DateTime? lastDay;
    for (final sms in visible) {
      final day = DateUtils.dateOnly(sms.date);
      if (day != lastDay) {
        rows
          ..add(const Gap(14))
          ..add(Text(formatDayLabel(day, now: now), style: t.labelLarge))
          ..add(const Gap(6));
        lastDay = day;
      }
      rows.add(
        BankSmsTile(
          sms: sms,
          recorded: cubit.recorded(sms),
          onTap: () => _openDetail(context, sms),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: cubit.refresh,
      child: ListView(
        key: const Key('bankSms_list'),
        padding: pagePadding(context).copyWith(top: 8, bottom: 40),
        children: [
          if (state.status == BankSmsStatus.loading)
            const LinearProgressIndicator(minHeight: 2),
          Text(
            "Yalnız bankaların gönderdiği SMS'ler okunur; diğer mesajlar "
            'Android tarafında elenir. Hiçbir şey kaydedilmez ya da '
            'gönderilmez, ekranı kapatınca liste silinir.',
            style: t.bodyMedium,
          ),
          const Gap(14),
          SmsSummaryCard(state: state, month: DateTime(now.year, now.month)),
          const Gap(14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final f in BankSmsFilter.values)
                ChoiceChip(
                  key: Key('bankSms_filter_${f.name}'),
                  label: Text(f.label),
                  selected: state.filter == f,
                  onSelected: (_) => cubit.setFilter(f),
                ),
            ],
          ),
          if (visible.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: SmsMessage(
                icon: Icons.sms_outlined,
                text: state.items.isEmpty
                    ? "Son ${state.days} günde banka SMS'i bulunamadı."
                    : 'Bu süzgece uyan SMS yok.',
              ),
            ),
          ...rows,
        ],
      ),
    );
  }

  Future<void> _openDetail(BuildContext context, BankSms sms) async {
    final cubit = context.read<BankSmsCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final action = await showModalBottomSheet<SmsSheetAction>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => BankSmsDetailSheet(
        sms: sms,
        recorded: cubit.recorded(sms),
        initial: guessCategory(sms),
      ),
    );
    switch (action) {
      case null:
        return;
      case UndoAction():
        await cubit.undo(sms);
        return;
      case RecordAction(:final category):
        if (!await cubit.record(sms, category)) return;
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(_addedBar(cubit, sms, category));
    }
  }

  SnackBar _addedBar(
    BankSmsCubit cubit,
    BankSms sms,
    ExpenseCategory category,
  ) => SnackBar(
    content: Text(
      '${formatMoney(sms.amount!)} ${category.label} olarak eklendi.',
    ),
    action: SnackBarAction(label: 'Geri al', onPressed: () => cubit.undo(sms)),
  );
}
