import 'package:flutter/material.dart';
import 'package:flutter_ders/app/core/base/base_change_notifier_view_model.dart';
import 'package:flutter_ders/app/helper/measure_format.dart';
import 'package:flutter_ders/app/models/currency/currency_info.dart';
import 'package:flutter_ders/app/models/currency/rate_history.dart';
import 'package:flutter_ders/app/theme/app_theme.dart';
import 'package:flutter_ders/app/views/view_currency/view_model/history_view_model.dart';
import 'package:flutter_ders/app/views/view_currency/widgets/section_title.dart';
import 'package:flutter_ders/app/widgets/common.dart';
import 'package:provider/provider.dart';

/// DERS 15 — 2. bölüm: haftalık / aylık / 3 aylık geçmiş. Yalnızca
/// [HistoryViewModel]'i dinler.
class HistorySection extends StatelessWidget {
  /// Bölümü oluşturur.
  const HistorySection({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final vm = context.watch<HistoryViewModel>();
    final info = currencyInfo(vm.code);
    final history = vm.history;
    final took = vm.took;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CurrencySectionTitle(
          number: 2,
          title: '${info.flag} ${info.code} geçmişi',
          trailing: took == null ? null : formatDuration(took),
        ),
        SegmentedButton<HistoryPeriod>(
          key: const Key('history_period'),
          segments: [
            for (final p in HistoryPeriod.values)
              ButtonSegment(
                value: p,
                label: Text(p.label, key: Key('period_${p.name}')),
              ),
          ],
          selected: {vm.period},
          showSelectedIcon: false,
          onSelectionChanged: (s) => vm.showPeriod(s.first),
        ),
        const Gap(12),
        Container(
          key: const Key('history_card'),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: MfColors.slate200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (vm.status == ViewStatus.failure)
                CurrencyErrorRow(
                  message: vm.error ?? 'Geçmiş alınamadı.',
                  onRetry: vm.load,
                ),
              if (history != null) ...[_Stats(history), const Gap(12)],
              SizedBox(
                height: 170,
                child: Stack(
                  children: [
                    if (history != null)
                      Positioned.fill(
                        child: AnimatedOpacity(
                          opacity: vm.isBusy ? 0.35 : 1,
                          duration: const Duration(milliseconds: 200),
                          child: CustomPaint(
                            painter: _LinePainter(
                              history.points,
                              color: changeColor(history.changePercent),
                            ),
                          ),
                        ),
                      ),
                    if (vm.isBusy)
                      const Center(child: CircularProgressIndicator()),
                  ],
                ),
              ),
              if (history != null) ...[
                const Gap(6),
                Row(
                  children: [
                    Text(_short(history.points.first.date), style: t.bodySmall),
                    const Spacer(),
                    Text(
                      '${history.points.length} nokta',
                      style: t.bodySmall?.copyWith(color: MfColors.slate400),
                    ),
                    const Spacer(),
                    Text(_short(history.points.last.date), style: t.bodySmall),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats(this.history);

  final RateHistory history;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final change = history.changePercent;
    Widget cell(String label, String value, {Color? color, Key? key}) =>
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: t.bodySmall),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  key: key,
                  style: t.titleSmall?.copyWith(color: color),
                ),
              ),
            ],
          ),
        );
    return Row(
      children: [
        cell(
          'Değişim',
          formatChange(change),
          color: changeColor(change),
          key: const Key('history_change'),
        ),
        cell('En düşük', formatTryRate(history.min)),
        cell('En yüksek', formatTryRate(history.max)),
        cell('Son', formatTryRate(history.points.last.value)),
      ],
    );
  }
}

String _short(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}';

/// Çizgi grafik: noktalar, altında yumuşak dolgu, en düşük/yüksek kılavuz.
class _LinePainter extends CustomPainter {
  _LinePainter(this.points, {required this.color});

  final List<RatePoint> points;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final values = points.map((p) => p.value);
    final lo = values.reduce((a, b) => a < b ? a : b);
    final hi = values.reduce((a, b) => a > b ? a : b);
    final span = hi - lo == 0 ? 1 : hi - lo;
    Offset at(int i) => Offset(
      size.width * i / (points.length - 1),
      size.height - 8 - (points[i].value - lo) / span * (size.height - 16),
    );

    final grid = Paint()
      ..color = MfColors.slate100
      ..strokeWidth = 1;
    for (final y in [8.0, size.height / 2, size.height - 8]) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final line = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < points.length; i++) {
      line.lineTo(at(i).dx, at(i).dy);
    }
    final fill = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas
      ..drawPath(
        fill,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [color.withValues(alpha: 0.25), color.withValues(alpha: 0)],
          ).createShader(Offset.zero & size),
      )
      ..drawPath(
        line,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeJoin = StrokeJoin.round,
      )
      ..drawCircle(at(points.length - 1), 4, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_LinePainter old) =>
      old.points != points || old.color != color;
}
