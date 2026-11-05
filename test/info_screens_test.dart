import 'dart:async';
import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ders/app/app.dart';
import 'package:flutter_ders/app/core/device/device_info_source.dart';
import 'package:flutter_ders/app/core/device/location_source.dart';
import 'package:flutter_ders/app/core/di/injection.dart';
import 'package:flutter_ders/app/core/repository/app_info_repository.dart';
import 'package:flutter_ders/app/core/repository/network_info_repository.dart';
import 'package:flutter_ders/app/core/repository/rates_repository.dart';
import 'package:flutter_ders/app/models/cloudflare_trace.dart';
import 'package:flutter_ders/app/models/info_section.dart';
import 'package:flutter_ders/app/views/view_app_network/bloc/network_info_bloc.dart';
import 'package:flutter_ders/app/views/view_app_network/bloc/network_info_event.dart';
import 'package:flutter_ders/app/views/view_app_network/bloc/network_info_state.dart';
import 'package:flutter_ders/app/views/view_device_info/bloc/device_info_bloc.dart';
import 'package:flutter_ders/app/views/view_device_info/bloc/device_info_event.dart';
import 'package:flutter_ders/app/views/view_device_info/bloc/device_info_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/lessons.dart';

// Belgelerde örnek için ayrılmış adresler (RFC 5737), gerçek değil.
const _body = '''
fl=12ab34
h=1.1.1.1
ip=203.0.113.7
ts=1730700000.250
visit_scheme=https
uag=Dart/3.13 (dart:io)
colo=IST
sliver=none
http=http/1.1
loc=TR
tls=TLSv1.3
sni=off
warp=off
gateway=off
rbi=off
kex=X25519
yeni_alan=deneme
''';

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.respond);

  final ResponseBody Function(RequestOptions options) respond;
  final requests = <Uri>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options.uri);
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

const _report = (
  sections: [
    InfoSection(
      id: 'identity',
      title: 'Kimlik',
      entries: [InfoEntry('Model', 'Deneme X1')],
    ),
  ],
  systemFeatures: ['android.hardware.nfc', 'android.hardware.camera'],
  raw: <String, Object?>{'model': 'Deneme X1'},
);

class _FakeDevice implements DeviceInfoSource {
  bool fail = false;

  @override
  Future<DeviceInfoReport> read() async =>
      fail ? throw Exception('kanal yok') : _report;
}

class _FakeApp implements AppInfoRepository {
  @override
  Future<List<InfoSection>> read() async => const [
    InfoSection(
      id: 'app',
      title: 'Uygulama',
      entries: [InfoEntry('Sürüm', '1.0.0')],
    ),
  ];
}

class _FakeLocal implements LocalNetworkSource {
  final controller = StreamController<List<ConnectivityResult>>.broadcast();
  int reads = 0;

  @override
  Stream<List<ConnectivityResult>> changes() => controller.stream;

  @override
  Future<LocalNetworkReport> read() async {
    reads++;
    return (
      connection: const [ConnectivityResult.wifi],
      sections: const [
        InfoSection(
          id: 'wifi',
          title: 'Wi-Fi',
          entries: [
            InfoEntry(kSsidLabel, '—', sensitive: true),
            InfoEntry('Yerel IPv4', '192.0.2.10', sensitive: true),
          ],
        ),
      ],
    );
  }
}

class _FakeTrace implements TraceRepository {
  bool fail = false;
  int calls = 0;

  @override
  Future<CloudflareTrace> fetch() async {
    calls++;
    if (fail) throw const TraceFailure('İnternete bağlanılamadı.');
    return CloudflareTrace.parse(_body);
  }
}

class _FakeLocation implements LocationSource {
  int asks = 0;

  @override
  Future<LocationAccess> requestAccess() async {
    asks++;
    return LocationAccess.granted;
  }

  @override
  Stream<GpsFix> positions() => const Stream.empty();

  @override
  Future<void> openSettings(LocationAccess access) async {}
}

