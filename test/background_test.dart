import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_ders/app/app.dart';
import 'package:flutter_ders/app/core/background/app_presence_reporter.dart';
import 'package:flutter_ders/app/core/background/background_models.dart';
import 'package:flutter_ders/app/core/background/background_service.dart';
import 'package:flutter_ders/app/core/background/background_tracker.dart';
import 'package:flutter_ders/app/core/background/notification_plan.dart';
import 'package:flutter_ders/app/core/device/location_source.dart';
import 'package:flutter_ders/app/core/di/injection.dart';
import 'package:flutter_ders/app/models/expense.dart';
import 'package:flutter_ders/app/views/view_background/background_view.dart';
import 'package:flutter_ders/app/views/view_expenses/cubit/expenses_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/lessons.dart';

GpsSample _sample(double lat, double lon, {double acc = 5}) => GpsSample(
  latitude: lat,
  longitude: lon,
  accuracy: acc,
  speed: 0,
  time: DateTime(2026, 11, 5, 12),
  presence: AppPresence.background,
  readMs: 0,
);

class _Clock {
  DateTime now = DateTime(2026, 11, 5, 12);
  void advance(Duration d) => now = now.add(d);
}

class _FakeLocation implements LocationSource {
  _FakeLocation(this.access);

  final LocationAccess access;

  @override
  Future<LocationAccess> requestAccess() async => access;

  @override
  Stream<GpsFix> positions() => const Stream.empty();

  @override
  Future<void> openSettings(LocationAccess access) async {}
}

