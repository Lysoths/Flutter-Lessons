import 'package:flutter/material.dart';
import 'package:flutter_ders/app/helper/money_format.dart';
import 'package:flutter_ders/app/models/expense.dart';
import 'package:flutter_ders/app/theme/app_theme.dart';
import 'package:flutter_ders/app/theme/category_style.dart';
import 'package:flutter_ders/app/widgets/common.dart';

/// Listede tek bir harcama kartı. [onTap] verilirse dokunulabilir,
/// [onDelete] verilirse sola kaydırınca silinir; ikisi de yoksa yalnızca
/// bilgi gösterir.
class ExpenseTileWidget extends StatelessWidget {
  /// [expense] için bir kart oluşturur.
  const ExpenseTileWidget({
    required this.expense,
    this.onTap,
    this.onDelete,
    this.subtitle,
    super.key,
  });

  /// Gösterilen harcama.
  final Expense expense;

  /// Karta dokunulduğunda çağrılır.
  final VoidCallback? onTap;

  /// Kart kaydırılarak silindiğinde çağrılır.
  final VoidCallback? onDelete;

  /// Alt satır; verilmezse kategori adı yazılır.
  final String? subtitle;

  static final _radius = BorderRadius.circular(16);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final accent = expense.category.accent;
    final card = _card(t, accent);
    if (onDelete == null) return card;
    return Dismissible(
      key: ValueKey('dismiss_${expense.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: MfColors.red600.withValues(alpha: 0.1),
          borderRadius: _radius,
        ),
        child: const Icon(Icons.delete_outline, color: MfColors.red600),
      ),
      onDismissed: (_) => onDelete!(),
      child: card,
    );
  }

  Widget _card(TextTheme t, Color accent) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: _radius,
        side: const BorderSide(color: MfColors.slate200),
      ),
      child: InkWell(
        key: Key('expenseTile_${expense.id}'),
        borderRadius: _radius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
          child: Row(
            children: [
              IconBadge(expense.category.icon, accent: accent, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      expense.note.isEmpty
                          ? expense.category.label
                          : expense.note,
                      style: t.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle ?? expense.category.label,
                      style: TextStyle(
                        color: accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                formatMoney(expense.amount),
                style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              if (onTap != null)
                const Icon(
                  Icons.chevron_right_rounded,
                  color: MfColors.slate400,
                )
              else
                const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}
