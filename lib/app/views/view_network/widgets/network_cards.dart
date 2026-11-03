import 'package:flutter/material.dart';
import 'package:flutter_ders/app/helper/network_checker.dart';
import 'package:flutter_ders/app/theme/app_theme.dart';
import 'package:flutter_ders/app/widgets/common.dart';

/// Kod örneği kutusu.
class CodeBox extends StatelessWidget {
  /// [code] için kutu oluşturur.
  const CodeBox(this.code, {super.key});

  /// Gösterilen kod.
  final String code;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MfColors.terminal,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        code,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 11.5,
          height: 1.45,
          color: Color(0xFFA5F3FC),
        ),
      ),
    );
  }
}

/// Beyaz, kenarlıklı bölüm kartı.
class SectionCard extends StatelessWidget {
  /// Kart oluşturur.
  const SectionCard({required this.child, super.key});

  /// İçerik.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: MfColors.slate200),
      ),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}

/// `ConnectionState`'in Türkçe adı ve rengi.
({String label, Color color}) connectionLabel(ConnectionState s) => switch (s) {
  ConnectionState.none => (label: 'none · başlamadı', color: MfColors.slate500),
  ConnectionState.waiting => (
    label: 'waiting · bekleniyor',
    color: const Color(0xFFF59E0B),
  ),
  ConnectionState.active => (
    label: 'active · veri akıyor',
    color: MfColors.blue600,
  ),
  ConnectionState.done => (label: 'done · bitti', color: MfColors.emerald500),
};

/// Bağlantı durumu çipi.
class ConnectionChip extends StatelessWidget {
  /// [state] için çip oluşturur.
  const ConnectionChip(this.state, {super.key});

  /// Gösterilen durum.
  final ConnectionState state;

  @override
  Widget build(BuildContext context) {
    final l = connectionLabel(state);
    return Eyebrow(
      'ConnectionState.${l.label}',
      color: l.color,
      background: l.color.withValues(alpha: 0.1),
    );
  }
}

/// Çevrimiçi / çevrimdışı sonuç satırı.
class NetworkResultRow extends StatelessWidget {
  /// [result] için satır oluşturur.
  const NetworkResultRow(this.result, {super.key});

  /// Gösterilen sonuç.
  final NetworkResult result;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final r = result;
    final color = r.online ? MfColors.emerald500 : MfColors.red600;
    String two(int n) => n.toString().padLeft(2, '0');
    final time =
        '${two(r.checkedAt.hour)}:${two(r.checkedAt.minute)}:'
        '${two(r.checkedAt.second)}';
    return Row(
      children: [
        Icon(
          r.online ? Icons.wifi_rounded : Icons.wifi_off_rounded,
          color: color,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                r.online ? 'Çevrimiçi' : 'Çevrimdışı',
                style: t.titleSmall?.copyWith(color: color),
              ),
              Text(r.detail, style: t.bodySmall),
            ],
          ),
        ),
        Text(
          '$time\n${r.latency.inMilliseconds} ms',
          textAlign: TextAlign.end,
          style: t.bodySmall,
        ),
      ],
    );
  }
}