void main() {
  test('yaşam döngüsü → açık / arka plan / kapalı', () {
    expect(
      AppPresence.fromLifecycle(AppLifecycleState.resumed),
      AppPresence.open,
    );
    // Bildirim perdesi çekilince "inactive" gelir: uygulama hâlâ açıktır.
    expect(
      AppPresence.fromLifecycle(AppLifecycleState.inactive),
      AppPresence.open,
    );
    expect(
      AppPresence.fromLifecycle(AppLifecycleState.hidden),
      AppPresence.background,
    );
    expect(
      AppPresence.fromLifecycle(AppLifecycleState.paused),
      AppPresence.background,
    );
    expect(
      AppPresence.fromLifecycle(AppLifecycleState.detached),
      AppPresence.closed,
    );
    expect(AppPresence.byName('yok'), AppPresence.closed);
  });

  group('BackgroundTracker', () {
    late _Clock clock;
    late MemoryTrackStore store;
    late List<GpsSample> queue;
    late BackgroundTracker tracker;

    setUp(() async {
      clock = _Clock();
      store = MemoryTrackStore();
      queue = [];
      tracker = BackgroundTracker(
        readGps: (presence) async {
          if (queue.isEmpty) throw TimeoutException('GPS yok');
          final s = queue.removeAt(0);
          return GpsSample(
            latitude: s.latitude,
            longitude: s.longitude,
            accuracy: s.accuracy,
            speed: 0,
            time: clock.now,
            presence: presence,
            readMs: 0,
          );
        },
        store: store,
        now: () => clock.now,
      );
      await tracker.load();
    });

    test('açıkken GPS okunmaz, arkadayken her adımda bir konum', () async {
      queue.addAll([_sample(41, 29), _sample(41.001, 29)]);
      expect(await tracker.tick(), TickOutcome.skippedOpen);
      expect(queue, hasLength(2));

      tracker.setPresence(AppPresence.background, 'test');
      clock.advance(kTickInterval);
      expect(await tracker.tick(), TickOutcome.recorded);
      clock.advance(kTickInterval);
      tracker.heartbeat();
      expect(await tracker.tick(), TickOutcome.recorded);

      final s = tracker.stats;
      expect(s.ticks, 3);
      expect(s.skippedOpen, 1);
      expect(s.gpsOk, 2);
      expect(store.samples, hasLength(2));
      expect(store.samples.first.presence, AppPresence.background);
      // 0,001 derece enlem ≈ 111 m.
      expect(s.distanceMeters, closeTo(111, 1));
      expect(s.presenceMs[AppPresence.background], 6000);
      expect(s.changes.single.presence, AppPresence.background);
      expect(s.serviceStarts, 1);
    });

    test('GPS titremesi (doğruluktan küçük adım) mesafeye eklenmez', () async {
      tracker.setPresence(AppPresence.background, 'test');
      queue.addAll([
        _sample(41, 29, acc: 20),
        _sample(41.00005, 29, acc: 20), // ≈ 5,5 m
      ]);
      await tracker.tick();
      await tracker.tick();
      expect(tracker.stats.gpsOk, 2);
      expect(tracker.stats.distanceMeters, 0);
    });

    test('okunamayan GPS hata sayılır', () async {
      tracker.setPresence(AppPresence.background, 'test');
      expect(await tracker.tick(), TickOutcome.failed);
      expect(tracker.stats.gpsFailed, 1);
      expect(store.samples, isEmpty);
    });

    test('nabız kesilince uygulama kapalı sayılır', () async {
      tracker.setPresence(AppPresence.background, 'yaşam döngüsü');
      clock.advance(const Duration(seconds: 9));
      expect(tracker.checkHeartbeat(), isFalse);
      clock.advance(const Duration(seconds: 2));
      expect(tracker.checkHeartbeat(), isTrue);
      expect(tracker.stats.presence, AppPresence.closed);
      expect(tracker.stats.changes.last.reason, 'nabız kesildi');
      // Kapalıyken de konum alınır.
      queue.add(_sample(41, 29));
      expect(await tracker.tick(), TickOutcome.recorded);
      expect(store.samples.single.presence, AppPresence.closed);
    });

    test('yeniden başlayan servis eski sayıları diskten okur', () async {
      tracker.setPresence(AppPresence.background, 'test');
      queue.add(_sample(41, 29));
      await tracker.tick();
      tracker.recordNotification(NotificationKind.inbox.key);

      final again = BackgroundTracker(
        readGps: (_) async => throw StateError('kullanılmaz'),
        store: store,
        now: () => clock.now,
      );
      await again.load();
      expect(again.stats.gpsOk, 1);
      expect(again.stats.serviceStarts, 2);
      expect(again.stats.notificationsSent, {'liste': 1});
      expect(again.storedSamples, 1);
      // Servis yeniden başlayınca ilk haberi uygulama verir: "açık".
      expect(again.stats.presence, AppPresence.open);
    });

    test('istatistik JSON gidiş-dönüş', () async {
      tracker
        ..setPresence(AppPresence.background, 'test')
        ..recordNotification('buyuk_gorsel')
        ..recordCancelled(3)
        ..syncActions({'sessize_al': 2})
        ..setMuted(muted: true);
      queue.add(_sample(41, 29));
      clock.advance(kTickInterval);
      await tracker.tick();
      final s = tracker.stats;
      expect(BackgroundStats.fromJson(s.toJson()), s);
      expect(s.notificationsCancelled, 3);
      expect(s.muted, isTrue);
    });

    test('temizle: konumlar ve sayılar sıfırlanır', () async {
      tracker.setPresence(AppPresence.background, 'test');
      queue.add(_sample(41, 29));
      await tracker.tick();
      await tracker.clear();
      expect(tracker.samples, isEmpty);
      expect(tracker.stats.gpsOk, 0);
      expect(store.samples, isEmpty);
    });
  });

  test('FileTrackStore: satır satır yazar, yarım son satırı atlar', () async {
    final dir = await Directory.systemTemp.createTemp('ders19_');
    addTearDown(() => dir.delete(recursive: true));
    final store = FileTrackStore(() async => dir);
    await store.append(_sample(41, 29));
    await store.append(_sample(41.1, 29.1));
    await store.saveStats(const BackgroundStats(gpsOk: 2));
    File('${dir.path}/arka_plan/konumlar.jsonl')
        .writeAsStringSync('{"lat": 4', mode: FileMode.append);

    final (stats, samples) = await store.load();
    expect(stats!.gpsOk, 2);
    expect(samples, hasLength(2));
    expect(samples.last.latitude, 41.1);

    await store.clear();
    final (s2, l2) = await store.load();
    expect(s2, isNull);
    expect(l2, isEmpty);
  });

  group('bildirim çizelgesi', () {
    const snapshot = AppSnapshot(
      expenseCount: 520,
      monthTotal: 1500,
      lastMonthTotal: 3000,
      topCategory: 'Yemek',
      recent: ['Yemek · 120 ₺', 'Ulaşım · 40 ₺'],
    );

    test('her tür bir kez, farklı anlarda, kimlikler tekil', () {
      final plan = planNotifications(snapshot);
      expect(plan.map((n) => n.kind).toSet(), NotificationKind.values.toSet());
      expect(plan.map((n) => n.id).toSet(), hasLength(plan.length));
      final delays = plan.map((n) => n.delay).toList();
      for (var i = 1; i < delays.length; i++) {
        expect(delays[i], greaterThan(delays[i - 1]));
      }
    });

    test('metinler uygulamanın verisinden gelir', () {
      final plan = planNotifications(snapshot);
      final byKind = {for (final n in plan) n.kind: n};
      expect(byKind[NotificationKind.bigText]!.body, contains('1500 ₺'));
      expect(byKind[NotificationKind.inbox]!.lines, snapshot.recent);
      expect(byKind[NotificationKind.progress]!.progress, 50);
      expect(
        byKind[NotificationKind.messaging]!.lines.join(),
        contains('Yemek'),
      );

      final empty = planNotifications(const AppSnapshot());
      expect(
        {for (final n in empty) n.kind: n}[NotificationKind.inbox]!.lines,
        ['Henüz harcama yok'],
      );
    });

    test('görselli bildirimler var olan asset kullanır ve düğmelidir', () {
      final pictures = planNotifications(snapshot)
          .where((n) => n.image != null);
      expect(pictures, hasLength(2));
      for (final n in pictures) {
        expect(File(n.image!).existsSync(), isTrue, reason: n.image);
        expect(n.actions, isNotEmpty);
      }
      final yaml = File('pubspec.yaml').readAsStringSync();
      expect(yaml, contains('assets/belgeler/'));
    });

    test('yük yalnız beyaz listedeki hedef olabilir', () {
      expect(
        NotificationTarget.fromPayload('documents'),
        NotificationTarget.documents,
      );
      expect(NotificationTarget.fromPayload('/firebase'), isNull);
      expect(NotificationTarget.fromPayload(null), isNull);
      // Uygulamayı açmayan düğmeler: sessize al ve yanıtla.
      expect(NotificationAction.values.where((a) => a.target == null), {
        NotificationAction.mute,
        NotificationAction.reply,
      });
    });

    testWidgets('simülatör: sırası gelince gönderir, öne gelince iptal', (
      tester,
    ) async {
      final sender = MemoryNotificationSender();
      final sent = <String>[];
      final sim = NotificationSimulator(
        sender: sender,
        onSent: (n) => sent.add(n.kind.key),
        isMuted: () async => false,
      )..start(snapshot);
      await tester.pump(const Duration(seconds: 4));
      expect(sender.shown, isEmpty);
      await tester.pump(const Duration(seconds: 1));
      expect(sent, ['genis_metin']);
      await tester.pump(const Duration(seconds: 15));
      expect(sent, ['genis_metin', 'buyuk_gorsel']);

      expect(sim.cancel(), 5);
      await tester.pump(const Duration(minutes: 3));
      expect(sent, hasLength(2));
      final states = [
        for (final s in sim.report()['adimlar']! as List) (s as Map)['durum'],
      ];
      expect(states.where((s) => s == 'sent'), hasLength(2));
      expect(states.where((s) => s == 'cancelled'), hasLength(5));
    });

    testWidgets('simülatör: sessizdeyken göndermez, önizleme 2 sn arayla', (
      tester,
    ) async {
      var muted = true;
      final sender = MemoryNotificationSender();
      final sim = NotificationSimulator(
        sender: sender,
        onSent: (_) {},
        isMuted: () async => muted,
      )..start(snapshot);
      await tester.pump(const Duration(minutes: 3));
      expect(sender.shown, isEmpty);

      muted = false;
      sim.start(snapshot, gap: const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 14));
      expect(sender.shown, hasLength(NotificationKind.values.length));
    });
  });

  testWidgets('uygulama durumunu yalnız servis çalışırken bildirir', (
    tester,
  ) async {
    final channel = MemoryBackgroundChannel();
    final reporter = AppPresenceReporter(
      channel: channel,
      snapshot: () => const AppSnapshot(expenseCount: 3),
    );
    await reporter.start();
    reporter.didChangeAppLifecycleState(AppLifecycleState.paused);
    expect(channel.sent, isEmpty);

    reporter
      ..didChangeAppLifecycleState(AppLifecycleState.resumed)
      ..serviceStarted();
    expect(channel.sent.single.$2, {'durum': 'open'});

    reporter
      ..didChangeAppLifecycleState(AppLifecycleState.inactive)
      ..didChangeAppLifecycleState(AppLifecycleState.hidden)
      ..didChangeAppLifecycleState(AppLifecycleState.paused);
    final background = channel.sent.last;
    expect(background.$1, BgMessages.presence);
    expect(background.$2!['durum'], 'background');
    expect((background.$2!['ozet']! as Map)['adet'], 3);
    expect(channel.sent, hasLength(2));

    channel.sent.clear();
    await tester.pump(const Duration(seconds: 7));
    expect(channel.sent.map((m) => m.$1), [
      BgMessages.heartbeat,
      BgMessages.heartbeat,
    ]);
    reporter.dispose();
    await tester.pump(const Duration(seconds: 6));
    expect(channel.sent, hasLength(2));
  });

  test('özet: sayı, ay toplamları, son 5 harcama; not eklenmez', () {
    final now = DateTime(2026, 11, 5);
    final state = ExpensesState(
      expenses: [
        for (var i = 0; i < 7; i++)
          Expense(
            id: 'e$i',
            amount: 100,
            category: i.isEven ? ExpenseCategory.food : ExpenseCategory.bills,
            date: i < 4 ? now : DateTime(2026, 10, 3),
            note: 'gizli not $i',
          ),
      ],
    );
    final s = snapshotOf(state, now);
    expect(s.expenseCount, 7);
    expect(s.monthTotal, 400);
    expect(s.lastMonthTotal, 300);
    expect(s.topCategory, 'Yemek');
    expect(s.recent, hasLength(5));
    expect(s.toJson().toString(), isNot(contains('gizli')));
  });

  group('Ders 19 ekranı', () {
    late MemoryBackgroundChannel channel;

    setUp(() async {
      await getIt.reset();
      SharedPreferences.setMockInitialValues({});
      await configureDependencies();
      channel = getIt<BackgroundChannel>() as MemoryBackgroundChannel;
    });

    Future<void> open(WidgetTester tester, LocationAccess access) async {
      getIt
        ..unregister<LocationSource>()
        ..registerSingleton<LocationSource>(_FakeLocation(access));
      tester.view.physicalSize = const Size(1440, 3120);
      tester.view.devicePixelRatio = 3.75;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const HarcamaApp(watchNetwork: false));
      await tester.pumpAndSettle();
      await openLessonsHub(tester);
      await tester.enterText(find.byKey(const Key('lessons_search')), '19');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('lessons_background')));
      await tester.pumpAndSettle();
      expect(find.byType(BackgroundView), findsOneWidget);
    }

    testWidgets('başlat → servis çalışır, rapor ekrana gelir', (tester) async {
      await open(tester, LocationAccess.granted);
      expect(find.text('Servis kapalı'), findsOneWidget);
      expect(find.byKey(const Key('bg_status')), findsOneWidget);

      await tester.tap(find.byKey(const Key('bg_start')));
      await tester.pumpAndSettle();
      expect(channel.running, isTrue);
      expect(find.text('Servis çalışıyor'), findsOneWidget);
      // Başlar başlamaz uygulama servise "açığım" der.
      expect(channel.sent.first.$1, BgMessages.presence);

      channel.emit({
        'istatistik': const BackgroundStats(
          presence: AppPresence.background,
          ticks: 12,
          gpsOk: 9,
          notificationsSent: {'buyuk_gorsel': 1},
        ).toJson(),
        'kayitli': 9,
        'son_konumlar': [_sample(41.015137, 28.97953).toJson()],
        'simulasyon': {
          'adimlar': [
            {
              'id': 1902,
              'tur': 'bigPicture',
              'sn': 15,
              'baslik': 'Fişini sakladın mı?',
              'durum': 'sent',
            },
          ],
        },
      });
      await tester.pumpAndSettle();
      expect(find.text('Uygulama: Arka planda'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const Key('bg_plan_bigPicture')),
        300,
        scrollable: find.descendant(
          of: find.byKey(const Key('bg_list')),
          matching: find.byType(Scrollable),
        ),
      );
      expect(find.text('Gönderildi'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const Key('bg_samples')),
        300,
        scrollable: find.descendant(
          of: find.byKey(const Key('bg_list')),
          matching: find.byType(Scrollable),
        ),
      );
      expect(find.text('9 kayıt'), findsOneWidget);
      expect(find.text('41.015137, 28.979530'), findsOneWidget);

      tester
          .state<ScrollableState>(
            find.descendant(
              of: find.byKey(const Key('bg_list')),
              matching: find.byType(Scrollable),
            ),
          )
          .position
          .jumpTo(0);
      await tester.pumpAndSettle();
      ScaffoldMessenger.of(
        tester.element(find.byType(BackgroundView)),
      ).removeCurrentSnackBar();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('bg_preview')));
      await tester.pump();
      expect(channel.sent.last.$1, BgMessages.preview);

      await tester.tap(find.byKey(const Key('bg_stop')));
      await tester.pumpAndSettle();
      expect(channel.sent.last.$1, BgMessages.stop);
      expect(find.text('Servis kapalı'), findsOneWidget);
    });

    testWidgets('konum izni yoksa servis başlamaz', (tester) async {
      await open(tester, LocationAccess.denied);
      await tester.tap(find.byKey(const Key('bg_start')));
      await tester.pumpAndSettle();
      expect(channel.running, isFalse);
      expect(find.text('İzin verilmedi'), findsOneWidget);
    });
  });
}
