import 'package:flutter/material.dart';
import 'package:flutter_ders/app/core/di/injection.dart';
import 'package:flutter_ders/app/core/hardware/hardware_profile.dart';
import 'package:flutter_ders/app/core/hardware/hardware_source.dart';
import 'package:flutter_ders/app/views/view_hardware/cubit/hardware_cubit.dart';
import 'package:flutter_ders/app/views/view_hardware/hardware_format.dart';
import 'package:flutter_ders/app/views/view_hardware/hardware_view.dart';
import 'package:flutter_test/flutter_test.dart';

// Kotlin'deki HardwareChannel.profile()'ın döndürdüğü biçim (sözleşme).
// Değerler uydurmadır. Kotlin Long'u Dart'ta int, Float'u double gelir.
Map<String, Object?> _profileMap() => {
  'kimlik': {
    'uretici': 'samsung',
    'marka': 'samsung',
    'model': 'SM-S938B',
    'cihaz': 'pa3q',
    'urun': 'pa3qxeea',
    'donanim': 'qcom',
    'kart': 'sun',
    'androidId': '0123456789abcdef',
  },
  'sistem': {
    'surum': '16',
    'sdk': 36,
    'yama': '2026-10-01',
    'derleme': 'BP2A.250605.031',
    'parmakIzi': 'samsung/pa3qxeea/pa3q:16/BP2A/S938BXXU5:user/release-keys',
    'bootloader': 'S938BXXU5',
    'cekirdek': '6.6.30-android15',
    'derlemeZamani': DateTime(2026, 9, 20).millisecondsSinceEpoch,
    'acikKalma': const Duration(days: 2, hours: 4).inMilliseconds,
    'dil': 'tr-TR',
    'saatDilimi': 'Europe/Istanbul',
  },
  'islemci': {
    'cekirdekSayisi': 8,
    'abiler': ['arm64-v8a'],
    'socUretici': 'Qualcomm',
    'socModel': 'SM8750',
    'enYuksekKhz': [
      3532800,
      3532800,
      3532800,
      3532800,
      3532800,
      3532800,
      4473600,
      4473600,
    ],
    'enDusukKhz': [384000, 384000, 384000, 384000, 384000, 384000, null, null],
  },
  'bellek': {
    'toplam': 12 * 1024 * 1024 * 1024,
    'bos': 4 * 1024 * 1024 * 1024,
    'esik': 226492416,
    'dusuk': false,
    'uygulamaSiniriMb': 256,
  },
  'depolama': {
    'toplam': 256 * 1024 * 1024 * 1024,
    'bos': 120 * 1024 * 1024 * 1024,
  },
  'pil': {
    'yuzde': 81,
    'durum': 'desarj',
    'saglik': 'iyi',
    'kaynak': null,
    'sicaklik': 31.5,
    'voltajMv': 4120,
    'teknoloji': 'Li-ion',
    'dongu': 212,
    'sarjMah': 3880,
    'akimUa': -412000,
  },
  'ekran': {
    'genislik': 1440,
    'yukseklik': 3120,
    'dpi': 600,
    'xdpi': 500.0,
    'ydpi': 500.0,
    'yenileme': 120.0,
    'yenilemeler': [60.0, 120.0],
    'hdr': ['HDR10', 'HDR10+'],
    'yaziOlcegi': 1.0,
  },
  'kameralar': [
    {
      'id': '0',
      'yon': 'arka',
      'megapiksel': 200.0,
      'odakUzakliklari': [6.3],
      'flas': true,
      'ois': true,
    },
    {
      'id': '1',
      'yon': 'on',
      'megapiksel': 12.0,
      'odakUzakliklari': <double>[],
      'flas': false,
      'ois': false,
    },
  ],
  'sensorler': [
    {
      'ad': 'LSM6DSV Accelerometer',
      'uretici': 'STMicro',
      'tur': 'android.sensor.accelerometer',
      'gucMa': 0.15,
      'aralik': 78.4,
      'uyandirir': false,
    },
    {
      'ad': 'Step Counter',
      'uretici': 'Samsung',
      'tur': 'android.sensor.step_counter',
      'gucMa': 0.01,
      'aralik': 1000000.0,
      'uyandirir': true,
    },
  ],
  'ozellikler': {'nfc': true, 'uwb': true, 'kizilotesi': false, 'esim': true},
  'telefon': {
    'var': true,
    'izin': false,
    'operator': 'Turkcell',
    'simOperator': 'Turkcell',
    'simUlke': 'TR',
    'agUlke': 'TR',
    'dolasim': false,
    'yuva': 2,
    'aktifSim': 1,
    'ag': '5G',
    'tur': 'GSM',
  },
};

