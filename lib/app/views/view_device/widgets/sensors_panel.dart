import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_ders/app/core/device/sensor_source.dart';
import 'package:flutter_ders/app/core/di/injection.dart';
import 'package:flutter_ders/app/theme/app_theme.dart';
import 'package:flutter_ders/app/views/view_network/widgets/network_cards.dart';
import 'package:flutter_ders/app/widgets/common.dart';

/// Yerçekimi ivmesi (m/s²).
const _g = 9.80665;

/// Bir sensörün o ana kadarki özeti: son ölçüm, son ölçümler (`history`)
/// ve saniyedeki ölçüm sayısı.
typedef SensorView = ({
  SensorReading last,
  List<SensorReading> history,
  double hz,
});

/// Sensör akışını özetler.
Stream<SensorView> collectSensor(
  Stream<SensorReading> source, {
  int max = 120,
}) async* {
  final history = <SensorReading>[];
  await for (final r in source) {
    history.add(r);
    if (history.length > max) history.removeAt(0);
    final span = history.last.time.difference(history.first.time);
    final hz = span.inMicroseconds == 0
        ? 0.0
        : (history.length - 1) / (span.inMicroseconds / 1e6);
    yield (last: r, history: [...history], hz: hz);
  }
}

/// Sallama sayacı: yerçekimsiz ivme [threshold]'u aşınca bir sallama
/// sayılır; ardından [gap] süresince yenisi sayılmaz.
Stream<({double magnitude, int shakes})> countShakes(
  Stream<SensorReading> source, {
  double threshold = 12,
  Duration gap = const Duration(milliseconds: 600),
}) async* {
  var shakes = 0;
  DateTime? lastShake;
  await for (final r in source) {
    final m = sqrt(r.x * r.x + r.y * r.y + r.z * r.z);
    if (m > threshold &&
        (lastShake == null || r.time.difference(lastShake) > gap)) {
      shakes++;
      lastShake = r.time;
    }
    yield (magnitude: m, shakes: shakes);
  }
}

/// Manyetometreden yaklaşık pusula yönü (derece; 0 = telefonun üstü
/// kuzeyi gösteriyor). Telefon düz dururken geçerlidir.
double compassHeading(double x, double y) =>
    (-atan2(x, y) * 180 / pi + 360) % 360;

/// DERS 12 — Hareket sensörleri.
class SensorsPanel extends StatefulWidget {
  /// Paneli oluşturur.
  const SensorsPanel({super.key});

  @override
  State<SensorsPanel> createState() => _SensorsPanelState();
}

