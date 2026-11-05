import 'package:flutter/material.dart';
import 'package:flutter_ders/app/helper/money_format.dart';
import 'package:flutter_ders/app/models/expense.dart';
import 'package:flutter_ders/app/theme/app_theme.dart';
import 'package:flutter_ders/app/views/view_expenses/expense_grouping.dart';
import 'package:flutter_ders/app/views/view_expenses/widgets/expense_tile_widget.dart';

const _monthsShort = [
  'OCA',
  'ŞUB',
  'MAR',
  'NİS',
  'MAY',
  'HAZ',
  'TEM',
  'AĞU',
  'EYL',
  'EKİ',
  'KAS',
  'ARA',
];

const _monthsLong = [
  'Ocak',
  'Şubat',
  'Mart',
  'Nisan',
  'Mayıs',
  'Haziran',
  'Temmuz',
  'Ağustos',
  'Eylül',
  'Ekim',
  'Kasım',
  'Aralık',
];

String _key(DateTime d) => '${d.year}_${d.month}_${d.day}';

/// "10–16 Kasım" ya da ay sınırında "30 Kasım".
String weekRangeLabel(WeekGroup w) {
  final month = _monthsLong[w.to.month - 1];
  return w.from.day == w.to.day
      ? '${w.from.day} $month'
      : '${w.from.day}–${w.to.day} $month';
}

/// Ana sayfadaki harcamalar: ay kartları, içinde katlanır haftalar.
///
/// Açılışta yalnız bu ay ve bu hafta açıktır; eski aylar tek satırlık
/// özet olarak durur, dokununca açılır. Liste bu sayede yüzlerce harcamada
/// da kısa kalır.
class ExpenseTimeline extends StatefulWidget {
  /// Oluşturur.
  const ExpenseTimeline({
    required this.expenses,
    required this.onTap,
    required this.onDelete,
    this.now,
    super.key,
  });

  /// Harcamalar.
  final List<Expense> expenses;

  /// Karta dokunma.
  final ValueChanged<Expense> onTap;

  /// Kaydırarak silme.
  final ValueChanged<Expense> onDelete;

  /// Şimdiki zaman (testler).
  final DateTime? now;

  @override
  State<ExpenseTimeline> createState() => _ExpenseTimelineState();
}

class _ExpenseTimelineState extends State<ExpenseTimeline> {
  final Set<DateTime> _months = {};
  final Set<(DateTime, DateTime)> _weeks = {};
  bool _initialized = false;

  void _initOnce(List<MonthGroup> groups, DateTime now) {
    if (_initialized || groups.isEmpty) return;
    _initialized = true;
    final d = defaultExpanded(groups, now);
    _months.add(d.month!);
    _weeks.add((d.month!, d.week!));
  }

  void _toggleMonth(DateTime m) =>
      setState(() => _months.contains(m) ? _months.remove(m) : _months.add(m));

  void _toggleWeek(DateTime m, DateTime w) => setState(
    () => _weeks.contains((m, w)) ? _weeks.remove((m, w)) : _weeks.add((m, w)),
  );

  @override
  Widget build(BuildContext context) {
    final now = widget.now ?? DateTime.now();
    final groups = groupByMonthAndWeek(widget.expenses);
    _initOnce(groups, now);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, g) in groups.indexed)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: _MonthCard(
              group: g,
              previous: i + 1 < groups.length ? groups[i + 1] : null,
              now: now,
              open: _months.contains(g.month),
              openWeeks: {
                for (final (m, w) in _weeks)
                  if (m == g.month) w,
              },
              onToggle: () => _toggleMonth(g.month),
              onToggleWeek: (w) => _toggleWeek(g.month, w),
              onTap: widget.onTap,
              onDelete: widget.onDelete,
            ),
          ),
      ],
    );
  }
}

class _MonthCard extends StatelessWidget {
  const _MonthCard({
    required this.group,
    required this.previous,
    required this.now,
    required this.open,
    required this.openWeeks,
    required this.onToggle,
    required this.onToggleWeek,
    required this.onTap,
    required this.onDelete,
  });

