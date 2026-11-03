import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_ders/app/core/bloc/navigation/navigation_cubit.dart';
import 'package:flutter_ders/app/helper/money_format.dart';
import 'package:flutter_ders/app/models/expense.dart';
import 'package:flutter_ders/app/theme/category_style.dart';
import 'package:flutter_ders/app/views/view_expenses/cubit/expenses_cubit.dart';
import 'package:flutter_ders/app/views/view_expenses/cubit/expenses_state.dart';
import 'package:flutter_ders/app/views/view_expenses/widgets/expense_tile_widget.dart';
import 'package:flutter_ders/app/widgets/common.dart';

// ─────────────────────────────────────────────────────────────────────────
// DERS 2 — Navigation 2.0
//
// Bu ekran yalnızca Navigation 2.0 ile yönetilir:
//   • Açılması: NavigationCubit.openCategory(...) → durum değişir →
//     AppRouterDelegate sayfa listesine bu ekranı ekler.
//   • Kapanması: geri düğmesi Navigator.pop() ÇAĞIRMAZ; durumu
//     NavigationCubit.backToHome() ile değiştirir, sayfa listeden çıkar.
//   • Bu ekranda Navigator.push / pop kullanılmaz (Ders 1 ayrı ekranda).
// ─────────────────────────────────────────────────────────────────────────

/// Seçili kategorinin harcamaları ve toplamları.
class CategoryExpensesView extends StatelessWidget {
  /// [category] için ekranı oluşturur.
  const CategoryExpensesView({required this.category, super.key});

  /// Gösterilen kategori.
  final ExpenseCategory category;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final accent = category.accent;
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          key: const Key('categoryView_back'),
          // Navigation 2.0: pop yerine durumu değiştir.
          onPressed: context.read<NavigationCubit>().backToHome,
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
