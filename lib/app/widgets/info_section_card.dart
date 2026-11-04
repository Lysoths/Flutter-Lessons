import 'package:flutter/material.dart';
import 'package:flutter_ders/app/models/info_section.dart';
import 'package:flutter_ders/app/theme/app_theme.dart';
import 'package:flutter_ders/app/widgets/common.dart';

/// DERS 14 — Bölüm kimliğine göre simge.
IconData infoSectionIcon(String id) => switch (id) {
  'identity' => Icons.smartphone_rounded,
  'os' => Icons.android_rounded,
  'build' => Icons.construction_rounded,
  'hardware' => Icons.memory_rounded,
  'memory' => Icons.storage_rounded,
  'runtime' => Icons.code_rounded,
  'screen' => Icons.aspect_ratio_rounded,
  'app' => Icons.apps_rounded,
  'flutter' => Icons.flutter_dash_rounded,
  'connectivity' => Icons.wifi_tethering_rounded,
  'wifi' => Icons.wifi_rounded,
  'interfaces' => Icons.lan_rounded,
  'trace' => Icons.public_rounded,
  'tls' => Icons.lock_rounded,
  _ => Icons.info_outline_rounded,
};

/// Başlık ve etiket/değer satırlarından oluşan kart.
class InfoSectionCard extends StatelessWidget {
  /// [section] için kart oluşturur.
  const InfoSectionCard(this.section, {super.key, this.trailing});

  /// Gösterilen bölüm.
  final InfoSection section;

  /// Başlığın sağındaki isteğe bağlı öğe.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      key: Key('info_${section.id}'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: MfColors.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconBadge(infoSectionIcon(section.id)),
              const SizedBox(width: 10),
              Expanded(child: Text(section.title, style: t.titleSmall)),
              ?trailing,
              Text(
                '${section.entries.length}',
                style: t.labelSmall?.copyWith(color: MfColors.slate400),
              ),
            ],
          ),
          const Gap(6),
          for (final (i, e) in section.entries.indexed) ...[
            if (i > 0) const Divider(height: 1, color: MfColors.slate100),
            InfoRow(e),
          ],
        ],
      ),
    );
  }
}

/// Tek satır. Hassas değerler gizli başlar; dokununca görünür.
class InfoRow extends StatefulWidget {
  /// [entry] için satır oluşturur.
  const InfoRow(this.entry, {super.key});

  /// Gösterilen satır.
  final InfoEntry entry;

  @override
  State<InfoRow> createState() => _InfoRowState();
}

class _InfoRowState extends State<InfoRow> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final e = widget.entry;
    final hidden = e.sensitive && !_revealed && e.value != '—';
    return InkWell(
      onTap: e.sensitive ? () => setState(() => _revealed = !_revealed) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 4,
              child: Text(
                e.label,
                style: t.bodySmall?.copyWith(color: MfColors.slate500),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 6,
              child: Text(
                hidden ? '•••••• (göster)' : e.value,
                key: Key('info_value_${e.label}'),
                textAlign: TextAlign.end,
                style: t.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: hidden ? MfColors.slate400 : MfColors.slate900,
                ),
              ),
            ),
            if (e.sensitive) ...[
              const SizedBox(width: 6),
              Icon(
                _revealed
                    ? Icons.visibility_rounded
                    : Icons.visibility_off_rounded,
                size: 16,
                color: MfColors.slate400,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
