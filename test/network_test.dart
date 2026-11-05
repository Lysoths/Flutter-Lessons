import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_ders/app/app.dart';
import 'package:flutter_ders/app/core/di/injection.dart';
import 'package:flutter_ders/app/core/router/app_deep_links.dart';
import 'package:flutter_ders/app/helper/mock_socket.dart';
import 'package:flutter_ders/app/helper/network_checker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/lessons.dart';

// DERS 11 — Ağ kontrolü.
void main() {
  /// Animasyonlar için kareleri küçük adımlarla ilerletir.
  Future<void> frames(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  group('NetworkChecker (Future)', () {
    test('ulaşılırsa çevrimiçi, ulaşılamazsa çevrimdışı', () async {
      expect(
        (await NetworkChecker(probe: () async => true).check()).online,
        isTrue,
      );
      expect(
        (await NetworkChecker(probe: () async => false).check()).online,
        isFalse,
      );
    });

    test('ağ hatası ve zaman aşımı çevrimdışı sayılır', () async {
      final socket = await NetworkChecker(
        probe: () => throw const SocketException('bağlantı yok'),
      ).check();
      expect(socket.online, isFalse);
      expect(socket.detail, contains('Ağ hatası'));

      final slow = await NetworkChecker(
        probe: () => throw TimeoutException('yavaş'),
      ).check();
      expect(slow.online, isFalse);
      expect(slow.detail, contains('Zaman aşımı'));
    });

    test('simülasyon ağa hiç sormadan çevrimdışı der', () async {
      var asked = false;
      final checker = NetworkChecker(
        probe: () async {
          asked = true;
          return true;
        },
      )..simulateOffline = true;
      expect((await checker.check()).online, isFalse);
      expect(asked, isFalse);
    });
  });

  group('NetworkChecker (Stream)', () {
    test('hemen bir değer, sonra aralıklarla; refresh hemen sorar', () async {
      var online = true;
      final checker = NetworkChecker(probe: () async => online);
      final values = <bool>[];
      final sub = checker
          .watch(every: const Duration(hours: 1))
          .listen((r) => values.add(r.online));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(values, [true]);

      online = false;
      checker.refresh();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(values, [true, false]);

      await sub.cancel();
      checker.refresh();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      // Dinleyen kalmayınca yeni kontrol yapılmaz.
      expect(values, [true, false]);
    });
  });

  group('sahte WebSocket', () {
    test('kur akar, mesaj geri döner', () async {
      final server = MockSocketServer(tick: const Duration(milliseconds: 30));
      final uri = await server.start();
      expect(uri.host, '127.0.0.1');

      final client = await MockSocketClient.connect(uri);
      final messages = client.messages.asBroadcastStream();
      final tick = await messages.firstWhere((m) => m is RateTick);
      expect((tick as RateTick).usd, greaterThan(30));

      client.send('merhaba');
      final echo = await messages.firstWhere((m) => m is EchoReply);
      expect((echo as EchoReply).text, 'merhaba');

      await client.close();
      await server.stop();
    });

    test('JSON mesajı doğru türe çözülür', () {
      final m = SocketMessage.fromJson({
        'type': 'kur',
        'usd': 41.5,
        'eur': 48,
        'at': '2026-11-03T10:00:00.000',
      });
      expect(m, isA<RateTick>());
      expect((m as RateTick).eur, 48);
    });
  });

  test('ağ sayfası deep link ile açılamaz', () {
    expect(
      AppDeepLinks.sanitize(Uri.parse('harcamatakibim://app/ag')).path,
      '/',
    );
  });

  testWidgets('bağlantı yokken üstte banner çıkar, gelince kalkar', (
    tester,
  ) async {
    await getIt.reset();
    SharedPreferences.setMockInitialValues({});
    await configureDependencies();
    var online = true;
    final checker = NetworkChecker(probe: () async => online);
    getIt
      ..unregister<NetworkChecker>()
      ..registerSingleton<NetworkChecker>(checker);
    tester.view.physicalSize = const Size(1440, 3120);
    tester.view.devicePixelRatio = 3.75;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const HarcamaApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('networkBanner')), findsNothing);

    online = false;
    checker.refresh();
    await tester.pump();
    // Banner yukarıdan kayarak açılır; animasyon bitsin.
    await frames(tester);
    expect(find.byKey(const Key('networkBanner')), findsOneWidget);
    expect(find.text('İnternet bağlantısı yok'), findsOneWidget);

    online = true;
    await tester.tap(find.byKey(const Key('networkBanner_retry')));
    await tester.pump();
    await frames(tester);
    expect(find.byKey(const Key('networkBanner')), findsNothing);
    expect(find.text('İnternet bağlantısı geri geldi'), findsOneWidget);

    // Bekleyen snackbar zamanlayıcısı bitsin.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('ağ sayfası: FutureBuilder sonucu ve simülasyon', (tester) async {
    await getIt.reset();
    SharedPreferences.setMockInitialValues({});
    await configureDependencies();
    getIt
      ..unregister<NetworkChecker>()
      ..registerSingleton<NetworkChecker>(
        NetworkChecker(probe: () async => true),
      );
    tester.view.physicalSize = const Size(1440, 3120);
    tester.view.devicePixelRatio = 3.75;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const HarcamaApp());
    await tester.pumpAndSettle();
    await openLessonsHub(tester);
    final card = find.byKey(const Key('lessons_network'));
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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final future = find.byKey(const Key('network_future'));
    await tester.scrollUntilVisible(
      future,
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('network_list')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pump();
    expect(
      find.descendant(of: future, matching: find.text('Çevrimiçi')),
      findsOneWidget,
    );

    // Anahtar sayfanın başında: yukarı dön, aç, sonra karta geri in.
    final list = find
        .descendant(
          of: find.byKey(const Key('network_list')),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.drag(list, const Offset(0, 3000));
    await frames(tester);
    await tester.tap(find.byKey(const Key('network_simulate')));
    await tester.pump();
    await frames(tester);
    await tester.scrollUntilVisible(future, 200, scrollable: list);
    await tester.pump();
    expect(
      find.descendant(of: future, matching: find.text('Çevrimdışı')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('networkBanner')), findsOneWidget);

    getIt<NetworkChecker>().simulateOffline = false;
    await tester.pumpWidget(const SizedBox());
    // Kaydırma / geçiş gibi kısa süreli zamanlayıcılar bitsin.
    await tester.pump(const Duration(seconds: 10));
  });
}
