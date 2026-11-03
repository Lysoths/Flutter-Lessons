import 'package:flutter/material.dart';
import 'package:flutter_ders/app/models/expense.dart';
import 'package:flutter_ders/app/theme/app_theme.dart';
import 'package:flutter_ders/app/theme/category_style.dart';

/// Tüm kategoriler için yatay kısayol çubuğu. Harcama olmasa da her zaman
/// görünür; dokunulan kategori [onSelected] ile bildirilir.
class CategoryShortcutsWidget extends StatelessWidget {
  /// Kısayol çubuğunu oluşturur.
  const CategoryShortcutsWidget({required this.onSelected, super.key});

  /// Bir kategoriye dokunulduğunda çağrılır.
  final ValueChanged<ExpenseCategory> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: ExpenseCategory.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final category = ExpenseCategory.values[i];
          final accent = category.accent;
          final radius = BorderRadius.circular(18);
          return Material(
            color: accent.withValues(alpha: 0.08),
            shape: RoundedRectangleBorder(
              borderRadius: radius,
              side: BorderSide(color: accent.withValues(alpha: 0.25)),
            ),
            child: InkWell(
              key: Key('categoryShortcut_${category.name}'),
              borderRadius: radius,
              onTap: () => onSelected(category),
              child: SizedBox(
                width: 78,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(category.icon, color: Colors.white, size: 22),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      category.label,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: MfColors.slate800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
