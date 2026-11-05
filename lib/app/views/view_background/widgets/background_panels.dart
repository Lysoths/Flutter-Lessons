import 'package:flutter/material.dart';
import 'package:flutter_ders/app/core/background/background_models.dart';
import 'package:flutter_ders/app/core/background/notification_plan.dart';
import 'package:flutter_ders/app/core/device/location_source.dart';
import 'package:flutter_ders/app/theme/app_theme.dart';
import 'package:flutter_ders/app/views/view_background/background_view.dart';
import 'package:flutter_ders/app/views/view_background/cubit/background_lab_cubit.dart';
import 'package:flutter_ders/app/widgets/common.dart';

BoxDecoration _card() => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(18),
  border: Border.all(color: MfColors.slate200),
);

/// ListTile'ların mürekkep efekti görünsün diye kart Material'dır.
class _CardBox extends StatelessWidget {
  const _CardBox({
    required this.child,
    this.padding = EdgeInsets.zero,
    this.color = Colors.white,
    this.radius = 18,
    this.border = true,
    super.key,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color color;
  final double radius;
  final bool border;

  @override
  Widget build(BuildContext context) => Material(
    color: color,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: border
          ? const BorderSide(color: MfColors.slate200)
          : BorderSide.none,
    ),
    child: Padding(padding: padding, child: child),
  );
}

String _two(int v) => v.toString().padLeft(2, '0');

/// Saat:dakika:saniye.
String clock(DateTime t) =>
    '${_two(t.hour)}:${_two(t.minute)}:${_two(t.second)}';

/// Süreyi kısa yazar: 4 sn, 3 dk 12 sn, 1 sa 5 dk.
String shortDuration(int ms) {
  final d = Duration(milliseconds: ms);
  if (d.inHours > 0) return '${d.inHours} sa ${d.inMinutes % 60} dk';
  if (d.inMinutes > 0) return '${d.inMinutes} dk ${d.inSeconds % 60} sn';
  return '${d.inSeconds} sn';
}

/// Bölüm başlığı.
class SectionTitle extends StatelessWidget {
  /// Oluşturur.
  const SectionTitle({
    required this.icon,
    required this.title,
    this.trailing,
    super.key,
  });

  /// Simge.
  final IconData icon;

  /// Başlık.
  final String title;

  /// Sağdaki kısa yazı.
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: MfColors.slate600),
        const SizedBox(width: 8),
        Expanded(child: Text(title, style: t.titleMedium)),
        if (trailing != null)
          Text(
            trailing!,
            style: t.labelMedium?.copyWith(color: MfColors.slate500),
          ),
      ],
    );
  }
}

/// Servis kartı: durum, izinler, düğmeler.
class ServiceCard extends StatelessWidget {
  /// Oluşturur.
  const ServiceCard({
    required this.state,
    required this.onStart,
    required this.onStop,
    required this.onPreview,
    required this.onMuted,
    required this.onClear,
    super.key,
  });

  /// Durum.
  final BackgroundLabState state;

  /// Başlat.
  final VoidCallback onStart;

  /// Durdur.
  final VoidCallback onStop;

  /// Önizle.
  final VoidCallback onPreview;

  /// Sessiz.
  final ValueChanged<bool> onMuted;

