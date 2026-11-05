import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_ders/app/core/analytics/app_events.dart';
import 'package:flutter_ders/app/core/device/location_source.dart';
import 'package:flutter_ders/app/core/di/injection.dart';
import 'package:flutter_ders/app/theme/app_theme.dart';
import 'package:flutter_ders/app/views/view_network/widgets/network_cards.dart';
import 'package:flutter_ders/app/widgets/common.dart';

/// Gelen konumların o ana kadarki özeti.
typedef GpsView = ({
  GpsFix last,
  List<GpsFix> track,
  double distance,
  int count,
});

/// Konum akışını özetler: her yeni konumda son [max] noktayı, toplam
/// mesafeyi ve ölçüm sayısını yayar.
Stream<GpsView> collectGps(Stream<GpsFix> source, {int max = 300}) async* {
  final track = <GpsFix>[];
  var distance = 0.0;
  var count = 0;
  await for (final fix in source) {
    count++;
    if (track.isNotEmpty) {
      final prev = track.last;
      final step = distanceMeters(
        prev.latitude,
        prev.longitude,
        fix.latitude,
        fix.longitude,
      );
      // GPS yerinde dururken de birkaç metre "titrer"; doğruluk
      // yarıçapından küçük adımlar mesafeye eklenmez.
      if (step > fix.accuracy / 2) distance += step;
    }
    track.add(fix);
    if (track.length > max) track.removeAt(0);
    yield (last: fix, track: [...track], distance: distance, count: count);
  }
}

/// DERS 12 — GPS donanımından canlı konum.
class GpsPanel extends StatefulWidget {
  /// Paneli oluşturur.
  const GpsPanel({super.key});

  @override
  State<GpsPanel> createState() => _GpsPanelState();
}

class _GpsPanelState extends State<GpsPanel>
    with AutomaticKeepAliveClientMixin {
  final LocationSource _source = getIt<LocationSource>();
  LocationAccess? _access;
  bool _asking = false;
  Stream<GpsView>? _stream;

  @override
  bool get wantKeepAlive => true;

  Future<void> _start() async {
    track(AppEvent.gpsStarted);
    setState(() => _asking = true);
    // 1. FUTURE: izin bir kez sorulur.
    final access = await _source.requestAccess();
    if (!mounted) return;
    setState(() {
      _asking = false;
      _access = access;
      // 2. STREAM: izin varsa konum akışı başlar.
      if (access == LocationAccess.granted) {
        _stream = collectGps(_source.positions());
      }
    });
  }

  // Akış null olunca StreamBuilder aboneliği bırakır, GPS durur.
  void _stop() {
    track(AppEvent.gpsStopped);
    setState(() => _stream = null);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final t = Theme.of(context).textTheme;
    final access = _access;
    final running = _stream != null;
    // Tembel liste ekrandan çıkan kartı yok eder; yeniden kurulan
    // StreamBuilder aynı akışı ikinci kez dinleyemez. Kartlar canlı kalsın.
    return SingleChildScrollView(
      key: const Key('gps_list'),
      padding: pagePadding(context).copyWith(top: 16, bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Konum yalnızca bu ekranda gösterilir; kaydedilmez, hiçbir yere '
            'gönderilmez.',
            style: t.bodyMedium,
          ),
          const Gap(12),
          const CodeBox('''
final izin = await source.requestAccess();   // Future
StreamBuilder<GpsFix>(
  stream: source.positions(),                 // Stream
  builder: (context, snap) => Text('\${snap.data?.latitude}'),
)'''),
          const Gap(12),
          if (access != null && access != LocationAccess.granted)
            _AccessProblem(
              access: access,
              onSettings: () => _source.openSettings(access),
            ),
          if (running)
            OutlinedButton.icon(
              key: const Key('gps_stop'),
              onPressed: _stop,
              icon: const Icon(Icons.stop_rounded),
              label: const Text('Durdur'),
            )
          else
            FilledButton.icon(
              key: const Key('gps_start'),
              onPressed: _asking ? null : _start,
              icon: const Icon(Icons.my_location_rounded),
              label: Text(_asking ? 'İzin bekleniyor…' : 'Canlı konumu başlat'),
            ),
          const Gap(16),
          StreamBuilder<GpsView>(
            stream: _stream,
            builder: (context, snapshot) {
              final v = snapshot.data;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ConnectionChip(snapshot.connectionState),
                  ),
                  const Gap(10),
                  if (snapshot.hasError)
                    Text(
                      'Konum alınamadı: ${snapshot.error}',
                      style: t.bodyMedium?.copyWith(color: MfColors.red600),
                    )
                  else if (v == null && running)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Column(
                        children: [
                          CircularProgressIndicator(),
                          Gap(10),
                          Text('GPS uydu arıyor… (açık havada daha hızlı)'),
                        ],
                      ),
                    )
                  else if (v != null) ...[
                    _Readings(v),
                    const Gap(12),
                    _TrackCard(v),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AccessProblem extends StatelessWidget {
  const _AccessProblem({required this.access, required this.onSettings});

  final LocationAccess access;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      key: const Key('gps_access'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_off_rounded, color: MfColors.red600),
          const SizedBox(width: 10),
          Expanded(child: Text(access.label, style: t.titleSmall)),
          if (access != LocationAccess.denied)
            TextButton(onPressed: onSettings, child: const Text('Ayarları aç')),
        ],
      ),
    );
  }
}