class _SensorsPanelState extends State<SensorsPanel>
    with AutomaticKeepAliveClientMixin {
  final SensorSource _source = getIt<SensorSource>();

  // Akışlar build içinde değil, bir kez burada kurulur.
  late final Stream<SensorView> _accel = collectSensor(_source.accelerometer());
  late final Stream<SensorView> _gyro = collectSensor(
    _source.gyroscope(),
    max: 30,
  );
  late final Stream<SensorView> _magnet = collectSensor(
    _source.magnetometer(),
    max: 10,
  );
  late final Stream<({double magnitude, int shakes})> _shake = countShakes(
    _source.userAccelerometer(),
  );

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final t = Theme.of(context).textTheme;
    // Tembel liste ekrandan çıkan kartı yok eder; yeniden kurulan
    // StreamBuilder aynı akışı ikinci kez dinleyemez. Kartlar canlı kalsın.
    return SingleChildScrollView(
      key: const Key('sensors_list'),
      padding: pagePadding(context).copyWith(top: 16, bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Her sensör üç eksende (x: sağ, y: üst, z: ekrandan size) sayı '
            'üretir ve saniyede onlarca kez Stream ile gönderir.',
            style: t.bodyMedium,
          ),
          const Gap(12),
          const CodeBox('''
StreamBuilder<SensorReading>(
  stream: source.accelerometer(),   // ≈ 60 ölçüm/sn
  builder: (context, snap) => Text('x: \${snap.data?.x}'),
)'''),
          const Gap(20),
          _SensorStream(
            title: 'Su terazisi · ivmeölçer',
            stream: _accel,
            builder: (v) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Level(v.last),
                const Gap(12),
                _Axes(v.last, unit: 'm/s²'),
                const Gap(12),
                SizedBox(
                  height: 120,
                  child: CustomPaint(
                    painter: _ChartPainter(v.history, _g * 1.5),
                  ),
                ),
                const Gap(6),
                Text(
                  'Telefon düzken z ≈ 9,8: yerçekimi. Eğdikçe yerçekimi x ve y '
                  'eksenlerine dağılır; terazi bunu kullanır.',
                  style: t.bodySmall,
                ),
              ],
            ),
          ),
          const Gap(12),
          _SensorStream(
            title: 'Pusula · manyetometre',
            stream: _magnet,
            builder: (v) => _Compass(v.last),
          ),
          const Gap(12),
          _SensorStream(
            title: 'Dönüş · jiroskop',
            stream: _gyro,
            builder: (v) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Axes(v.last, unit: 'rad/s'),
                const Gap(8),
                Text(
                  'Telefonu çevirdikçe o eksendeki değer büyür; durunca 0\'a '
                  'döner. Saniyede '
                  '${(_magnitude(v.last) * 180 / pi).toStringAsFixed(0)}° dönüyor.',
                  style: t.bodySmall,
                ),
              ],
            ),
          ),
          const Gap(12),
          SectionCard(
            child: StreamBuilder<({double magnitude, int shakes})>(
              stream: _shake,
              builder: (context, snapshot) {
                final s = snapshot.data;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Sallama · kullanıcı ivmesi', style: t.titleMedium),
                    const Gap(6),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ConnectionChip(snapshot.connectionState),
                    ),
                    const Gap(10),
                    if (snapshot.hasError)
                      const Text('Bu telefonda bu sensör yok.')
                    else ...[
                      Text(
                        'Sallama: ${s?.shakes ?? 0}',
                        key: const Key('sensors_shakes'),
                        style: t.headlineSmall,
                      ),
                      const Gap(8),
                      LinearProgressIndicator(
                        value: ((s?.magnitude ?? 0) / 20).clamp(0, 1),
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      const Gap(6),
                      Text(
                        'Yerçekimi çıkarılmış ivme: '
                        '${(s?.magnitude ?? 0).toStringAsFixed(1)} m/s² '
                        '(12 üstü = sallama)',
                        style: t.bodySmall,
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

double _magnitude(SensorReading r) => sqrt(r.x * r.x + r.y * r.y + r.z * r.z);

/// Başlık, bağlantı durumu ve ölçüm hızıyla bir sensör kartı.
class _SensorStream extends StatelessWidget {
  const _SensorStream({
    required this.title,
    required this.stream,
    required this.builder,
  });

  final String title;
  final Stream<SensorView> stream;
  final Widget Function(SensorView view) builder;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return SectionCard(
      child: StreamBuilder<SensorView>(
        stream: stream,
        builder: (context, snapshot) {
          final v = snapshot.data;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: Text(title, style: t.titleMedium)),
                  if (v != null)
                    Eyebrow(
                      '${v.hz.toStringAsFixed(0)} Hz',
                      color: MfColors.slate600,
                      background: MfColors.slate100,
                    ),
                ],
              ),
              const Gap(6),
              Align(
                alignment: Alignment.centerLeft,
                child: ConnectionChip(snapshot.connectionState),
              ),
              const Gap(12),
              if (snapshot.hasError)
                const Text('Bu telefonda bu sensör yok.')
              else if (v == null)
                const LinearProgressIndicator()
              else
                builder(v),
            ],
          );
        },
      ),
    );
  }
}

class _Axes extends StatelessWidget {
  const _Axes(this.r, {required this.unit});

  final SensorReading r;
  final String unit;

