import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ders/app/helper/money_format.dart';
import 'package:flutter_ders/app/models/expense.dart';
import 'package:flutter_ders/app/theme/app_theme.dart';
import 'package:flutter_ders/app/theme/category_style.dart';
import 'package:flutter_ders/app/views/view_expenses/widgets/expense_form_sheet.dart';
import 'package:flutter_ders/app/widgets/common.dart';

// ─────────────────────────────────────────────────────────────────────────
// DERS 4 — auto_route
//
// Bu ekran listeden şöyle açılır (bkz. expenses_view.dart → _openDetail):
//
//   final result = await context.router.push<ExpenseDetailResult>(
//     ExpenseDetailRoute(expense: expense),
//   );
//
// ExpenseDetailRoute, @RoutePage() sayesinde üretilen tipli rota sınıfıdır.
// Harcama NESNE olarak gider; yolda ID yoktur ve dışarıdan gelen bir link
// bu ekrana ulaşamaz. Kapanırken context.router.maybePop(sonuç) ile tipli
// sonucu açan yere döndürür.
// ─────────────────────────────────────────────────────────────────────────

/// Detay ekranının kapanırken döndürdüğü sonuç.
sealed class ExpenseDetailResult {
  const ExpenseDetailResult();
}

/// Harcama düzenlendi; [expense] yeni halidir.
final class ExpenseDetailEdited extends ExpenseDetailResult {
  /// Düzenleme sonucu.
  const ExpenseDetailEdited(this.expense);

  /// Harcamanın düzenlenmiş hali.
  final Expense expense;
}

/// Harcama silinmek istendi.
final class ExpenseDetailDeleted extends ExpenseDetailResult {
  /// Silme sonucu.
  const ExpenseDetailDeleted();
}

/// Tek bir harcamanın ayrıntıları; düzenleme ve silme buradan yapılır.
@RoutePage()
class ExpenseDetailView extends StatelessWidget {
  /// [expense] için detay ekranı oluşturur.
  const ExpenseDetailView({required this.expense, super.key});

  /// Gösterilen harcama.
  final Expense expense;

  /// Düzenleme formunu bu ekranın üstünde açar. Kaydedilirse detay ekranı
  /// kapanır ve sonucu listeye bırakır.
  Future<void> _edit(BuildContext context) async {
    final router = context.router;
    final result = await showModalBottomSheet<ExpenseFormResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ExpenseFormSheet(initial: expense),
    );
    switch (result) {
      case ExpenseFormSaved(:final amount, :final category, :final date):
        await router.maybePop(
          ExpenseDetailEdited(
            expense.copyWith(
              amount: amount,
              category: category,
              date: date,
              note: result.note,
            ),
          ),
        );
      case ExpenseFormDeleted():
        await router.maybePop(const ExpenseDetailDeleted());
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final accent = expense.category.accent;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Harcama ayrıntısı'),
        titleTextStyle: t.titleLarge,
      ),
      body: ListView(
        padding: pagePadding(context).copyWith(top: 8, bottom: 24),
        children: [
          // Başlık kartı: kategori rengiyle büyük tutar.
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                IconBadge(expense.category.icon, accent: accent, size: 60),
                const Gap(14),
                Text(
                  formatMoney(expense.amount),
                  key: const Key('expenseDetail_amount'),
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                    color: MfColors.slate900,
                  ),
                ),
                const Gap(6),
                Eyebrow(
                  expense.category.label,
                  color: accent,
                  background: Colors.white,
                ),
              ],
            ),
          ),
          const Gap(20),
          Card(
            child: Column(
              children: [
                _InfoRow(
                  icon: Icons.calendar_today_rounded,
                  label: 'Tarih',
                  value:
                      '${formatDayLabel(expense.date)} · '
                      '${expense.date.hour.toString().padLeft(2, '0')}:'
                      '${expense.date.minute.toString().padLeft(2, '0')}',
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                _InfoRow(
                  icon: Icons.category_rounded,
                  label: 'Kategori',
                  value: expense.category.label,
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                _InfoRow(
                  icon: Icons.edit_note_rounded,
                  label: 'Not',
                  value: expense.note.isEmpty ? '—' : expense.note,
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: pagePadding(context).copyWith(bottom: 16),
        child: Row(
          children: [
            SizedBox(
              width: 56,
              child: OutlinedButton(
                key: const Key('expenseDetail_delete'),
                // Ekranı kapat ve "silindi" sonucunu döndür.
                onPressed: () =>
                    context.router.maybePop(const ExpenseDetailDeleted()),
                style: OutlinedButton.styleFrom(
                  foregroundColor: MfColors.red600,
                  padding: EdgeInsets.zero,
                  side: BorderSide(
                    color: MfColors.red600.withValues(alpha: 0.3),
                  ),
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  semanticLabel: 'Sil',
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                key: const Key('expenseDetail_edit'),
                onPressed: () => _edit(context),
                icon: const Icon(Icons.edit_rounded, size: 18),
                label: const Text('Düzenle'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 20, color: MfColors.slate500),
          const SizedBox(width: 12),
          Text(label, style: t.bodyMedium),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: t.titleMedium,
            ),
          ),
        ],
      ),
    );
  }
}
