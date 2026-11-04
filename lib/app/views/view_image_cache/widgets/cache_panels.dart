import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_ders/app/core/cache/image_memory_controller.dart';
import 'package:flutter_ders/app/helper/measure_format.dart';
import 'package:flutter_ders/app/theme/app_theme.dart';
import 'package:flutter_ders/app/views/view_image_cache/cubit/image_cache_lab_cubit.dart';
import 'package:flutter_ders/app/views/view_image_cache/cubit/image_cache_lab_state.dart';
import 'package:flutter_ders/app/widgets/common.dart';

/// DERS 17 — Başlıklı beyaz kart.
class LabCard extends StatelessWidget {
  /// Kart oluşturur.
  const LabCard({
    required this.icon,
    required this.title,
    required this.children,
    super.key,
  });

  /// Simge.
  final IconData icon;

  /// Başlık.
  final String title;

  /// İçerik.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
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
              IconBadge(icon),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: t.titleSmall)),
            ],
          ),
          const Gap(10),
          ...children,
        ],
      ),
    );
  }
}

/// Etiket + değer hücresi.
class StatCell extends StatelessWidget {
  /// Hücre oluşturur.
  const StatCell(this.label, this.value, {super.key, this.color});

  /// Etiket.
  final String label;

  /// Değer.
  final String value;

  /// Değer rengi.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: MfColors.slate50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: t.labelSmall?.copyWith(color: MfColors.slate500)),
          Text(value, style: t.titleSmall?.copyWith(color: color)),
        ],
      ),
    );
  }
}

/// Sürüm denetimi kartı.
class VersionPanel extends StatelessWidget {
  /// Kart oluşturur.
  const VersionPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final v = context
        .select<ImageCacheLabCubit, ImageCacheLabState>((c) => c.state)
        .version;
    return LabCard(
      key: const Key('cache_version'),
      icon: Icons.new_releases_rounded,
      title: 'Sürüm denetimi (açılışta)',
      children: [
        Text(
          'Kayıtlı sürüm şimdikinden farklıysa disk ve bellek önbelleği '
          'boşaltılır: eski sürümün görseli ekranda kalmaz.',
          style: t.bodySmall,
        ),
        const Gap(10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            StatCell('Şimdiki', v?.current ?? '…'),
            StatCell('Önceki', v?.previous ?? 'ilk açılış'),
            StatCell(
              'Temizlendi mi',
              v == null ? '…' : (v.cleared ? 'Evet' : 'Hayır'),
              color: v?.cleared ?? false ? MfColors.emerald500 : null,
            ),
            StatCell('Silinen dosya', '${v?.removedFiles ?? 0}'),
          ],
        ),
        const Gap(10),
        OutlinedButton.icon(
          key: const Key('cache_upgrade'),
          onPressed: context.read<ImageCacheLabCubit>().simulateUpgrade,
          icon: const Icon(Icons.system_update_alt_rounded, size: 18),
          label: const Text('Yeni sürüm çıkmış gibi yap'),
        ),
      ],
    );
  }
}

