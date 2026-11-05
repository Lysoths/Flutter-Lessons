import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_ders/app/app.dart';
import 'package:flutter_ders/app/core/device/location_source.dart';
import 'package:flutter_ders/app/core/device/sensor_source.dart';
import 'package:flutter_ders/app/core/di/injection.dart';
import 'package:flutter_ders/app/core/router/app_deep_links.dart';
import 'package:flutter_ders/app/views/view_device/widgets/gps_panel.dart';
import 'package:flutter_ders/app/views/view_device/widgets/sensors_panel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/lessons.dart';

/// Elle konum gönderilebilen sahte GPS.
class _FakeLocation implements LocationSource {
  _FakeLocation(this.access);

  final LocationAccess access;
  final positions_ = StreamController<GpsFix>.broadcast();

  @override
  Future<LocationAccess> requestAccess() async => access;

  @override
  Stream<GpsFix> positions() => positions_.stream;

  @override
  Future<void> openSettings(LocationAccess access) async {}
}

/// Elle ölçüm gönderilebilen sahte sensörler.
class _FakeSensors implements SensorSource {
  final accel = StreamController<SensorReading>.broadcast();
  final user = StreamController<SensorReading>.broadcast();
  final gyro = StreamController<SensorReading>.broadcast();
  final magnet = StreamController<SensorReading>.broadcast();

  @override
  Stream<SensorReading> accelerometer() => accel.stream;

  @override
  Stream<SensorReading> userAccelerometer() => user.stream;

  @override
  Stream<SensorReading> gyroscope() => gyro.stream;

  @override
  Stream<SensorReading> magnetometer() => magnet.stream;
}

GpsFix fix(double lat, double lon, {double accuracy = 4, int second = 0}) => (
  latitude: lat,
  longitude: lon,
  accuracy: accuracy,
  altitude: 40,
  speed: 1.5,
  heading: 90,
  time: DateTime(2026, 11, 3, 12, 0, second),
);

SensorReading reading(double x, double y, double z, [int ms = 0]) =>
    (x: x, y: y, z: z, time: DateTime(2026).add(Duration(milliseconds: ms)));