  /// Sil.
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = state;
    final presence = s.running ? s.stats.presence : null;
    final color = presence == null
        ? MfColors.slate400
        : presenceColor(presence);
    return _CardBox(
      key: const Key('bg_status'),
      padding: const EdgeInsets.all(16),
      color: MfColors.slate900,
      radius: 20,
      border: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  s.running ? 'Servis çalışıyor' : 'Servis kapalı',
                  key: const Key('bg_running'),
                  style: t.titleMedium?.copyWith(color: Colors.white),
                ),
              ),
              if (presence != null)
                Container(
                  key: const Key('bg_presence'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Uygulama: ${presence.label}',
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const Gap(12),
          _Permission(
            icon: Icons.my_location_rounded,
            label: 'Konum',
            value: s.location?.label ?? 'Başlatınca sorulur',
            ok: s.location == null
                ? null
                : s.location == LocationAccess.granted,
          ),
          _Permission(
            icon: Icons.notifications_rounded,
            label: 'Bildirim',
            value: switch (s.notifications) {
              null => 'Başlatınca sorulur',
              true => 'İzin verildi',
              false => 'İzin verilmedi',
            },
            ok: s.notifications,
          ),
          const Gap(12),
          Row(
            children: [
              Expanded(
                child: s.running
                    ? OutlinedButton.icon(
                        key: const Key('bg_stop'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: MfColors.slate600),
                        ),
                        onPressed: onStop,
                        icon: const Icon(Icons.stop_rounded),
                        label: const Text('Durdur'),
                      )
                    : FilledButton.icon(
                        key: const Key('bg_start'),
                        onPressed: s.busy ? null : onStart,
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: Text(
                          s.busy ? 'İzin bekleniyor…' : 'Servisi başlat',
                        ),
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.tonalIcon(
                  key: const Key('bg_preview'),
                  onPressed: s.running ? onPreview : null,
                  icon: const Icon(Icons.notifications_active_rounded),
                  label: const Text('Hepsini dene'),
                ),
              ),
            ],
          ),
          const Gap(4),
          SwitchListTile(
            key: const Key('bg_mute'),
            contentPadding: EdgeInsets.zero,
            dense: true,
            value: s.stats.muted,
            onChanged: s.running ? onMuted : null,
            title: const Text(
              'Simülasyonu sessize al',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: const Text(
              'Bildirimdeki “Sessize al” düğmesi de bunu açar.',
              style: TextStyle(color: MfColors.slate400, fontSize: 12),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const Key('bg_clear'),
              style: TextButton.styleFrom(foregroundColor: MfColors.slate200),
              onPressed: onClear,
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              label: const Text('Konumları ve istatistiği sil'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Permission extends StatelessWidget {
  const _Permission({
    required this.icon,
    required this.label,
    required this.value,
    required this.ok,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool? ok;

  @override
  Widget build(BuildContext context) {
    final color = switch (ok) {
      null => MfColors.slate400,
      true => MfColors.emerald500,
      false => const Color(0xFFF87171),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 16, color: MfColors.slate400),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: MfColors.slate200)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// İstatistik kutuları.
class StatsGrid extends StatelessWidget {
  /// Oluşturur.
  const StatsGrid({required this.stats, required this.stored, super.key});

  /// İstatistik.
  final BackgroundStats stats;

  /// Kayıtlı konum.
  final int stored;

  @override
  Widget build(BuildContext context) {
    final s = stats;
    final tiles = [
      ('Adım (3 sn)', '${s.ticks}', Icons.timer_rounded),
      ('GPS okuması', '${s.gpsOk}', Icons.gps_fixed_rounded),
      ('Kayıtlı konum', '$stored', Icons.save_rounded),
      ('GPS hatası', '${s.gpsFailed}', Icons.gps_off_rounded),
      ('Açıkken atlanan', '${s.skippedOpen}', Icons.skip_next_rounded),
      ('Çakışan adım', '${s.overlapped}', Icons.call_split_rounded),
      (
        'Ort. / en uzun okuma',
        '${s.averageReadMs} / ${s.maxReadMs} ms',
        Icons.speed_rounded,
      ),
      ('Arkada mesafe', formatDistance(s.distanceMeters), Icons.route_rounded),
      ('Bildirim', '${s.notificationsTotal}', Icons.notifications_rounded),
      (
        'İptal edilen',
        '${s.notificationsCancelled}',
        Icons.notifications_off_rounded,
      ),
      (
        'Düğme',
        '${s.actions.values.fold(0, (a, b) => a + b)}',
        Icons.touch_app_rounded,
      ),
      ('Servis başlatma', '${s.serviceStarts}', Icons.restart_alt_rounded),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        final width = (c.maxWidth - 10) / 2;
        return Wrap(
          key: const Key('bg_stats'),
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final (label, value, icon) in tiles)
              Container(
                width: width,
                padding: const EdgeInsets.all(12),
                decoration: _card(),
                child: Row(
                  children: [
                    Icon(icon, size: 18, color: MfColors.blue600),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            value,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: MfColors.slate500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Metre → "850 m" / "1,24 km".
String formatDistance(double m) => m < 1000
    ? '${m.round()} m'
    : '${(m / 1000).toStringAsFixed(2).replaceAll('.', ',')} km';

/// Açık / arka plan / kapalı sürelerinin oranı.
class PresenceBar extends StatelessWidget {
  /// Oluşturur.
  const PresenceBar({required this.stats, super.key});

  /// İstatistik.
  final BackgroundStats stats;

  @override
  Widget build(BuildContext context) {
    final total = stats.presenceMs.values.fold(0, (a, b) => a + b);
    return Container(
      key: const Key('bg_presence_bar'),
      padding: const EdgeInsets.all(12),
      decoration: _card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 10,
              child: total == 0
                  ? const ColoredBox(color: MfColors.slate100)
                  : Row(
                      children: [
                        for (final p in AppPresence.values)
                          if ((stats.presenceMs[p] ?? 0) > 0)
                            Expanded(
                              flex: stats.presenceMs[p]!,
                              child: ColoredBox(color: presenceColor(p)),
                            ),
                      ],
                    ),
            ),
          ),
          const Gap(10),
          Row(
            children: [
              for (final p in AppPresence.values)
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: presenceColor(p),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '${p.label} ${shortDuration(stats.presenceMs[p] ?? 0)}',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Simülasyon çizelgesi.
class PlanList extends StatelessWidget {
  /// Oluşturur.
  const PlanList({required this.plan, required this.stats, super.key});

  /// Satırlar.
  final List<PlanRow> plan;

  /// Tür başına gönderilen sayısı için.
  final BackgroundStats stats;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return _CardBox(
      key: const Key('bg_plan'),
      child: Column(
        children: [
          for (final (i, row) in plan.indexed) ...[
            if (i > 0) const Divider(height: 1, color: MfColors.slate100),
            ListTile(
              key: Key('bg_plan_${row.kind.name}'),
              dense: true,
              leading: SizedBox(
                width: 48,
                child: Text(
                  '+${row.seconds} sn',
                  style: t.labelMedium?.copyWith(color: MfColors.slate500),
                ),
              ),
              title: Text(
                row.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Row(
                children: [
                  Icon(kindIcon(row.kind), size: 14, color: MfColors.slate400),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      '${row.kind.label} · ${stats.notificationsSent[row.kind.key] ?? 0} kez',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              trailing: _StepChip(row.state),
            ),
          ],
        ],
      ),
    );
  }
}

class _StepChip extends StatelessWidget {
  const _StepChip(this.state);

  final PlanStepState state;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (state) {
      PlanStepState.waiting => ('Bekliyor', MfColors.slate500),
      PlanStepState.sent => ('Gönderildi', MfColors.emerald500),
      PlanStepState.cancelled => ('İptal', MfColors.red600),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Son durum geçişleri.
class ChangesList extends StatelessWidget {
  /// Oluşturur.
  const ChangesList({required this.changes, super.key});

  /// Geçişler (en yenisi sonda).
  final List<PresenceChange> changes;

  @override
  Widget build(BuildContext context) {
    if (changes.isEmpty) {
      return const _Empty(
        'Henüz geçiş yok. Servisi başlatıp uygulamayı arka plana at.',
      );
    }
    return _CardBox(
      key: const Key('bg_changes'),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          for (final c in changes.reversed.take(8))
            ListTile(
              dense: true,
              leading: Icon(
                Icons.circle,
                size: 10,
                color: presenceColor(c.presence),
              ),
              title: Text(c.presence.label),
              subtitle: Text(c.reason),
              trailing: Text(clock(c.at)),
            ),
        ],
      ),
    );
  }
}

/// Son konumlar.
class SamplesList extends StatelessWidget {
  /// Oluşturur.
  const SamplesList({required this.samples, super.key});

  /// Konumlar (en yenisi başta).
  final List<GpsSample> samples;

  @override
  Widget build(BuildContext context) {
    if (samples.isEmpty) {
      return const _Empty(
        'Konum yok. Uygulama arkadayken 3 saniyede bir eklenir.',
      );
    }
    return _CardBox(
      key: const Key('bg_samples'),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          for (final s in samples.take(20))
            ListTile(
              dense: true,
              leading: Icon(
                Icons.place_rounded,
                color: presenceColor(s.presence),
              ),
              title: Text(
                '${s.latitude.toStringAsFixed(6)}, ${s.longitude.toStringAsFixed(6)}',
                style: const TextStyle(
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              subtitle: Text(
                '±${s.accuracy.round()} m · ${s.presence.label} · ${s.readMs} ms',
              ),
              trailing: Text(clock(s.time)),
            ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: _card(),
    child: Text(text, style: Theme.of(context).textTheme.bodySmall),
  );
}
