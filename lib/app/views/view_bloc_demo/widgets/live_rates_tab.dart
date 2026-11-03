import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_ders/app/theme/app_theme.dart';
import 'package:flutter_ders/app/views/view_bloc_demo/bloc/live_rates_bloc.dart';
import 'package:flutter_ders/app/views/view_bloc_demo/bloc/live_rates_event.dart';
import 'package:flutter_ders/app/views/view_bloc_demo/bloc/live_rates_state.dart';
import 'package:flutter_ders/app/views/view_network/widgets/network_cards.dart';
import 'package:flutter_ders/app/widgets/common.dart';

/// DERS 13 — 2. sekme: gerçek zamanlı veri (WebSocket → Bloc).
class LiveRatesTab extends StatefulWidget {
  /// Sekmeyi oluşturur.
  const LiveRatesTab({super.key});

  @override
  State<LiveRatesTab> createState() => _LiveRatesTabState();
}

class _LiveRatesTabState extends State<LiveRatesTab> {
  final TextEditingController _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _send() {
    context.read<LiveRatesBloc>().add(LiveMessageSent(_text.text));
    _text.clear();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final bloc = context.read<LiveRatesBloc>();
    return SingleChildScrollView(
      padding: pagePadding(context).copyWith(top: 16, bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "Ders 11'deki sahte WebSocket sunucusu (telefonun içinde). Fark: "
            'akışı artık ekran değil Bloc dinliyor; ekran yalnızca durumu çizer.',
            style: t.bodyMedium,
          ),
          const Gap(12),
          const CodeBox('''
on<LiveConnectRequested>((event, emit) async {
  await emit.forEach(repository.connect(),
    onData: (mesaj) => state.copyWith(last: mesaj));
});'''),
          const Gap(16),
          BlocBuilder<LiveRatesBloc, LiveRatesState>(
            builder: (context, state) {
              final connected =
                  state.status == LiveStatus.connecting ||
                  state.status == LiveStatus.live;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Eyebrow(
                        state.status.label,
                        key: const Key('live_status'),
                        color: state.status == LiveStatus.live
                            ? MfColors.emerald500
                            : MfColors.slate600,
                        background: MfColors.slate100,
                      ),
                      const Spacer(),
                      if (connected)
                        OutlinedButton.icon(
                          key: const Key('live_disconnect'),
                          onPressed: () =>
                              bloc.add(const LiveDisconnectRequested()),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 40),
                          ),
                          icon: const Icon(Icons.link_off_rounded),
                          label: const Text('Kes'),
                        )
                      else
                        FilledButton.icon(
                          key: const Key('live_connect'),
                          onPressed: () =>
                              bloc.add(const LiveConnectRequested()),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 40),
                          ),
                          icon: const Icon(Icons.link_rounded),
                          label: const Text('Bağlan'),
                        ),
                    ],
                  ),
                  const Gap(12),
                  Row(
                    children: [
                      Expanded(
                        child: _Rate(
                          'USD/TRY',
                          state.last?.usd,
                          state.previous?.usd,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _Rate(
                          'EUR/TRY',
                          state.last?.eur,
                          state.previous?.eur,
                        ),
                      ),
                    ],
                  ),
                  if (state.error != null) ...[
                    const Gap(8),
                    Text(
                      state.error!,
                      style: t.bodyMedium?.copyWith(color: MfColors.red600),
                    ),
                  ],
                  if (connected) ...[
                    const Gap(14),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            key: const Key('live_input'),
                            controller: _text,
                            decoration: const InputDecoration(
                              hintText: 'Sunucuya mesaj yaz',
                              isDense: true,
                            ),
                            onSubmitted: (_) => _send(),
                          ),
                        ),
                        IconButton.filled(
                          key: const Key('live_send'),
                          onPressed: _send,
                          icon: const Icon(Icons.send_rounded),
                        ),
                      ],
                    ),
                  ],
                  for (final e in state.echoes)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '↩ Sunucu geri yolladı: "${e.text}"',
                        style: t.bodyMedium,
                      ),
                    ),
                ],
              );
            },
          ),
          const Gap(16),
          // BlocSelector: yalnızca seçilen parça (ticks) değişince çizilir;
          // echo gelince bu satır yeniden çizilmez.
          BlocSelector<LiveRatesBloc, LiveRatesState, int>(
            selector: (state) => state.ticks,
            builder: (context, ticks) => Text(
              'Gelen kur mesajı: $ticks · sahte veri (BlocSelector)',
              key: const Key('live_ticks'),
              style: t.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _Rate extends StatelessWidget {
  const _Rate(this.label, this.value, this.previous);

  final String label;
  final double? value;
  final double? previous;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final v = value;
    final p = previous;
    final up = v != null && p != null && v >= p;
    final color = v == null || p == null
        ? MfColors.slate600
        : up
        ? MfColors.emerald500
        : MfColors.red600;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MfColors.slate50,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: t.labelMedium),
          const SizedBox(height: 4),
          Row(
            children: [
              Flexible(
                child: Text(
                  v == null ? '—' : v.toStringAsFixed(3),
                  style: t.titleLarge?.copyWith(
                    color: color,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              if (p != null)
                Icon(
                  up
                      ? Icons.arrow_drop_up_rounded
                      : Icons.arrow_drop_down_rounded,
                  color: color,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