// DERS 12 — GPS ve sensörler.
void main() {
  group('hesaplar', () {
    test('1° enlem ≈ 111 km (haversine)', () {
      expect(distanceMeters(41, 29, 42, 29), closeTo(111195, 50));
      expect(distanceMeters(41, 29, 41, 29), 0);
    });

    test('iz: mesafe birikir, yerinde titreme sayılmaz', () async {
      final views = await collectGps(
        Stream.fromIterable([
          fix(41, 29),
          fix(41.0000101, 29, accuracy: 10), // ~1 m: titreme
          fix(41.0010, 29), // ~110 m yürüdü
        ]),
      ).toList();
      expect(views.last.count, 3);
      expect(views.last.track, hasLength(3));
      expect(views[1].distance, 0);
      expect(views.last.distance, closeTo(110, 2));
    });

    test('pusula: telefonun üstü kuzey = 0°, doğu = 90°', () {
      // Alan telefonun üstünü gösteriyor → üst kuzeyde.
      expect(compassHeading(0, 30), closeTo(0, 0.01));
      // Alan telefonun soluna → kuzey solda → üst doğuya bakıyor.
      expect(compassHeading(-30, 0), closeTo(90, 0.01));
      expect(compassHeading(30, 0), closeTo(270, 0.01));
    });

    test('sallama: eşik aşılınca sayılır, arka arkaya sayılmaz', () async {
      final result = await countShakes(
        Stream.fromIterable([
          reading(0, 0, 1),
          reading(15, 0, 0, 100), // sallama 1
          reading(16, 0, 0, 200), // 600 ms dolmadı
          reading(15, 0, 0, 900), // sallama 2
        ]),
      ).toList();
      expect(result.map((r) => r.shakes), [0, 1, 1, 2]);
    });

    test('ölçüm hızı zaman damgalarından hesaplanır', () async {
      final views = await collectSensor(
        Stream.fromIterable([
          for (var i = 0; i < 11; i++) reading(0, 0, 9.8, i * 10),
        ]),
      ).toList();
      expect(views.last.hz, closeTo(100, 0.1));
      expect(views.last.history, hasLength(11));
    });

    test('sayfa deep link ile açılamaz', () {
      expect(
        AppDeepLinks.sanitize(Uri.parse('harcamatakibim://app/konum-sensor'))
            .path,
        '/',
      );
    });
  });

  group('ekranda', () {
    late _FakeSensors sensors;

    Future<void> open(WidgetTester tester, LocationSource location) async {
      await getIt.reset();
      SharedPreferences.setMockInitialValues({});
      await configureDependencies();
      sensors = _FakeSensors();
      getIt
        ..unregister<LocationSource>()
        ..registerSingleton<LocationSource>(location)
        ..unregister<SensorSource>()
        ..registerSingleton<SensorSource>(sensors);
      tester.view.physicalSize = const Size(1440, 3120);
      tester.view.devicePixelRatio = 3.75;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const HarcamaApp(watchNetwork: false));
      await tester.pumpAndSettle();
      await openLessonsHub(tester);
      final card = find.byKey(const Key('lessons_device'));
      await tester.scrollUntilVisible(
        card,
        200,
        scrollable: find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .first,
      );
      await tester.tapAt(tester.getTopLeft(card) + const Offset(24, 24));
      await tester.pumpAndSettle();
    }

    testWidgets('GPS: izin, canlı konum ve iz', (tester) async {
      final location = _FakeLocation(LocationAccess.granted);
      await open(tester, location);

      await tester.tap(find.byKey(const Key('gps_start')));
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('uydu arıyor'), findsOneWidget);

      location.positions_.add(fix(41.008238, 28.978359));
      await tester.pump();
      location.positions_.add(fix(41.009238, 28.978359, second: 5));
      await tester.pump();
      expect(find.text('41.009238'), findsOneWidget);
      expect(find.text('2'), findsOneWidget); // ölçüm sayısı

      await tester.tap(find.byKey(const Key('gps_stop')));
      await tester.pump();
      expect(find.byKey(const Key('gps_start')), findsOneWidget);
    });

    testWidgets('GPS: izin yoksa ayarlara yönlendirir', (tester) async {
      await open(tester, _FakeLocation(LocationAccess.deniedForever));
      await tester.tap(find.byKey(const Key('gps_start')));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('gps_access')), findsOneWidget);
      expect(find.text('Ayarları aç'), findsOneWidget);
    });

    testWidgets('sensörler: terazi, pusula ve sallama canlı güncellenir', (
      tester,
    ) async {
      await open(tester, _FakeLocation(LocationAccess.granted));
      await tester.tap(find.byKey(const Key('device_tabSensors')));
      // Veri beklenirken ilerleme çubuğu döner; pumpAndSettle bitmez.
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      sensors.accel.add(reading(0, 0, 9.8));
      await tester.pump();
      expect(find.text('Düz ✓'), findsOneWidget);

      sensors.accel.add(reading(4, 0, 8.9, 16));
      await tester.pump();
      expect(find.text('Eğik'), findsOneWidget);

      final list = find
          .descendant(
            of: find.byKey(const Key('sensors_list')),
            matching: find.byType(Scrollable),
          )
          .first;
      // Kart ekrandayken ölçüm gönderilir (akış yayın türünde).
      await tester.scrollUntilVisible(
        find.text('Pusula · manyetometre'),
        300,
        scrollable: list,
      );
      sensors.magnet.add(reading(-30, 0, -20));
      await tester.pump();
      expect(find.text('90° D'), findsOneWidget);

      final shakes = find.byKey(const Key('sensors_shakes'));
      await tester.scrollUntilVisible(shakes, 300, scrollable: list);
      sensors.user.add(reading(14, 0, 0, 100));
      await tester.pump();
      expect(tester.widget<Text>(shakes).data, 'Sallama: 1');
    });
  });
}
