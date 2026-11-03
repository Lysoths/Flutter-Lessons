import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_ders/app/core/bloc/navigation/navigation_cubit.dart';
import 'package:flutter_ders/app/core/bloc/navigation/navigation_state.dart';
import 'package:flutter_ders/app/helper/money_format.dart';
import 'package:flutter_ders/app/models/expense.dart';
import 'package:flutter_ders/app/theme/app_theme.dart';
import 'package:flutter_ders/app/views/view_expense_detail/expense_detail_view.dart';
import 'package:flutter_ders/app/views/view_expenses/cubit/expenses_cubit.dart';
import 'package:flutter_ders/app/views/view_expenses/cubit/expenses_state.dart';
import 'package:flutter_ders/app/views/view_expenses/widgets/category_breakdown_widget.dart';
import 'package:flutter_ders/app/views/view_expenses/widgets/category_shortcuts_widget.dart';
import 'package:flutter_ders/app/views/view_expenses/widgets/expense_form_sheet.dart';
import 'package:flutter_ders/app/views/view_expenses/widgets/expense_tile_widget.dart';
import 'package:flutter_ders/app/views/view_expenses/widgets/month_summary_card.dart';
import 'package:flutter_ders/app/widgets/common.dart';

/// Ana ekran: aylık özet, kategori dağılımı ve güne göre gruplu liste.
/// [ExpensesCubit] uygulama seviyesinde sağlanır (bkz. `app.dart`).
class ExpensesView extends StatelessWidget {
  /// Ekranı oluşturur.
  const ExpensesView({super.key});