  final MonthGroup group;
  final MonthGroup? previous;
  final DateTime now;
  final bool open;
  final Set<DateTime> openWeeks;
  final VoidCallback onToggle;
  final ValueChanged<DateTime> onToggleWeek;
  final ValueChanged<Expense> onTap;
  final ValueChanged<Expense> onDelete;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final m = group.month;
    final isThisMonth = m.year == now.year && m.month == now.month;
    final prev = previous;
    final change = prev == null || prev.total == 0
        ? null
        : ((group.total - prev.total) / prev.total * 100).round();
    return Material(
      key: Key('expenses_month_${_key(m)}'),
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isThisMonth ? MfColors.blue600 : MfColors.slate200,
          width: isThisMonth ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            key: Key('expenses_month_toggle_${_key(m)}'),
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 52,
                    decoration: BoxDecoration(
                      color: isThisMonth ? MfColors.blue600 : MfColors.slate100,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _monthsShort[m.month - 1],
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: isThisMonth
                                ? Colors.white
                                : MfColors.slate800,
                          ),
                        ),
                        Text(
                          '${m.year}',
                          style: TextStyle(
                            fontSize: 11,
                            color: isThisMonth
                                ? MfColors.blue100
                                : MfColors.slate500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isThisMonth
                              ? 'Bu ay · ${_monthsLong[m.month - 1]}'
                              : '${_monthsLong[m.month - 1]} ${m.year}',
                          style: t.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${group.count} harcama · ${group.weeks.length} hafta',
                          style: t.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatMoney(group.total),
                        style: t.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (change != null) _ChangeChip(change),
                    ],
                  ),
                  AnimatedRotation(
                    turns: open ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.expand_more_rounded,
                      color: MfColors.slate400,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: open
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final w in group.weeks)
                          _WeekSection(
                            week: w,
                            monthTotal: group.total,
                            now: now,
                            open: openWeeks.contains(w.weekStart),
                            onToggle: () => onToggleWeek(w.weekStart),
                            onTap: onTap,
                            onDelete: onDelete,
                          ),
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

/// Önceki aya göre değişim: harcama arttıysa kırmızı, azaldıysa yeşil.
class _ChangeChip extends StatelessWidget {
  const _ChangeChip(this.percent);

  final int percent;

  @override
  Widget build(BuildContext context) {
    final up = percent > 0;
    final color = percent == 0
        ? MfColors.slate500
        : up
        ? MfColors.red600
        : const Color(0xFF059669);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
          size: 12,
          color: color,
        ),
        Text(
          '%${percent.abs()}',
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _WeekSection extends StatelessWidget {
  const _WeekSection({
    required this.week,
    required this.monthTotal,
    required this.now,
    required this.open,
    required this.onToggle,
    required this.onTap,
    required this.onDelete,
  });

  final WeekGroup week;
  final double monthTotal;
  final DateTime now;
  final bool open;
  final VoidCallback onToggle;
  final ValueChanged<Expense> onTap;
  final ValueChanged<Expense> onDelete;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final thisWeek = mondayOf(now);
    final lastWeek = DateTime(thisWeek.year, thisWeek.month, thisWeek.day - 7);
    final tag = week.weekStart == thisWeek
        ? 'Bu hafta'
        : week.weekStart == lastWeek
        ? 'Geçen hafta'
        : null;
    final share = monthTotal == 0 ? 0.0 : week.total / monthTotal;
    return Container(
      key: Key('expenses_week_${_key(week.weekStart)}'),
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: open ? MfColors.slate50 : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MfColors.slate100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            key: Key('expenses_week_toggle_${_key(week.weekStart)}'),
            borderRadius: BorderRadius.circular(16),
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                weekRangeLabel(week),
                                style: t.titleSmall,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (tag != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: MfColors.blue50,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  tag,
                                  style: const TextStyle(
                                    color: MfColors.blue700,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Text(
                        '${week.count} · ${formatMoney(week.total)}',
                        style: t.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      AnimatedRotation(
                        turns: open ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: const Icon(
                          Icons.expand_more_rounded,
                          size: 20,
                          color: MfColors.slate400,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Haftanın ay toplamındaki payı.
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: share.clamp(0, 1),
                      minHeight: 4,
                      backgroundColor: MfColors.slate100,
                      color: MfColors.blue600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: open
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final d in week.days) ...[
                          Padding(
                            padding: const EdgeInsets.only(
                              top: 8,
                              bottom: 6,
                              left: 4,
                            ),
                            child: Text(
                              formatDayLabel(d.day, now: now).toUpperCase(),
                              style: t.labelMedium,
                            ),
                          ),
                          for (final e in d.items)
                            Padding(
                              key: ValueKey(e.id),
                              padding: const EdgeInsets.only(bottom: 8),
                              child: ExpenseTileWidget(
                                expense: e,
                                onTap: () => onTap(e),
                                onDelete: () => onDelete(e),
                              ),
                            ),
                        ],
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}
