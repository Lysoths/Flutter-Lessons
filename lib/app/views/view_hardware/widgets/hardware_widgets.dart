import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_ders/app/core/hardware/hardware_profile.dart';
import 'package:flutter_ders/app/helper/measure_format.dart';
import 'package:flutter_ders/app/theme/app_theme.dart';
import 'package:flutter_ders/app/views/view_hardware/cubit/hardware_cubit.dart';
import 'package:flutter_ders/app/views/view_hardware/hardware_format.dart';
import 'package:flutter_ders/app/widgets/common.dart';

/// Üstteki koyu kart: model, Android, yonga, RAM, depolama.
class HardwareHero extends StatelessWidget {
  /// Oluşturur.
  const HardwareHero({required this.profile, super.key});

  /// Profil.
  final DeviceProfile profile;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = profile;
    final soc = [?p.cpu.socMaker, ?p.cpu.socModel].join(' ');
    final chips = [
      if (p.system.release != null) 'Android ${p.system.release}',
      if (p.system.sdk != null) 'API ${p.system.sdk}',
      '${p.cpu.cores} çekirdek',
      formatBytes(p.memory.total),
      formatBytes(p.storage.total),
    ];
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: MfColors.slate900,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            p.identity.title.isEmpty ? 'Bu telefon' : p.identity.title,
            key: const Key('hardware_title'),
            style: t.titleLarge?.copyWith(color: Colors.white),
          ),
          if (soc.isNotEmpty) ...[
            const Gap(2),
            Text(soc, style: t.bodyMedium?.copyWith(color: MfColors.slate400)),
          ],
          const Gap(14),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final c in chips)
                Eyebrow(
                  c,
                  color: Colors.white,
                  background: Colors.white.withValues(alpha: 0.1),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Canlı ölçüm kartı: pil, sıcaklık, akım grafiği, boş RAM, çekirdekler.
class LiveCard extends StatelessWidget {
  /// Oluşturur.
  const LiveCard({
    required this.live,
    required this.history,
    required this.cpu,
    super.key,
  });

  /// Son ölçüm.
  final LiveReading? live;

  /// Akım geçmişi (mA).
  final List<double> history;

  /// İşlemci (en yüksek frekanslar için).
  final CpuInfo cpu;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final r = live;
    Widget figure(String label, String value, Key key) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: t.labelSmall?.copyWith(color: MfColors.slate500)),
          const Gap(2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, key: key, style: t.titleMedium),
          ),
        ],
      ),
    );
    return _CardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.sensors_rounded,
                size: 18,
                color: r == null ? MfColors.slate400 : MfColors.emerald500,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Canlı · saniyede bir', style: t.titleSmall),
              ),
              if (r?.charging ?? false)
                const Eyebrow(
                  'Şarjda',
                  color: Color(0xFF047857),
                  background: Color(0xFFD1FAE5),
                ),
            ],
          ),
          const Gap(12),
          Row(
            children: [
              figure(
                'Pil',
                r?.battery == null ? '–' : '%${r!.battery}',
                const Key('hardware_live_battery'),
              ),
              figure(
                'Sıcaklık',
                r?.temperature == null
                    ? '–'
                    : '${formatDecimal(r!.temperature!)} °C',
                const Key('hardware_live_temp'),
              ),
              figure(
                'Akım',
                r?.currentUa == null ? '–' : formatCurrent(r!.currentUa!),
                const Key('hardware_live_current'),
              ),
              figure(
                'Boş RAM',
                r?.freeRam == null ? '–' : formatBytes(r!.freeRam!),
                const Key('hardware_live_ram'),
              ),
            ],
          ),
          const Gap(12),
          SizedBox(
            height: 44,
            width: double.infinity,
            child: CustomPaint(painter: _Sparkline(history)),
          ),
          const Gap(4),
          Text(
            'Akım (mA): eksi değer pilden çekilen, artı şarj.',
            style: t.bodySmall,
          ),
          if (r != null && r.coreKhz.any((k) => k != null)) ...[
            const Gap(14),
            Text('Çekirdeklerin anlık hızı', style: t.labelLarge),
            const Gap(8),
            _CoreBars(now: r.coreKhz, max: cpu.maxKhz),
          ],
        ],
      ),
    );
  }
}

class _Sparkline extends CustomPainter {
  _Sparkline(this.values);

  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    final base = Paint()
      ..color = MfColors.slate200
      ..strokeWidth = 1;
    if (values.length < 2) {
      canvas.drawLine(
        Offset(0, size.height / 2),
        Offset(size.width, size.height / 2),
        base,
      );
      return;
    }
    final lo = math.min(0, values.reduce(math.min)).toDouble();
    final hi = math.max(0, values.reduce(math.max)).toDouble();
    final span = (hi - lo).abs() < 1 ? 1.0 : hi - lo;
    double y(double v) => size.height - (v - lo) / span * size.height;
    canvas.drawLine(Offset(0, y(0)), Offset(size.width, y(0)), base);
    final step = size.width / (HardwareState.historyLength - 1);
    final start = size.width - step * (values.length - 1);
    final path = Path()..moveTo(start, y(values.first));
    for (var i = 1; i < values.length; i++) {
      path.lineTo(start + step * i, y(values[i]));
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = MfColors.blue600
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_Sparkline old) => old.values != values;
}

class _CoreBars extends StatelessWidget {
  const _CoreBars({required this.now, required this.max});

  final List<int?> now;
  final List<int?> max;

