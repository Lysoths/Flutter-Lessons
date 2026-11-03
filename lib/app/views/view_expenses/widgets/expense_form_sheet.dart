import 'package:flutter/material.dart';
import 'package:flutter_ders/app/helper/money_format.dart';
import 'package:flutter_ders/app/models/expense.dart';
import 'package:flutter_ders/app/theme/app_theme.dart';
import 'package:flutter_ders/app/theme/category_style.dart';
import 'package:flutter_ders/app/widgets/common.dart';

/// Formun kapanırken döndürdüğü sonuç.
sealed class ExpenseFormResult {
  const ExpenseFormResult();
}

/// "Kaydet"e basıldı.
final class ExpenseFormSaved extends ExpenseFormResult {
  /// Formdaki değerlerle bir sonuç oluşturur.
  const ExpenseFormSaved({
    required this.amount,
    required this.category,
    required this.date,
    required this.note,
  });

  /// Tutar.
  final double amount;

  /// Kategori.
  final ExpenseCategory category;

  /// Tarih.
  final DateTime date;

  /// Not.
  final String note;
}

/// "Sil"e basıldı (yalnızca düzenlemede).
final class ExpenseFormDeleted extends ExpenseFormResult {
  /// Silme sonucu.
  const ExpenseFormDeleted();
}

/// Alttan açılan harcama formu. [initial] verilirse düzenleme modunda açılır.
class ExpenseFormSheet extends StatefulWidget {
  /// Formu oluşturur.
  const ExpenseFormSheet({this.initial, this.onSaved, super.key});

  /// Düzenlenen harcama; yeni kayıtta `null`.
  final Expense? initial;

  /// Verilirse "Kaydet"te çağrılır ve form sonuçsuz kapanır; verilmezse
  /// sonuç `pop` ile açan yere döndürülür.
  final ValueChanged<ExpenseFormSaved>? onSaved;

  @override
  State<ExpenseFormSheet> createState() => _ExpenseFormSheetState();
}

class _ExpenseFormSheetState extends State<ExpenseFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountFocus = FocusNode();
  late final _amount = TextEditingController(
    text: widget.initial == null ? '' : editableMoney(widget.initial!.amount),
  );
  late final _note = TextEditingController(text: widget.initial?.note);
  late ExpenseCategory _category =
      widget.initial?.category ?? ExpenseCategory.food;
  late DateTime _date = widget.initial?.date ?? DateTime.now();
  Animation<double>? _routeAnimation;

  bool get _isEditing => widget.initial != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isEditing || _routeAnimation != null) return;
    // Klavyeyi modal açılma animasyonu bitince aç. İkisi aynı anda
    // oynarsa her karede yerleşim yeniden hesaplanır ve açılış takılır.
    final animation = ModalRoute.of(context)?.animation;
    if (animation == null || animation.isCompleted) {
      _amountFocus.requestFocus();
      return;
    }
    _routeAnimation = animation..addStatusListener(_onRouteAnimation);
  }

  void _onRouteAnimation(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _routeAnimation?.removeStatusListener(_onRouteAnimation);
    if (mounted) _amountFocus.requestFocus();
  }

  @override
  void dispose() {
    _routeAnimation?.removeStatusListener(_onRouteAnimation);
    _amountFocus.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    // Saat bilgisini koru, yalnızca günü değiştir.
    setState(
      () => _date = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _date.hour,
        _date.minute,
      ),
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final saved = ExpenseFormSaved(
      amount: parseMoney(_amount.text)!,
      category: _category,
      date: _date,
      note: _note.text.trim(),
    );
    final onSaved = widget.onSaved;
    if (onSaved == null) {
      Navigator.of(context).pop(saved);
    } else {
      onSaved(saved);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final accent = _category.accent;
    return SingleChildScrollView(
      padding: pagePadding(context)
          .copyWith(bottom: 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isEditing ? 'Harcamayı düzenle' : 'Yeni harcama',
              textAlign: TextAlign.center,
              style: t.titleLarge,
            ),
            const Gap(16),
            // Büyük tutar alanı: seçili kategorinin rengini alır.
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Text(
                    'Tutar',
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  TextFormField(
                    key: const Key('expenseForm_amount'),
                    controller: _amount,
                    focusNode: _amountFocus,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                      color: MfColors.slate900,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      hintText: '0,00',
                      hintStyle: TextStyle(color: MfColors.slate400),
                      suffixText: '₺',
                      suffixStyle: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: MfColors.slate500,
                      ),
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                    ),
                    validator: (v) => parseMoney(v ?? '') == null
                        ? 'Geçerli bir tutar girin'
                        : null,
                  ),
                ],
              ),
            ),
            const Gap(20),
            Text('Kategori', style: t.labelMedium),
            const Gap(10),
            LayoutBuilder(
              builder: (context, c) {
                const spacing = 8.0;
                final width = (c.maxWidth - spacing * 2) / 3;
                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: [
                    for (final cat in ExpenseCategory.values)
                      SizedBox(
                        width: width,
                        child: _CategoryTile(
                          category: cat,
                          selected: cat == _category,
                          onTap: () => setState(() => _category = cat),
                        ),
                      ),
                  ],
                );
              },
            ),
            const Gap(20),
            TextFormField(
              key: const Key('expenseForm_note'),
              controller: _note,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Not (isteğe bağlı)',
                prefixIcon: Icon(Icons.edit_note_rounded),
              ),
            ),
            const Gap(10),
            Material(
              color: MfColors.slate50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: MfColors.slate200),
              ),
              child: InkWell(
                key: const Key('expenseForm_date'),
                borderRadius: BorderRadius.circular(12),
                onTap: _pickDate,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_rounded,
                        size: 20,
                        color: MfColors.slate500,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          formatDayLabel(_date),
                          style: t.titleMedium,
                        ),
                      ),
                      const Text(
                        'Değiştir',
                        style: TextStyle(
                          color: MfColors.blue600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Gap(24),
            Row(
              children: [
                if (_isEditing) ...[
                  SizedBox(
                    width: 56,
                    child: OutlinedButton(
                      key: const Key('expenseForm_delete'),
                      onPressed: () =>
                          Navigator.of(context).pop(const ExpenseFormDeleted()),
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
                ],
                Expanded(
                  child: FilledButton(
                    key: const Key('expenseForm_save'),
                    onPressed: _save,
                    child: Text(
                      _isEditing ? 'Değişiklikleri kaydet' : 'Kaydet',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Renkli kategori kutusu: ikon üstte, ad altta.
class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final ExpenseCategory category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = category.accent;
    final radius = BorderRadius.circular(14);
    return Material(
      color: selected ? accent : MfColors.slate50,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: selected ? accent : MfColors.slate200),
      ),
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Icon(
                category.icon,
                size: 22,
                color: selected ? Colors.white : accent,
              ),
              const SizedBox(height: 6),
              Text(
                category.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : MfColors.slate800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
