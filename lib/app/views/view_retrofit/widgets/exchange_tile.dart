import 'package:flutter/material.dart';
import 'package:flutter_ders/app/core/network/recording_interceptor.dart';
import 'package:flutter_ders/app/helper/measure_format.dart';
import 'package:flutter_ders/app/theme/app_theme.dart';

/// HTTP metodunun rengi.
Color methodColor(String method) => switch (method) {
  'GET' => MfColors.blue600,
  'POST' => MfColors.emerald500,
  'PUT' => const Color(0xFFF59E0B),
  'PATCH' => const Color(0xFF8B5CF6),
  'DELETE' => MfColors.red600,
  _ => MfColors.slate500,
};

/// Durum kodunun rengi.
Color statusColor(int? code) => switch (code) {
  null => MfColors.red600,
  < 300 => MfColors.emerald500,
  < 400 => const Color(0xFFF59E0B),
  _ => MfColors.red600,
};

/// DERS 16 — Tek istek/cevap: başlıkta özet, açınca ham ayrıntı.
class ExchangeTile extends StatelessWidget {
  /// [exchange] için satır oluşturur.
  const ExchangeTile(this.exchange, {super.key, this.showDemo = false});

  /// Gösterilen istek.
  final NetworkExchange exchange;

  /// Hangi denemeden geldiği yazılsın mı?
  final bool showDemo;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final e = exchange;
    final took = e.took;
    final mono = t.bodySmall?.copyWith(fontFamily: 'monospace', height: 1.4);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: MfColors.slate50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MfColors.slate200),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        dense: true,
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 10),
        childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        title: Row(
          children: [
            _Pill(e.method, methodColor(e.method)),
            const SizedBox(width: 6),
            _Pill(
              e.statusCode?.toString() ?? 'HATA',
              statusColor(e.statusCode),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${e.url.host}${e.url.path}'
                '${e.url.hasQuery ? '?${e.url.query}' : ''}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: mono,
              ),
            ),
          ],
        ),
        subtitle: Text(
          [
            if (took != null) formatDuration(took),
            if (showDemo && e.demoId != null) 'deneme: ${e.demoId}',
            ?e.error,
          ].join(' · '),
          style: t.bodySmall,
        ),
        children: [
          _Block('İstek başlıkları', _headers(e.requestHeaders), mono),
          if (e.extra.isNotEmpty)
            _Block(
              'extra (ağa gitmez, yalnız interceptor görür)',
              e.extra.entries.map((x) => '${x.key}: ${x.value}').join('\n'),
              mono,
            ),
          if (e.requestBody case final body?)
            _Block('İstek gövdesi', body, mono),
          _Block('Cevap başlıkları', _headers(e.responseHeaders), mono),
          if (e.responseBody case final body?)
            _Block('Cevap gövdesi', _cut(body), mono),
        ],
      ),
    );
  }

  static String _headers(Map<String, String> h) =>
      h.isEmpty ? '—' : h.entries.map((e) => '${e.key}: ${e.value}').join('\n');

  static String _cut(String s) => s.length <= 2500
      ? s
      : '${s.substring(0, 2500)}\n… (${s.length} karakter)';
}

class _Pill extends StatelessWidget {
  const _Pill(this.text, this.color);

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      text,
      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800),
    ),
  );
}

class _Block extends StatelessWidget {
  const _Block(this.title, this.text, this.style);

  final String title;
  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: t.labelSmall?.copyWith(color: MfColors.slate500)),
          const SizedBox(height: 2),
          SelectableText(text, style: style),
        ],
      ),
    );
  }
}
