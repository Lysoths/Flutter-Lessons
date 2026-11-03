import 'package:flutter/material.dart';
import 'package:flutter_ders/app/helper/money_format.dart';
import 'package:flutter_ders/app/models/expense.dart';
import 'package:flutter_ders/app/theme/app_theme.dart';
import 'package:flutter_ders/app/theme/category_style.dart';
import 'package:flutter_ders/app/widgets/common.dart';

/// Kategori dağılımı: renkli yığılmış çubuk ve altında kategori satırları.
class CategoryBreakdownWidget extends StatelessWidget {
  /// [totals] için bir dağılım kartı oluşturur.
  const CategoryBreakdownWidget({
    required this.totals,
    this.onCategoryTap,
    super.key,
  });

  /// Kategori başına toplamlar, büyükten küçüğe.
  final List<({ExpenseCategory category, double amount})> totals;

  /// Bir kategori satırına dokunulduğunda çağrılır.
  final ValueChanged<ExpenseCategory>? onCategoryTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final sum = totals.fold<double>(0, (s, e) => s + e.amount);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: SizedBox(
                height: 12,
                child: Row(
                  children: [
                    for (final item in totals)
                      Expanded(
                        flex: (item.amount / sum * 1000).round().clamp(1, 1000),
                        child: Container(color: item.category.accent),
                      ),
                  ],
                ),
              ),
            ),
            const Gap(14),
            for (final item in totals)
              InkWell(
                key: Key('categoryBreakdown_${item.category.name}'),
                borderRadius: BorderRadius.circular(12),
                onTap: onCategoryTap == null
                    ? null
                    : () => onCategoryTap!(item.category),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      IconBadge(
                        item.category.icon,
                        accent: item.category.accent,
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(item.category.label, style: t.titleMedium),
                      ),
                      Text(
                        '%${(item.amount / sum * 100).round()}',
                        style: const TextStyle(
                          color: MfColors.slate500,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 104,
                        child: Text(
                          formatMoney(item.amount),
                          textAlign: TextAlign.right,
                          style: t.titleMedium,
                        ),
                      ),
                      if (onCategoryTap != null)
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: MfColors.slate400,
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