class _Readings extends StatelessWidget {
  const _Readings(this.view);

  final GpsView view;

  @override
  Widget build(BuildContext context) {
    final f = view.last;
    String two(int n) => n.toString().padLeft(2, '0');
    final time =
        '${two(f.time.hour)}:${two(f.time.minute)}:${two(f.time.second)}';
    final cells = [
      ('Enlem', f.latitude.toStringAsFixed(6), Icons.swap_vert_rounded),
      ('Boylam', f.longitude.toStringAsFixed(6), Icons.swap_horiz_rounded),
      ('Doğruluk', '± ${f.accuracy.toStringAsFixed(1)} m', Icons.gps_fixed),
      (
        'Hız',
        '${(f.speed * 3.6).toStringAsFixed(1)} km/sa',
        Icons.speed_rounded,
      ),
      ('Yön', '${f.heading.toStringAsFixed(0)}°', Icons.explore_rounded),
      (
        'Yükseklik',
        '${f.altitude.toStringAsFixed(1)} m',
        Icons.terrain_rounded,
      ),
      ('Ölçüm', '${view.count}', Icons.numbers_rounded),
      ('Son ölçüm', time, Icons.schedule_rounded),
    ];
    final t = Theme.of(context).textTheme;
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.4,
      children: [
        for (final (label, value, icon) in cells)
          Container(
            key: Key('gps_$label'),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: MfColors.slate200),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: MfColors.blue600),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: t.bodySmall),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          value,
                          style: t.titleSmall?.copyWith(
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
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
  }
}

class _TrackCard extends StatelessWidget {
  const _TrackCard(this.view);

  final GpsView view;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('İz (yukarısı kuzey)', style: t.titleSmall)),
              Text(
                'Mesafe: ${view.distance.toStringAsFixed(1)} m',
                key: const Key('gps_distance'),
                style: t.titleSmall,
              ),
            ],
          ),
          const Gap(10),
          AspectRatio(
            aspectRatio: 1,
            child: CustomPaint(painter: _TrackPainter(view.track)),
          ),
          const Gap(6),
          Text(
            'Mavi daire GPS doğruluğudur: gerçek konum büyük olasılıkla bu '
            'dairenin içindedir. Yürüdükçe iz uzar.',
            style: t.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// Konumları, ilk noktaya göre metre cinsinden düzleme çizer.
class _TrackPainter extends CustomPainter {
  _TrackPainter(this.track);

  final List<GpsFix> track;

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = MfColors.slate50;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12)),
      bg,
    );
    if (track.isEmpty) return;
    final origin = track.first;
    // Küçük alanlarda Dünya düz sayılabilir: 1° enlem ≈ 110,5 km,
    // 1° boylam ≈ 111,3 km × cos(enlem).
    Offset meters(GpsFix f) => Offset(
      (f.longitude - origin.longitude) *
          111320 *
          cos(origin.latitude * pi / 180),
      -(f.latitude - origin.latitude) * 110540,
    );
    final points = [for (final f in track) meters(f)];
    final last = track.last;
    var extent = last.accuracy * 2;
    for (final p in points) {
      extent = max(extent, max(p.dx.abs(), p.dy.abs()) * 2.4);
    }
    extent = max(extent, 20);
    final scale = size.shortestSide / extent;
    final center = size.center(Offset.zero);
    Offset screen(Offset m) => center + m * scale;

    // Izgara: her çizgi arası metre cinsinden yazılır.
    final grid = Paint()
      ..color = MfColors.slate200
      ..strokeWidth = 1;
    for (var i = 1; i < 4; i++) {
      final d = size.width * i / 4;
      canvas
        ..drawLine(Offset(d, 0), Offset(d, size.height), grid)
        ..drawLine(Offset(0, d), Offset(size.width, d), grid);
    }

    final current = screen(points.last);
    canvas.drawCircle(
      current,
      last.accuracy * scale,
      Paint()..color = MfColors.blue600.withValues(alpha: 0.12),
    );
    if (points.length > 1) {
      final path = Path()
        ..moveTo(screen(points.first).dx, screen(points.first).dy);
      for (final p in points.skip(1)) {
        final s = screen(p);
        path.lineTo(s.dx, s.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeJoin = StrokeJoin.round
          ..color = MfColors.blue600,
      );
    }
    canvas
      ..drawCircle(
        screen(points.first),
        5,
        Paint()..color = MfColors.emerald500,
      )
      ..drawCircle(current, 7, Paint()..color = Colors.white)
      ..drawCircle(current, 5, Paint()..color = MfColors.blue600);

    final label = TextPainter(
      text: TextSpan(
        text: 'kare ≈ ${(extent / 4).toStringAsFixed(0)} m',
        style: const TextStyle(color: MfColors.slate500, fontSize: 11),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    label.paint(canvas, Offset(8, size.height - label.height - 6));
  }

  @override
  bool shouldRepaint(_TrackPainter old) => old.track != track;
}