void main() {
  group('kanal sözleşmesi', () {
    test('Kotlin haritası tipli profile çevrilir', () {
      final p = DeviceProfile.fromChannel(_profileMap());
      expect(p.identity.title, 'Samsung SM-S938B');
      expect(p.system.sdk, 36);
      expect(p.system.uptime, const Duration(days: 2, hours: 4));
      expect(p.cpu.cores, 8);
      expect(p.cpu.clusters, [
        (count: 2, khz: 4473600),
        (count: 6, khz: 3532800),
      ]);
      expect(formatClusters(p.cpu), '2 × 4,47 GHz + 6 × 3,53 GHz');
      expect(p.memory.total, 12 * 1024 * 1024 * 1024);
      expect(p.battery.temperature, 31.5);
      expect(p.battery.cycles, 212);
      expect(p.display.diagonalInches, closeTo(6.87, 0.01));
      expect(p.cameras.map((c) => c.facing), ['arka', 'on']);
      expect(p.sensors.last.shortType, 'step_counter');
      expect(p.features['nfc'], isTrue);
      expect(p.telephony.operatorName, 'Turkcell');
    });

    test('eksik ya da yanlış tipli alanlar uygulamayı çökertmez', () {
      final p = DeviceProfile.fromChannel({
        'kimlik': 'bozuk',
        'islemci': {
          'cekirdekSayisi': '8',
          'enYuksekKhz': [null, 'x', 1800000],
        },
        'kameralar': [42, null],
        'ozellikler': {'nfc': 'evet', 'uwb': true, 7: true},
      });
      expect(p.identity.title, '');
      expect(p.cpu.cores, 0);
      expect(p.cpu.maxKhz, [null, null, 1800000]);
      expect(p.cpu.peakKhz, 1800000);
      expect(p.cameras, hasLength(2));
      expect(p.cameras.first.id, '?');
      expect(p.features, {'uwb': true});
      expect(p.display.diagonalInches, isNull);
      expect(DeviceProfile.fromChannel(null).sensors, isEmpty);
    });

    test('canlı ölçüm', () {
      expect(LiveReading.fromChannel({'pil': 50}), isNull);
      final r = LiveReading.fromChannel({
        'zaman': 1000,
        'pil': 80,
        'sicaklik': 30.2,
        'akimUa': -350000,
        'sarjOluyor': false,
        'bosRam': 1024,
        'anlikKhz': [1200000, null],
      })!;
      expect(r.battery, 80);
      expect(r.coreKhz, [1200000, null]);
    });

    test('profil log\'a kimlik yazmaz', () {
      final text = DeviceProfile.fromChannel(_profileMap()).toString();
      expect(text, isNot(contains('0123456789abcdef')));
      expect(text, isNot(contains('Turkcell')));
    });
  });

  group('biçimler', () {
    test('frekans, süre, akım, kimlik maskesi', () {
      expect(formatKhz(4473600), '4,47 GHz');
      expect(formatKhz(960000), '960 MHz');
      expect(formatUptime(const Duration(days: 2, hours: 4)), '2 gün 4 sa');
      expect(formatUptime(const Duration(hours: 3, minutes: 12)), '3 sa 12 dk');
      expect(formatUptime(const Duration(minutes: 8)), '8 dk');
      expect(formatCurrent(-412000), '-412 mA');
      expect(formatDecimal(120), '120');
      expect(formatDecimal(6.87), '6,9');
      expect(maskId('0123456789abcdef'), '0123••••••••cdef');
    });

    test('IMEI açıklaması', () {
      final text = imeiExplanation(
        const ImeiBlocked(code: 'sistem_izni', sdk: 36),
      );
      expect(text, contains('Android 10'));
      expect(text, contains('API 36'));
      expect(text, contains('*#06#'));
    });
  });

  group('cubit', () {
    late MemoryHardwareSource source;
    late HardwareCubit cubit;

    setUp(() {
      source = MemoryHardwareSource(profileMap: _profileMap());
      cubit = HardwareCubit(source: source);
    });

    tearDown(() => cubit.close());

    test(
      'profil okunur, canlı ölçüm dinlenir, geçmiş 30 ile sınırlı',
      () async {
        await cubit.init();
        expect(cubit.state.status, HardwareStatus.ready);
        expect(source.listening, isTrue);
        for (var i = 0; i < 35; i++) {
          source.emit(LiveReading(time: DateTime(2026), currentUa: -i * 1000));
        }
        await Future<void>.delayed(Duration.zero);
        expect(
          cubit.state.currentHistory,
          hasLength(HardwareState.historyLength),
        );
        expect(cubit.state.currentHistory.last, -34);
        expect(cubit.state.toString(), isNot(contains('SM-S938B')));

        await cubit.close();
        expect(source.listening, isFalse);
      },
    );

    test('IMEI engeli bir sonuç olarak gelir', () async {
      await cubit.init();
      await cubit.tryImei();
      expect(cubit.state.imei, isA<ImeiBlocked>());
      expect(cubit.state.imeiBusy, isFalse);
    });

    test('telefon izni verilince profil yenilenir', () async {
      await cubit.init();
      expect(cubit.state.profile!.telephony.granted, isFalse);
      await cubit.requestPhoneAccess();
      expect(source.reads, 2);
      expect(cubit.state.profile!.telephony.granted, isTrue);
    });

    test('platform yoksa', () async {
      final c = HardwareCubit(source: _UnsupportedSource());
      await c.init();
      expect(c.state.status, HardwareStatus.unsupported);
      await c.close();
    });
  });

  group('ekran', () {
    late MemoryHardwareSource source;

    setUp(() async {
      await getIt.reset();
      source = MemoryHardwareSource(profileMap: _profileMap());
      getIt.registerSingleton<HardwareSource>(source);
    });

    tearDown(getIt.reset);

    Future<void> pumpView(WidgetTester tester) async {
      tester.view
        ..physicalSize = const Size(1440, 3120)
        ..devicePixelRatio = 3.75;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MaterialApp(home: HardwareView()));
      await tester.pumpAndSettle();
    }

    // Liste tembel (lazy) ve uzun: öğe henüz kurulmadıysa kurulana kadar
    // kaydırılır, sonra tam görünür yapılıp dokunulur.
    Future<void> tapKey(WidgetTester tester, String key) async {
      final f = find.byKey(Key(key));
      if (f.evaluate().isEmpty) {
        await tester.scrollUntilVisible(
          f,
          200,
          scrollable: find.descendant(
            of: find.byKey(const Key('hardware_list')),
            matching: find.byType(Scrollable),
          ),
        );
      }
      await tester.ensureVisible(f);
      await tester.pumpAndSettle();
      await tester.tap(f);
      await tester.pumpAndSettle();
    }

    Future<void> open(WidgetTester tester, String id) =>
        tapKey(tester, 'hardware_section_$id');

    testWidgets('kimlik: Android ID gizli, IMEI denemesi açıklanır', (
      tester,
    ) async {
      await pumpView(tester);
      expect(find.text('Samsung SM-S938B'), findsOneWidget);
      expect(find.text('0123••••••••cdef'), findsOneWidget);
      expect(find.text('0123456789abcdef'), findsNothing);

      await tapKey(tester, 'hardware_reveal_id');
      expect(find.text('0123456789abcdef'), findsOneWidget);

      await tapKey(tester, 'hardware_imei_try');
      expect(find.textContaining('*#06#'), findsOneWidget);
    });

    testWidgets('canlı kart saniyede bir güncellenir', (tester) async {
      await pumpView(tester);
      source.emit(
        LiveReading(
          time: DateTime(2026),
          battery: 77,
          temperature: 33,
          currentUa: -500000,
          freeRam: 3 * 1024 * 1024 * 1024,
          coreKhz: const [1000000, null, 2000000],
        ),
      );
      await tester.pumpAndSettle();
      Text text(String key) => tester.widget<Text>(find.byKey(Key(key)));
      expect(text('hardware_live_battery').data, '%77');
      expect(text('hardware_live_temp').data, '33 °C');
      expect(text('hardware_live_current').data, '-500 mA');
      expect(text('hardware_live_ram').data, '3,00 GB');
    });

    testWidgets('bölümler açılır; SIM izni verilince ağ türü görünür', (
      tester,
    ) async {
      await pumpView(tester);
      await open(tester, 'cpu');
      expect(find.text('2 × 4,47 GHz + 6 × 3,53 GHz'), findsOneWidget);

      await open(tester, 'phone');
      expect(find.text('Turkcell'), findsWidgets);
      expect(find.text('5G'), findsNothing);
      await tapKey(tester, 'hardware_phone_allow');
      expect(find.text('5G'), findsWidgets);
      expect(find.byKey(const Key('hardware_phone_allow')), findsNothing);
    });
  });
}

class _UnsupportedSource implements HardwareSource {
  @override
  Future<DeviceProfile> profile() => throw const HardwareUnsupported();

  @override
  Future<ImeiResult> imei() async => const ImeiBlocked(code: 'platform');

  @override
  Future<bool> phoneAccess() async => false;

  @override
  Future<bool> requestPhoneAccess() async => false;

  @override
  Stream<LiveReading> live() => const Stream.empty();
}
