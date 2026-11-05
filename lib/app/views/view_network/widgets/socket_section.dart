import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_ders/app/core/analytics/app_events.dart';
import 'package:flutter_ders/app/helper/mock_socket.dart';
import 'package:flutter_ders/app/theme/app_theme.dart';
import 'package:flutter_ders/app/views/view_network/widgets/network_cards.dart';
import 'package:flutter_ders/app/widgets/common.dart';

/// Soketten gelenlerin o ana kadarki özeti.
typedef _SocketView = ({
  RateTick? last,
  RateTick? previous,
  int ticks,
  List<EchoReply> echoes,
});

/// Gelen mesajları biriktirip her mesajda yeni bir özet yayar.
Stream<_SocketView> _collect(Stream<SocketMessage> messages) async* {
  RateTick? last;
  RateTick? previous;
  var ticks = 0;
  final echoes = <EchoReply>[];
  await for (final m in messages) {
    switch (m) {
      case RateTick():
        previous = last;
        last = m;
        ticks++;
      case EchoReply():
        echoes.insert(0, m);
        if (echoes.length > 5) echoes.removeLast();
    }
    yield (last: last, previous: previous, ticks: ticks, echoes: [...echoes]);
  }
}

/// DERS 11 — StreamBuilder + sahte WebSocket.
class SocketSection extends StatefulWidget {
  /// Bölümü oluşturur.
  const SocketSection({super.key});

  @override
  State<SocketSection> createState() => _SocketSectionState();
}

class _SocketSectionState extends State<SocketSection> {
  final MockSocketServer _server = MockSocketServer();
  final TextEditingController _text = TextEditingController();
  MockSocketClient? _client;
  Stream<_SocketView>? _stream;
  bool _connecting = false;

  @override
  void dispose() {
    unawaited(_client?.close());
    unawaited(_server.stop());
    _text.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    track(AppEvent.socketConnected);
    setState(() => _connecting = true);
    final uri = await _server.start();
    final client = await MockSocketClient.connect(uri);
    if (!mounted) {
      unawaited(client.close());
      return;
    }
    setState(() {
      _connecting = false;
      _client = client;
      _stream = _collect(client.messages);
    });
  }

  Future<void> _disconnect() async {
    await _client?.close();
    if (!mounted) return;
    setState(() => _client = null);
  }

  void _send() {
    final text = _text.text.trim();
    if (text.isEmpty) return;
    track(AppEvent.socketMessage);
    _client?.send(text);
    _text.clear();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final connected = _client != null;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _server.uri == null
                ? 'Sunucu: kapalı'
                : 'Sunucu: ${_server.uri} (yalnızca bu telefon)',
            style: t.bodySmall,
          ),
          const Gap(10),
          // stream null iken ConnectionState.none, bağlanınca waiting,
          // ilk mesajla active, bağlantı kapanınca done olur.
          StreamBuilder<_SocketView>(
            key: const Key('socket_builder'),
            stream: _stream,
            builder: (context, snapshot) {
              final view = snapshot.data;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ConnectionChip(
                    snapshot.connectionState,
                    key: const Key('socket_state'),
                  ),
                  const Gap(12),
                  Row(
                    children: [
                      Expanded(
                        child: _Rate(
                          'USD/TRY',
                          view?.last?.usd,
                          view?.previous?.usd,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _Rate(
                          'EUR/TRY',
                          view?.last?.eur,
                          view?.previous?.eur,
                        ),
                      ),
                    ],
                  ),
                  const Gap(6),
                  Text(
                    'Gelen kur mesajı: ${view?.ticks ?? 0} · sahte veri',
                    key: const Key('socket_ticks'),
                    style: t.bodySmall,
                  ),
                  if (view != null && view.echoes.isNotEmpty) ...[
                    const Gap(10),
                    for (final e in view.echoes)
                      Text(
                        '↩ Sunucu geri yolladı: "${e.text}"',
                        style: t.bodyMedium,
                      ),
                  ],
                ],
              );
            },
          ),
          const Gap(12),
          if (connected)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('socket_input'),
                    controller: _text,
                    decoration: const InputDecoration(
                      hintText: 'Sunucuya mesaj yaz',
                      isDense: true,
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                IconButton.filled(
                  key: const Key('socket_send'),
                  onPressed: _send,
                  icon: const Icon(Icons.send_rounded),
                ),
              ],
            ),
          const Gap(10),
          if (connected)
            OutlinedButton.icon(
              key: const Key('socket_disconnect'),
              onPressed: _disconnect,
              icon: const Icon(Icons.link_off_rounded),
              label: const Text('Bağlantıyı kes'),
            )
          else
            FilledButton.icon(
              key: const Key('socket_connect'),
              onPressed: _connecting ? null : _connect,
              icon: const Icon(Icons.link_rounded),
              label: Text(
                _connecting ? 'Bağlanıyor…' : 'Sahte sunucuya bağlan',
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