  @override
  Widget build(BuildContext context) {
    final peak = max.whereType<int>().fold(0, math.max);
    return SizedBox(
      height: 54,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < now.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Flexible(
                      child: FractionallySizedBox(
                        heightFactor: peak == 0 || now[i] == null
                            ? 0.04
                            : (now[i]! / peak).clamp(0.04, 1.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: now[i] == null
                                ? MfColors.slate200
                                : MfColors.blue600,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                    const Gap(3),
                    Text(
                      '$i',
                      style: const TextStyle(
                        fontSize: 10,
                        color: MfColors.slate500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Beyaz kenarlıklı kart.
class _CardBox extends StatelessWidget {
  const _CardBox({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: const BorderSide(color: MfColors.slate200),
    ),
    clipBehavior: Clip.antiAlias,
    child: Padding(padding: const EdgeInsets.all(16), child: child),
  );
}

/// Açılıp kapanan bölüm kartı.
class HardwareSection extends StatefulWidget {
  /// Oluşturur.
  const HardwareSection({
    required this.id,
    required this.icon,
    required this.title,
    required this.children,
    this.summary,
    this.initiallyOpen = false,
    super.key,
  });

  /// Test anahtarında kullanılan ad.
  final String id;

  /// Simge.
  final IconData icon;

  /// Başlık.
  final String title;

  /// Kapalıyken başlığın altındaki kısa özet.
  final String? summary;

  /// Açılışta açık mı?
  final bool initiallyOpen;

  /// İçerik.
  final List<Widget> children;

  @override
  State<HardwareSection> createState() => _HardwareSectionState();
}

class _HardwareSectionState extends State<HardwareSection> {
  late bool _open = widget.initiallyOpen;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: MfColors.slate200),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            InkWell(
              key: Key('hardware_section_${widget.id}'),
              onTap: () => setState(() => _open = !_open),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                child: Row(
                  children: [
                    IconBadge(widget.icon, size: 36),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.title, style: t.titleSmall),
                          if (widget.summary != null)
                            Text(
                              widget.summary!,
                              style: t.bodySmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: _open ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(
                        Icons.expand_more_rounded,
                        color: MfColors.slate500,
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
              child: _open
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Divider(height: 1, color: MfColors.slate100),
                          const Gap(8),
                          ...widget.children,
                        ],
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ad – değer satırı. Uzun değerler alt satıra kayar.
class InfoRow extends StatelessWidget {
  /// Oluşturur.
  const InfoRow(this.label, this.value, {this.trailing, super.key});

  /// Ad.
  final String label;

  /// Değer; `null` ise "–".
  final String? value;

  /// Sağdaki küçük düğme.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 116,
            child: Text(
              label,
              style: t.bodySmall?.copyWith(color: MfColors.slate500),
            ),
          ),
          Expanded(child: Text(value ?? '–', style: t.bodyMedium)),
          ?trailing,
        ],
      ),
    );
  }
}

/// Yüzde çubuğu: kullanılan / toplam.
class UsageBar extends StatelessWidget {
  /// Oluşturur.
  const UsageBar({
    required this.label,
    required this.used,
    required this.total,
    super.key,
  });

  /// Ad.
  final String label;

  /// Kullanılan (bayt).
  final int used;

  /// Toplam (bayt).
  final int total;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final ratio = total <= 0 ? 0.0 : (used / total).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: t.labelLarge)),
              Text(
                '${formatBytes(used)} / ${formatBytes(total)}',
                style: t.bodySmall,
              ),
            ],
          ),
          const Gap(6),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              backgroundColor: MfColors.slate100,
              color: ratio > 0.85 ? MfColors.red600 : MfColors.blue600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Var / yok çipleri.
class FeatureChips extends StatelessWidget {
  /// Oluşturur.
  const FeatureChips({required this.features, super.key});

  /// Özellikler.
  final Map<String, bool> features;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final MapEntry(:key, value: label) in kFeatureLabels.entries)
          if (features.containsKey(key))
            Chip(
              key: Key('hardware_feature_$key'),
              visualDensity: VisualDensity.compact,
              avatar: Icon(
                features[key]! ? Icons.check_rounded : Icons.close_rounded,
                size: 16,
                color: features[key]! ? MfColors.emerald500 : MfColors.slate400,
              ),
              label: Text(
                label,
                style: TextStyle(
                  color: features[key]! ? MfColors.slate800 : MfColors.slate400,
                ),
              ),
            ),
      ],
    );
  }
}

/// IMEI satırı: dene düğmesi ve sonucun açıklaması.
class ImeiPanel extends StatelessWidget {
  /// Oluşturur.
  const ImeiPanel({
    required this.result,
    required this.busy,
    required this.onTry,
    super.key,
  });

  /// Sonuç.
  final ImeiResult? result;

  /// Deneniyor mu?
  final bool busy;

  /// Dene.
  final VoidCallback onTry;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final r = result;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: r is ImeiBlocked ? const Color(0xFFFFFBEB) : MfColors.slate50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: r is ImeiBlocked ? const Color(0xFFFDE68A) : MfColors.slate200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('IMEI', style: t.labelLarge)),
              TextButton.icon(
                key: const Key('hardware_imei_try'),
                onPressed: busy ? null : onTry,
                icon: busy
                    ? const SizedBox.square(
                        dimension: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.play_arrow_rounded, size: 18),
                label: Text(r == null ? 'Kanaldan iste' : 'Tekrar dene'),
              ),
            ],
          ),
          Text(
            switch (r) {
              null =>
                'Kotlin tarafı TelephonyManager.getImei() çağırır. Sonucu '
                    'görmek için dene.',
              ImeiRead(:final value) => value,
              final ImeiBlocked b => imeiExplanation(b),
            },
            key: const Key('hardware_imei_result'),
            style: t.bodySmall,
          ),
        ],
      ),
    );
  }
}