/// Bellek denetleyicisi kartı: canlı grafik ve boşaltma kayıtları.
class MemoryPanel extends StatelessWidget {
  /// Kart oluşturur.
  const MemoryPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final state = context.watch<ImageCacheLabCubit>().state;
    final cubit = context.read<ImageCacheLabCubit>();
    final last = state.samples.lastOrNull;
    String mb(int b) => '${(b / (1 << 20)).toStringAsFixed(1)} MB';
    return LabCard(
      key: const Key('cache_memory'),
      icon: Icons.memory_rounded,
      title: 'Bellek denetleyicisi (arka planda, 2 sn)',
      children: [
        Text(
          'Bütçe cihaz RAM\'inin %2\'si. %90\'ı geçince ya da Android '
          '"bellek az" deyince ekranda olmayan görseller atılır; ekrandakiler '
          'kalır, bu yüzden titreme olmaz.',
          style: t.bodySmall,
        ),
        const Gap(10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            StatCell(
              'Cihaz RAM',
              state.ramMb == null ? '—' : formatBytes(state.ramMb! << 20),
            ),
            StatCell('Bütçe', last == null ? '—' : mb(last.budgetBytes)),
            StatCell('Önbellek', last == null ? '—' : mb(last.cacheBytes)),
            StatCell('Görsel', '${last?.cacheCount ?? 0}'),
            StatCell('Ekranda', '${last?.liveCount ?? 0}'),
            StatCell('Uygulama (RSS)', last == null ? '—' : mb(last.rssBytes)),
          ],
        ),
        const Gap(10),
        SizedBox(
          height: 70,
          child: CustomPaint(painter: _SamplesPainter(state.samples)),
        ),
        const SizedBox(height: 4),
        Text(
          'Mavi: önbellek · kesikli: bütçe',
          style: t.labelSmall?.copyWith(color: MfColors.slate400),
        ),
        if (state.trims.isNotEmpty) ...[
          const Gap(8),
          for (final e in state.trims)
            Text(
              '${_time(e.at)} · ${e.reason.label} · '
              '${formatBytes(e.freedBytes)} boşaldı',
              style: t.bodySmall,
            ),
        ],
        const Gap(10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(
              key: const Key('cache_clear_memory'),
              onPressed: cubit.clearMemory,
              child: const Text('Belleği boşalt'),
            ),
            OutlinedButton(
              key: const Key('cache_stress'),
              onPressed: cubit.stressTest,
              child: const Text('Yük testi (24 karo)'),
            ),
          ],
        ),
      ],
    );
  }
}

/// Disk önbelleği ve sayaçlar kartı.
class DiskPanel extends StatelessWidget {
  /// Kart oluşturur.
  const DiskPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final state = context.watch<ImageCacheLabCubit>().state;
    final cubit = context.read<ImageCacheLabCubit>();
    final s = state.stats;
    return LabCard(
      key: const Key('cache_disk'),
      icon: Icons.sd_storage_rounded,
      title: 'Disk önbelleği ve bütünlük',
      children: [
        Text(
          'Dosya önce .part adıyla yazılır, biçimin bitiş işareti ve çözme '
          'denetimi geçerse adı .img olur. Diskte bozulan dosya silinip '
          'yeniden indirilir.',
          style: t.bodySmall,
        ),
        const Gap(10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            StatCell(
              'Disk',
              '${state.disk.files} dosya · ${formatBytes(state.disk.bytes)}',
            ),
            StatCell('Diskten', '${s?.diskHits ?? 0}'),
            StatCell('İndirilen', '${s?.downloads ?? 0}'),
            StatCell(
              'Bozuk bulunan',
              '${s?.corrupted ?? 0}',
              color: (s?.corrupted ?? 0) > 0 ? MfColors.red600 : null,
            ),
            StatCell('Yeniden deneme', '${s?.retries ?? 0}'),
            StatCell('Ortak istek', '${s?.sharedRequests ?? 0}'),
          ],
        ),
        const Gap(10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(
              key: const Key('cache_clear_disk'),
              onPressed: cubit.clearDisk,
              child: const Text('Diski boşalt'),
            ),
            OutlinedButton(
              key: const Key('cache_corrupt'),
              onPressed: cubit.corruptFirst,
              child: const Text('Bir dosyayı boz'),
            ),
          ],
        ),
      ],
    );
  }
}

String _time(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:'
    '${d.minute.toString().padLeft(2, '0')}:'
    '${d.second.toString().padLeft(2, '0')}';

class _SamplesPainter extends CustomPainter {
  _SamplesPainter(this.samples);

  final List<MemorySample> samples;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(8)),
      Paint()..color = MfColors.slate50,
    );
    if (samples.isEmpty) return;
    final top = samples
        .map((s) => s.budgetBytes > s.cacheBytes ? s.budgetBytes : s.cacheBytes)
        .reduce((a, b) => a > b ? a : b)
        .toDouble();
    double y(int bytes) => size.height - 4 - bytes / top * (size.height - 8);
    final dx = samples.length < 2 ? 0.0 : size.width / (samples.length - 1);
    final budget = y(samples.last.budgetBytes);
    final dash = Paint()
      ..color = MfColors.slate400
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 8) {
      canvas.drawLine(Offset(x, budget), Offset(x + 4, budget), dash);
    }
    final path = Path();
    for (final (i, s) in samples.indexed) {
      final p = Offset(i * dx, y(s.cacheBytes));
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = MfColors.blue600
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_SamplesPainter old) => old.samples != samples;
}