  /// Yeni harcama formunu açar.
  Future<void> _openNewForm(BuildContext context) async {
    final cubit = context.read<ExpensesCubit>();
    final result = await showModalBottomSheet<ExpenseFormResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const ExpenseFormSheet(),
    );
    if (result case ExpenseFormSaved(
      :final amount,
      :final category,
      :final date,
      :final note,
    )) {
      await cubit.add(
        amount: amount,
        category: category,
        date: date,
        note: note,
      );
    }
  }

  /// DERS 1 — Navigation 1.0: detay ekranını yığının üstüne koyar (push)
  /// ve ekran kapanınca (pop) döndürdüğü sonuca göre listeyi günceller.
  ///
  /// Detay ekranı bu ekranın altında değil yanında (aynı Navigator'da)
  /// durduğu için cubit'e erişemez; veri constructor ile gider, sonuç
  /// pop ile geri gelir.
  Future<void> _openDetail(BuildContext context, Expense expense) async {
    final cubit = context.read<ExpensesCubit>();
    final result = await Navigator.of(context).push<ExpenseDetailResult>(
      MaterialPageRoute(builder: (_) => ExpenseDetailView(expense: expense)),
    );
    if (!context.mounted) return;
    switch (result) {
      case ExpenseDetailEdited(:final expense):
        await cubit.edit(expense);
      case ExpenseDetailDeleted():
        await _delete(context, expense.id);
      case null:
        break; // Geri tuşuyla kapatıldı; değişiklik yok.
    }
  }

  /// Siler ve "Geri al" seçeneği gösterir.
  Future<void> _delete(BuildContext context, String id) async {
    final cubit = context.read<ExpensesCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final removed = await cubit.remove(id);
    if (removed == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${removed.category.label} harcaması silindi'),
          action: SnackBarAction(
            label: 'Geri al',
            onPressed: () => cubit.restore(removed),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return _NewExpenseRequestListener(
      onRequest: () => _openNewForm(context),
      child: _buildScaffold(context),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    return Scaffold(
      appBar: AppBar(titleSpacing: 20, title: const _BrandTitle()),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('expensesView_add'),
        onPressed: () => _openNewForm(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Harcama ekle',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: BlocBuilder<ExpensesCubit, ExpensesState>(
        builder: (context, state) {
          if (state.status == ExpensesStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          final now = DateTime.now();
          final monthItems = state.inMonth(now);
          final categories = state.categoryTotals(now);
          return ListView(
            padding: pagePadding(context).copyWith(
              top: 8,
              bottom: MediaQuery.paddingOf(context).bottom + 96,
            ),
            children: [
              MonthSummaryCard(
                month: now,
                monthTotal: state.totalInMonth(now),
                monthCount: monthItems.length,
                allTimeTotal: state.total,
              ),
              const Gap(24),
              const _SectionTitle(
                'Kategori sayfaları',
                subtitle: 'Bir kategorinin tüm harcamalarını görün',
              ),
              const Gap(12),
              // DERS 2 — Navigation 2.0: dokunmak yalnızca durumu değiştirir.
              CategoryShortcutsWidget(
                onSelected: context.read<NavigationCubit>().openCategory,
              ),
              if (categories.isNotEmpty) ...[
                const Gap(28),
                const _SectionTitle(
                  'Kategoriler',
                  subtitle: 'Bu ay · ayrıntı için kategoriye dokunun',
                ),
                const Gap(12),
                CategoryBreakdownWidget(
                  totals: categories,
                  // DERS 2 — Navigation 2.0: ekran açılmaz, yalnızca durum
                  // değişir; RouterDelegate kategori sayfasını ekler.
                  onCategoryTap: context.read<NavigationCubit>().openCategory,
                ),
              ],
              const Gap(28),
              const _SectionTitle(
                'Harcamalar',
                subtitle: 'Ayrıntı için dokunun, silmek için kaydırın',
              ),
              const Gap(4),
              if (state.expenses.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: _EmptyCard(),
                )
              else
                ..._groupedTiles(context, state.expenses, now),
            ],
          );
        },
      ),
    );
  }

  /// Harcamaları gün başlıklarıyla gruplar.
  List<Widget> _groupedTiles(
    BuildContext context,
    List<Expense> expenses,
    DateTime now,
  ) {
    final widgets = <Widget>[];
    String? lastLabel;
    for (final expense in expenses) {
      final label = formatDayLabel(expense.date, now: now);
      if (label != lastLabel) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 8),
            child: Text(
              label.toUpperCase(),
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
        );
        lastLabel = label;
      }
      widgets.add(
        Padding(
          key: ValueKey(expense.id),
          padding: const EdgeInsets.only(bottom: 8),
          child: ExpenseTileWidget(
            expense: expense,
            onTap: () => _openDetail(context, expense),
            onDelete: () => _delete(context, expense.id),
          ),
        ),
      );
    }
    return widgets;
  }
}

/// DERS 3 — Deep link: `/yeni` linki gelince formu açar.
///
/// Link uygulama kapalıyken geldiyse durum bu ekran kurulmadan önce
/// ayarlanmış olur; bu yüzden hem ilk karede hem sonraki değişikliklerde
/// kontrol edilir. Form yalnızca açılır, kaydı kullanıcı yapar. Üstte zaten
/// bir form ya da detay ekranı açıksa link yok sayılır.
class _NewExpenseRequestListener extends StatefulWidget {
  const _NewExpenseRequestListener({
    required this.onRequest,
    required this.child,
  });

  final Future<void> Function() onRequest;
  final Widget child;

  @override
  State<_NewExpenseRequestListener> createState() =>
      _NewExpenseRequestListenerState();
}

class _NewExpenseRequestListenerState
    extends State<_NewExpenseRequestListener> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  void _check() {
    if (!mounted) return;
    final navigation = context.read<NavigationCubit>();
    if (!navigation.state.newExpenseRequested) return;
    navigation.newExpenseHandled();
    // Ana sayfanın üstünde zaten bir şey açıksa (form ya da detay ekranı)
    // ikinci bir form açma; kullanıcının yazdıkları kaybolmasın.
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
    unawaited(widget.onRequest());
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<NavigationCubit, NavigationState>(
      listenWhen: (previous, current) => current.newExpenseRequested,
      // Bir sonraki karede aç: önce RouterDelegate kategori sayfasını
      // kaldırsın. Aksi halde form o sayfanın üstüne açılır ve sayfayla
      // birlikte kapanır.
      listener: (_, _) =>
          WidgetsBinding.instance.addPostFrameCallback((_) => _check()),
      child: widget.child,
    );
  }
}

/// Bölüm başlığı: kalın başlık ve sağda/altta küçük açıklama.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: t.titleLarge),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(subtitle!, style: t.bodyMedium?.copyWith(fontSize: 13)),
        ],
      ],
    );
  }
}

/// Uygulama başlığı (duo'daki logo + alt yazı düzeni).
class _BrandTitle extends StatelessWidget {
  const _BrandTitle();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: const LinearGradient(
              colors: [MfColors.slate900, MfColors.blue700],
            ),
          ),
          child: const Icon(
            Icons.account_balance_wallet_rounded,
            color: Colors.white,
            size: 20,
          ),
        ),
        const SizedBox(width: 10),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Harcama Takibim',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: MfColors.slate900,
              ),
            ),
            Text(
              'Kişisel bütçe defteri',
              style: TextStyle(fontSize: 11, color: MfColors.slate500),
            ),
          ],
        ),
      ],
    );
  }
}

/// Liste boşken gösterilen kart.
class _EmptyCard extends StatelessWidget {
  const _EmptyCard();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const IconBadge(Icons.receipt_long_rounded, size: 52),
            const Gap(12),
            Text('Henüz harcama yok', style: t.titleMedium),
            const Gap(4),
            Text(
              'İlk harcamanızı "Harcama ekle" ile girin.',
              style: t.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