void main() {
  group('CloudflareTrace', () {
    test('anahtar=değer satırlarını ayrıştırır', () {
      final t = CloudflareTrace.parse(_body);
      expect(t.ip, '203.0.113.7');
      expect(t.isIpv6, isFalse);
      expect(t.colo, 'IST');
      expect(t.loc, 'TR');
      expect(t.serverTime?.millisecondsSinceEpoch, 1730700000250);
      expect(CloudflareTrace.parse('ip=2001:db8::1').isIpv6, isTrue);
    });

    test('bölümler: IP hassas, bilinmeyen alan kaybolmaz', () {
      final sections = CloudflareTrace.parse(_body).toSections();
      final all = sections.expand((s) => s.entries).toList();
      final ip = all.firstWhere((e) => e.label == 'Genel IP');
      expect(ip.value, '203.0.113.7');
      expect(ip.sensitive, isTrue);
      expect(
        all.firstWhere((e) => e.label == 'Veri merkezi (colo)').value,
        'IST · İstanbul',
      );
      expect(all.any((e) => e.label == 'yeni_alan'), isTrue);
    });

    test('toString IP içermez', () {
      expect(CloudflareTrace.parse(_body).toString(), isNot(contains('203.')));
    });
  });

  group('CloudflareTraceRepository', () {
    test('1.1.1.1/cdn-cgi/trace adresine düz metin isteği atar', () async {
      final adapter = _FakeAdapter(
        (_) => ResponseBody.fromString(
          _body,
          200,
          headers: {
            Headers.contentTypeHeader: ['text/plain'],
          },
        ),
      );
      final dio = createDio()..httpClientAdapter = adapter;
      final trace = await CloudflareTraceRepository(dio).fetch();
      expect(adapter.requests.single.toString(), CloudflareTraceRepository.url);
      expect(trace.colo, 'IST');
    });

    test('bağlantı hatası Türkçe TraceFailure olur', () async {
      final dio = createDio()
        ..httpClientAdapter = _FakeAdapter(
          (o) => throw DioException.connectionError(
            requestOptions: o,
            reason: 'yok',
          ),
        );
      await expectLater(
        CloudflareTraceRepository(dio).fetch(),
        throwsA(
          isA<TraceFailure>().having(
            (e) => e.message,
            'message',
            'İnternete bağlanılamadı.',
          ),
        ),
      );
    });
  });

  group('DeviceInfoBloc', () {
    blocTest<DeviceInfoBloc, DeviceInfoState>(
      'Requested → Loading, Loaded (alan sayısı)',
      build: () => DeviceInfoBloc(source: _FakeDevice()),
      act: (b) => b.add(const DeviceInfoRequested()),
      expect: () => [
        isA<DeviceInfoLoading>(),
        isA<DeviceInfoLoaded>().having((s) => s.fieldCount, 'fieldCount', 3),
      ],
    );

    blocTest<DeviceInfoBloc, DeviceInfoState>(
      'okuma hatası → DeviceInfoError',
      build: () => DeviceInfoBloc(source: _FakeDevice()..fail = true),
      act: (b) => b.add(const DeviceInfoRequested()),
      expect: () => [isA<DeviceInfoLoading>(), isA<DeviceInfoError>()],
    );
  });

  group('NetworkInfoBloc', () {
    late _FakeLocal local;
    late _FakeTrace trace;
    late _FakeLocation location;

    setUp(() {
      local = _FakeLocal();
      trace = _FakeTrace();
      location = _FakeLocation();
    });

    NetworkInfoBloc build() =>
        NetworkInfoBloc(local: local, trace: trace, location: location);

    blocTest<NetworkInfoBloc, NetworkInfoState>(
      'Started → yerel bilgi ve trace hazır',
      build: build,
      act: (b) => b.add(const NetworkInfoStarted()),
      verify: (b) {
        final s = b.state;
        expect(s.localStatus, PartStatus.ready);
        expect(s.traceStatus, PartStatus.ready);
        expect(s.connection, [ConnectivityResult.wifi]);
        expect(s.trace?.colo, 'IST');
        expect(s.traceLatency, isNotNull);
        expect(s.wifiNameMissing, isTrue);
        // Konsola yazılan özet IP içermez.
        expect(s.toString(), isNot(contains('203.')));
        expect(s.toString(), isNot(contains('192.')));
      },
    );

    blocTest<NetworkInfoBloc, NetworkInfoState>(
      'trace hatası yalnızca trace parçasını etkiler',
      build: () {
        trace.fail = true;
        return build();
      },
      act: (b) => b.add(const NetworkInfoStarted()),
      verify: (b) {
        expect(b.state.localStatus, PartStatus.ready);
        expect(b.state.traceStatus, PartStatus.failure);
        expect(b.state.traceError, 'İnternete bağlanılamadı.');
      },
    );

    blocTest<NetworkInfoBloc, NetworkInfoState>(
      'bağlantı değişince kendiliğinden yeniden okur',
      build: build,
      act: (b) async {
        b.add(const NetworkInfoStarted());
        await Future<void>.delayed(Duration.zero);
        // İlk değer atlanır (şu anki bağlantı), ikincisi değişikliktir.
        local.controller
          ..add([ConnectivityResult.wifi])
          ..add([ConnectivityResult.mobile]);
      },
      wait: const Duration(seconds: 1),
      verify: (b) {
        expect(b.state.connectionChanges, 1);
        expect(trace.calls, 2);
        expect(local.reads, 2);
      },
    );

    blocTest<NetworkInfoBloc, NetworkInfoState>(
      'Wi-Fi izni istenir ve yerel bilgi yeniden okunur',
      build: build,
      act: (b) => b.add(const NetworkWifiAccessRequested()),
      verify: (b) {
        expect(location.asks, 1);
        expect(b.state.wifiAccess, LocationAccess.granted);
        expect(local.reads, 1);
      },
    );
  });

  group('sayfalar', () {
    setUp(() async {
      await getIt.reset();
      SharedPreferences.setMockInitialValues({});
      await configureDependencies();
      getIt
        ..unregister<DeviceInfoSource>()
        ..registerSingleton<DeviceInfoSource>(_FakeDevice())
        ..unregister<AppInfoRepository>()
        ..registerSingleton<AppInfoRepository>(_FakeApp())
        ..unregister<LocalNetworkSource>()
        ..registerSingleton<LocalNetworkSource>(_FakeLocal())
        ..unregister<TraceRepository>()
        ..registerSingleton<TraceRepository>(_FakeTrace())
        ..unregister<LocationSource>()
        ..registerSingleton<LocationSource>(_FakeLocation());
    });

    Future<void> open(WidgetTester tester, String key) async {
      tester.view.physicalSize = const Size(1440, 3120);
      tester.view.devicePixelRatio = 3.75;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const HarcamaApp(watchNetwork: false));
      await tester.pumpAndSettle();
      await openLessonsHub(tester);
      final card = find.byKey(Key(key));
      await tester.scrollUntilVisible(
        card,
        200,
        scrollable: find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .first,
      );
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();
      await tester.tapAt(tester.getTopLeft(card) + const Offset(24, 24));
      await tester.pumpAndSettle();
    }

    testWidgets('cihaz bilgisi: özet, ekran ve bölümler', (tester) async {
      await open(tester, 'lessons_deviceInfo');
      expect(find.byKey(const Key('deviceInfo_summary')), findsOneWidget);
      expect(find.textContaining('3 alan'), findsOneWidget);
      expect(find.byKey(const Key('info_screen')), findsOneWidget);
      expect(find.text('Deneme X1'), findsOneWidget);
      expect(find.text('Sistem özellikleri (2)'), findsOneWidget);
    });

    testWidgets('uygulama ve ağ: IP gizli başlar, dokununca görünür', (
      tester,
    ) async {
      await open(tester, 'lessons_appNetwork');
      expect(find.text('1.0.0'), findsOneWidget);

      await tester.tap(find.byKey(const Key('appNetwork_tabNetwork')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('trace_latency')), findsOneWidget);
      expect(find.text('203.0.113.7'), findsNothing);
      expect(find.byKey(const Key('wifi_access')), findsOneWidget);

      final ip = find.byKey(const Key('info_value_Genel IP'));
      await tester.ensureVisible(ip);
      await tester.tap(ip);
      await tester.pumpAndSettle();
      expect(find.text('203.0.113.7'), findsOneWidget);
    });
  });
}