  static const colors = [
    MfColors.red600,
    MfColors.emerald500,
    MfColors.blue600,
  ];

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final values = [r.x, r.y, r.z];
    return Row(
      children: [
        for (final (i, name) in ['x', 'y', 'z'].indexed) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
              decoration: BoxDecoration(
                color: colors[i].withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: t.labelMedium?.copyWith(color: colors[i])),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      values[i].toStringAsFixed(2),
                      key: Key('sensors_${unit}_$name'),
                      style: t.titleMedium?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  Text(unit, style: t.bodySmall),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Su terazisi: kabarcık telefonun yüksek tarafına kaçar.
class _Level extends StatelessWidget {
  const _Level(this.r);

  final SensorReading r;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    // Eğim açıları: yerçekiminin eksenlere dağılımından.
    final roll = atan2(r.x, r.z) * 180 / pi;
    final pitch = atan2(r.y, r.z) * 180 / pi;
    final flat = roll.abs() < 2 && pitch.abs() < 2;
    return Row(
      children: [
        SizedBox.square(
          dimension: 130,
          child: LayoutBuilder(
            builder: (context, c) {
              final radius = c.maxWidth / 2;
              final dx = (r.x / _g).clamp(-1.0, 1.0) * (radius - 14);
              final dy = (-r.y / _g).clamp(-1.0, 1.0) * (radius - 14);
              return Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (flat ? MfColors.emerald500 : MfColors.blue600)
                          .withValues(alpha: 0.08),
                      border: Border.all(color: MfColors.slate200, width: 2),
                    ),
                  ),
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: MfColors.slate400),
                    ),
                  ),
                  Transform.translate(
                    offset: Offset(dx, dy),
                    child: Container(
                      key: const Key('sensors_bubble'),
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: flat ? MfColors.emerald500 : MfColors.blue600,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                flat ? 'Düz ✓' : 'Eğik',
                key: const Key('sensors_flat'),
                style: t.titleLarge?.copyWith(
                  color: flat ? MfColors.emerald500 : MfColors.slate900,
                ),
              ),
              const Gap(6),
              Text(
                'Sağa / sola: ${roll.toStringAsFixed(1)}°',
                style: t.bodyMedium,
              ),
              Text(
                'İleri / geri: ${pitch.toStringAsFixed(1)}°',
                style: t.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Son ölçümlerin x, y, z çizgileri.
class _ChartPainter extends CustomPainter {
  _ChartPainter(this.history, this.range);

  final List<SensorReading> history;

  /// Dikeyde gösterilen en büyük değer (± range).
  final double range;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(10)),
      Paint()..color = MfColors.slate50,
    );
    final mid = size.height / 2;
    canvas.drawLine(
      Offset(0, mid),
      Offset(size.width, mid),
      Paint()..color = MfColors.slate200,
    );
    if (history.length < 2) return;
    final step = size.width / (history.length - 1);
    for (final (i, pick) in <double Function(SensorReading)>[
      (r) => r.x,
      (r) => r.y,
      (r) => r.z,
    ].indexed) {
      final path = Path();
      for (final (j, r) in history.indexed) {
        final y = mid - (pick(r) / range).clamp(-1.0, 1.0) * (mid - 4);
        j == 0 ? path.moveTo(0, y) : path.lineTo(j * step, y);
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = _Axes.colors[i],
      );
    }
  }

  @override
  bool shouldRepaint(_ChartPainter old) => old.history != history;
}

class _Compass extends StatelessWidget {
  const _Compass(this.r);

  final SensorReading r;

  static const _names = ['K', 'KD', 'D', 'GD', 'G', 'GB', 'B', 'KB'];

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final heading = compassHeading(r.x, r.y);
    final strength = _magnitude(r);
    final name = _names[((heading + 22.5) % 360 ~/ 45)];
    return Row(
      children: [
        SizedBox.square(
          dimension: 120,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: MfColors.slate200, width: 2),
                ),
              ),
              // Ok, ekranın neresi kuzeyse oraya döner.
              Transform.rotate(
                angle: -heading * pi / 180,
                child: const Icon(
                  Icons.navigation_rounded,
                  size: 64,
                  color: MfColors.red600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${heading.toStringAsFixed(0)}° $name',
                key: const Key('sensors_heading'),
                style: t.headlineSmall,
              ),
              Text('Telefonun üstünün baktığı yön', style: t.bodySmall),
              const Gap(8),
              Text(
                'Alan: ${strength.toStringAsFixed(0)} µT',
                style: t.bodyMedium,
              ),
              Text(
                strength > 100
                    ? 'Yakında metal / mıknatıs var, yön şaşabilir.'
                    : 'Dünya\'nın alanı 25–65 µT. Telefon düzken yaklaşıktır.',
                style: t.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
