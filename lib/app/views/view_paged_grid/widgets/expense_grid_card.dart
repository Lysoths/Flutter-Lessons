import 'package:flutter/material.dart';
import 'package:flutter_ders/app/helper/money_format.dart';
import 'package:flutter_ders/app/models/expense.dart';
import 'package:flutter_ders/app/theme/app_theme.dart';
import 'package:flutter_ders/app/theme/category_style.dart';
import 'package:flutter_ders/app/widgets/common.dart';

/// Izgaradaki tek bir harcama kartı.
class ExpenseGridCard extends StatelessWidget {
  /// [number]. sıradaki [expense] için kart oluşturur.
  const ExpenseGridCard({
    required this.expense,
    required this.number,
    super.key,
  });

  /// Gösterilen harcama.
  final Expense expense;

  /// Listedeki sıra (1'den başlar).
  final int number;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final accent = expense.category.accent;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MfColors.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBadge(expense.category.icon, accent: accent, size: 36),
              const Spacer(),
              Text(
                '#$number',
                key: Key('gridCard_$number'),
                style: t.labelMedium,
              ),
            ],
          ),
          const Spacer(),
          Text(
            expense.note.isEmpty ? expense.category.label : expense.note,
            style: t.titleMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            formatDate(expense.date),
            style: TextStyle(
              color: accent,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatMoney(expense.amount),
              style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
