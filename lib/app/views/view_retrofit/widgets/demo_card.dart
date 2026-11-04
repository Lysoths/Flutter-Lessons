import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_ders/app/helper/measure_format.dart';
import 'package:flutter_ders/app/theme/app_theme.dart';
import 'package:flutter_ders/app/views/view_network/widgets/network_cards.dart';
import 'package:flutter_ders/app/views/view_retrofit/cubit/retrofit_demos.dart';
import 'package:flutter_ders/app/views/view_retrofit/cubit/retrofit_lab_cubit.dart';
import 'package:flutter_ders/app/views/view_retrofit/cubit/retrofit_lab_state.dart';
import 'package:flutter_ders/app/views/view_retrofit/widgets/exchange_tile.dart';
import 'package:flutter_ders/app/widgets/common.dart';

/// DERS 16 — Tek retrofit özelliğinin kartı.
///
/// Girdiler kartın kendi State'inde (TextEditingController); sonuç Cubit'te.
/// Kart kaydırılıp ekrandan çıksa da yazılanlar kaybolmasın diye
/// `AutomaticKeepAliveClientMixin` kullanılır.
class DemoCard extends StatefulWidget {
  /// [demo] için kart oluşturur.
  const DemoCard({required this.demo, super.key});

  /// Gösterilen deneme.
  final RetrofitDemo demo;

  @override
  State<DemoCard> createState() => _DemoCardState();
}

class _DemoCardState extends State<DemoCard>
    with AutomaticKeepAliveClientMixin {
  late final Map<String, TextEditingController> _inputs = {
    for (final i in widget.demo.inputs)
      i.key: TextEditingController(text: i.initial),
  };
  bool _open = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    for (final c in _inputs.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _send() {
    FocusScope.of(context).unfocus();
    context.read<RetrofitLabCubit>().run(widget.demo, {
      for (final e in _inputs.entries) e.key: e.value.text,
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final t = Theme.of(context).textTheme;
    final demo = widget.demo;
    final run = context.select<RetrofitLabCubit, DemoRun?>(
      (c) => c.state.runs[demo.id],
    );
    final running = run?.status == RunStatus.running;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _open ? MfColors.blue100 : MfColors.slate200),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            key: Key('demo_${demo.id}'),
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          demo.annotation,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: MfColors.blue700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(demo.title, style: t.titleSmall),
                      ],
                    ),
                  ),
                  _StatusDot(run),
                  Icon(
                    _open
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: MfColors.slate400,
                  ),
                ],
              ),
            ),
          ),
          if (_open)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(demo.description, style: t.bodySmall),
                  const Gap(10),
                  CodeBox(demo.code),
                  if (demo.inputs.isNotEmpty) ...[
                    const Gap(10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final i in demo.inputs)
                          SizedBox(
                            width: demo.inputs.length == 1
                                ? double.infinity
                                : 150,
                            child: TextField(
                              key: Key('input_${demo.id}_${i.key}'),
                              controller: _inputs[i.key],
                              enabled: !running,
                              keyboardType: i.numeric
                                  ? TextInputType.number
                                  : TextInputType.text,
                              inputFormatters: i.numeric
                                  ? [FilteringTextInputFormatter.digitsOnly]
                                  : null,
                              decoration: InputDecoration(
                                labelText: i.label,
                                isDense: true,
                              ),
                              onSubmitted: (_) => _send(),
                            ),
                          ),
                      ],
                    ),
                  ],
                  const Gap(10),
                  Row(
                    children: [
                      FilledButton.icon(
                        key: Key('send_${demo.id}'),
                        onPressed: running ? null : _send,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 42),
                        ),
                        icon: running
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send_rounded, size: 18),
                        label: Text(running ? 'Gönderiliyor' : 'Gönder'),
                      ),
                      if (demo.cancellable) ...[
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          key: Key('cancel_${demo.id}'),
                          onPressed: running
                              ? () => context.read<RetrofitLabCubit>().cancel(
                                  demo,
                                )
                              : null,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 42),
                          ),
                          icon: const Icon(Icons.close_rounded, size: 18),
                          label: const Text('İptal'),
                        ),
                      ],
                    ],
                  ),
                  if (demo.showsProgress && run?.progress != null) ...[
                    const Gap(10),
                    LinearProgressIndicator(
                      key: Key('progress_${demo.id}'),
                      value: run!.progress,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '%${((run.progress ?? 0) * 100).round()}',
                      style: t.bodySmall,
                    ),
                  ],
                  if (run != null && !running) ...[
                    const Gap(12),
                    _ResultBox(demo: demo, run: run),
                  ],
                  if (run != null && run.exchanges.isNotEmpty) ...[
                    const Gap(10),
                    Text(
                      'Ağdan geçenler (${run.exchanges.length})',
                      style: t.labelMedium,
                    ),
                    const SizedBox(height: 6),
                    for (final e in run.exchanges) ExchangeTile(e),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot(this.run);

  final DemoRun? run;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (run?.status) {
      null => (MfColors.slate200, ''),
      RunStatus.running => (MfColors.blue600, '…'),
      RunStatus.success => (MfColors.emerald500, '✓'),
      RunStatus.failure => (MfColors.red600, '!'),
      RunStatus.cancelled => (const Color(0xFFF59E0B), '×'),
    };
    return Container(
      width: 22,
      height: 22,
      margin: const EdgeInsets.only(right: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _ResultBox extends StatelessWidget {
  const _ResultBox({required this.demo, required this.run});

  final RetrofitDemo demo;
  final DemoRun run;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final ok = run.status == RunStatus.success;
    final color = switch (run.status) {
      RunStatus.success => MfColors.emerald500,
      RunStatus.cancelled => const Color(0xFFF59E0B),
      _ => MfColors.red600,
    };
    final took = run.took;
    return Container(
      key: Key('result_${demo.id}'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                ok ? Icons.check_circle_rounded : Icons.error_rounded,
                size: 18,
                color: color,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  run.resultType ?? '',
                  style: t.titleSmall?.copyWith(
                    color: color,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              if (took != null) Text(formatDuration(took), style: t.bodySmall),
            ],
          ),
          if (run.error case final error?) ...[
            const SizedBox(height: 6),
            Text(error, style: t.bodyMedium),
          ],
          if (run.resultText case final text?) ...[
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: SingleChildScrollView(
                child: SelectableText(
                  text,
                  style: t.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    height: 1.4,
                    color: MfColors.slate900,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
