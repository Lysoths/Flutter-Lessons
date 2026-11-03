import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_ders/app/core/router/app_deep_links.dart';
import 'package:flutter_ders/app/helper/money_format.dart';
import 'package:flutter_ders/app/theme/category_style.dart';
import 'package:flutter_ders/app/views/view_expenses/cubit/expenses_cubit.dart';
import 'package:flutter_ders/app/views/view_expenses/cubit/expenses_state.dart';
import 'package:flutter_ders/app/views/view_expenses/widgets/expense_tile_widget.dart';
import 'package:flutter_ders/app/widgets/common.dart';

// ─────────────────────────────────────────────────────────────────────────
// DERS 4 — auto_route
//
// Rota: '/kategori/:slug'. @PathParam('slug') yoldaki ':slug' parçasını
// bu parametreye bağlar; hem uygulama içinden
//   context.router.push(CategoryExpensesRoute(slug: 'yemek'))
// hem de harcamatakibim://app/kategori/yemek linkiyle açılır.
// Geri düğmesi context.router.maybePop() ile sayfayı kapatır.
// ─────────────────────────────────────────────────────────────────────────

/// Seçili kategorinin harcamaları ve toplamları.
@RoutePage()
class CategoryExpensesView extends StatelessWidget {
  /// [slug] kategorisi için ekranı oluşturur.
  const CategoryExpensesView({
    @PathParam('slug') required this.slug,
    super.key,
  });

  /// Linkteki kategori adı (ör. `yemek`). Beyaz listeden geçmiştir.
  final String slug;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final category = kCategorySlugs[slug.toLowerCase()];
    if (category == null) {
      // Uygulama içinden yanlış ad gelirse (link zaten süzülür).
      return Scaffold(appBar: AppBar(title: const Text('Kategori bulunamadı')));
    }
    final accent = category.accent;
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          key: const Key('categoryView_back'),
          onPressed: () => context.router.maybePop(),
        ),
        title: Text(category.label),
        titleTextStyle: t.titleLarge,
      ),
      body: BlocBuilder<ExpensesCubit, ExpensesState>(
        builder: (context, state) {
          final now = DateTime.now();
          final items = [
            for (final e in state.expenses)
              if (e.category == category) e,
          ];
          final monthTotal = items
              .where(
                (e) => e.date.year == now.year && e.date.month == now.month,
              )
              .fold<double>(0, (s, e) => s + e.amount);
          final allTotal = items.fold<double>(0, (s, e) => s + e.amount);
          return ListView(
            padding: pagePadding(context).copyWith(top: 8, bottom: 24),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [accent, Color.lerp(accent, Colors.black, 0.25)!],
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(category.icon, color: Colors.white, size: 30),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bu ay · ${formatMonth(now)}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              formatMoney(monthTotal),
                              key: const Key('categoryView_monthTotal'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -1,
                              ),
                            ),
                          ),
                          Text(
                            '${items.length} kayıt · tüm zamanlar '
                            '${formatMoney(allTotal)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(24),
              Text('Harcamalar', style: t.titleLarge),
              const Gap(12),
              if (items.isEmpty)
                Text('Bu kategoride harcama yok.', style: t.bodyMedium)
              else
                for (final e in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ExpenseTileWidget(
                      expense: e,
                      subtitle: formatDayLabel(e.date, now: now),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}
