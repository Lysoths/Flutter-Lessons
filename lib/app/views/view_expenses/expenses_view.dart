import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_ders/app/core/analytics/app_events.dart';
import 'package:flutter_ders/app/core/router/app_deep_links.dart';
import 'package:flutter_ders/app/core/router/app_router.dart';
import 'package:flutter_ders/app/helper/money_format.dart';
import 'package:flutter_ders/app/models/expense.dart';
import 'package:flutter_ders/app/theme/app_theme.dart';
import 'package:flutter_ders/app/views/view_expense_detail/expense_detail_view.dart';
import 'package:flutter_ders/app/views/view_expenses/cubit/expenses_cubit.dart';
import 'package:flutter_ders/app/views/view_expenses/cubit/expenses_state.dart';
import 'package:flutter_ders/app/views/view_expenses/widgets/category_breakdown_widget.dart';
import 'package:flutter_ders/app/views/view_expenses/widgets/category_shortcuts_widget.dart';
import 'package:flutter_ders/app/views/view_expenses/widgets/expense_tile_widget.dart';
import 'package:flutter_ders/app/views/view_expenses/widgets/month_summary_card.dart';
import 'package:flutter_ders/app/views/view_lessons/widgets/lessons_entry_card.dart';
import 'package:flutter_ders/app/widgets/common.dart';

/// Ana ekran: aylık özet, kategori dağılımı ve güne göre gruplu liste.
/// [ExpensesCubit] uygulama seviyesinde sağlanır (bkz. `app.dart`).
///
/// DERS 4 — auto_route: @RoutePage() bu sayfa için `ExpensesRoute`
/// sınıfının üretilmesini sağlar.
@RoutePage()
class ExpensesView extends StatelessWidget {
  /// Ekranı oluşturur.
  const ExpensesView({super.key});

  /// DERS 4 — auto_route: tipli rota nesnesiyle sayfa açılır (yol yazısı
  /// yok). Sonuç, Navigator.push'taki gibi `await` ile beklenir.
  Future<void> _openDetail(BuildContext context, Expense expense) async {
    final cubit = context.read<ExpensesCubit>();
    final result = await context.router.push<ExpenseDetailResult>(
      ExpenseDetailRoute(expense: expense),
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

  /// DERS 4 — auto_route: kategori sayfası `/kategori/:slug` rotası.
  void _openCategory(BuildContext context, ExpenseCategory category) {
    track(AppEvent.categoryOpened, category.name);
    context.router.push(CategoryExpensesRoute(slug: category.slug));
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
            onPressed: () {
              track(AppEvent.expenseRestored);
              cubit.restore(removed);
            },
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: const _BrandTitle(),
        actions: [
          IconButton(
            key: const Key('expensesView_lessonsAction'),
            tooltip: 'Dersler',
            onPressed: () => context.router.push(const LessonsRoute()),
            icon: const Icon(Icons.school_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('expensesView_add'),
        // DERS 4 — auto_route: form da bir rota (deep link: /yeni).
        onPressed: () => context.router.push(const NewExpenseRoute()),
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
              CategoryShortcutsWidget(
                onSelected: (c) => _openCategory(context, c),
              ),
              const Gap(16),
              // Ders ekranları ayrı bir dizinde (LessonsView).
              const LessonsEntryCard(key: Key('expensesView_lessons')),
              if (categories.isNotEmpty) ...[
                const Gap(28),
                const _SectionTitle(
                  'Kategoriler',
                  subtitle: 'Bu ay · ayrıntı için kategoriye dokunun',
                ),
                const Gap(12),
                CategoryBreakdownWidget(
                  totals: categories,
                  onCategoryTap: (c) => _openCategory(context, c),
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
        const Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Harcama Takibim',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: MfColors.slate900,
                ),
              ),
              Text(
                'Kişisel bütçe defteri',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: MfColors.slate500),
              ),
            ],
          ),
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
