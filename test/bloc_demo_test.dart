import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ders/app/app.dart';
import 'package:flutter_ders/app/core/di/injection.dart';
import 'package:flutter_ders/app/core/repository/live_rates_repository.dart';
import 'package:flutter_ders/app/core/repository/rates_repository.dart';
import 'package:flutter_ders/app/core/repository/tips_repository.dart';
import 'package:flutter_ders/app/helper/mock_socket.dart';
import 'package:flutter_ders/app/models/exchange_rates.dart';
import 'package:flutter_ders/app/models/expense.dart';
import 'package:flutter_ders/app/models/saving_tip.dart';
import 'package:flutter_ders/app/views/view_bloc_demo/bloc/live_rates_bloc.dart';
import 'package:flutter_ders/app/views/view_bloc_demo/bloc/live_rates_event.dart';
import 'package:flutter_ders/app/views/view_bloc_demo/bloc/live_rates_state.dart';
import 'package:flutter_ders/app/views/view_bloc_demo/bloc/rates_bloc.dart';
import 'package:flutter_ders/app/views/view_bloc_demo/bloc/rates_event.dart';
import 'package:flutter_ders/app/views/view_bloc_demo/bloc/rates_state.dart';
import 'package:flutter_ders/app/views/view_bloc_demo/bloc/tips_bloc.dart';
import 'package:flutter_ders/app/views/view_bloc_demo/bloc/tips_event.dart';
import 'package:flutter_ders/app/views/view_bloc_demo/bloc/tips_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/lessons.dart';

/// Gerçek ağa çıkmadan dio'ya cevap veren bağdaştırıcı.
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

/// İsteği elle bitirilebilen sahte kur deposu.
class _ControlledRates implements RatesRepository {
  int calls = 0;
  Completer<ExchangeRates> pending = Completer();

  @override
  Future<ExchangeRates> latest() {
    calls++;
    return pending.future;
  }
}

class _InstantRates implements RatesRepository {
  @override
  Future<ExchangeRates> latest() async => rates;
}

class _FailingRates implements RatesRepository {
  @override
  Future<ExchangeRates> latest() async =>
      throw const RatesFailure('İnternete bağlanılamadı.');
}

/// Elle mesaj gönderilebilen sahte canlı akış.
class _FakeLive implements LiveRatesRepository {
  StreamController<SocketMessage> controller = StreamController();
  final sent = <String>[];

  @override
  Stream<SocketMessage> connect() => controller.stream;

  @override
  void send(String text) => sent.add(text);

  @override
  Future<void> disconnect() async {
    if (!controller.isClosed) await controller.close();
  }
}

class _FakeTips implements TipsRepository {
  @override
  Future<List<SavingTip>> loadAll() async => tips;
}

final rates = ExchangeRates(
  date: DateTime(2026, 11, 2),
  tryPerUnit: const {'USD': 50, 'EUR': 56},
);

const tips = [
  SavingTip(
    id: 'kahve',
    category: ExpenseCategory.food,
    title: 'Kahveyi termosla taşı',
    body: 'Dışarıdan kahve pahalı.',
    monthlySaving: 900,
  ),
  SavingTip(
    id: 'akbil',
    category: ExpenseCategory.transport,
    title: 'Aylık kart al',
    body: 'Toplu taşıma.',
    monthlySaving: 500,
  ),
];

RateTick tick(double usd) =>
    RateTick(usd: usd, eur: usd + 6, at: DateTime(2026, 11, 3));

// DERS 13 — Bloc ile durum yönetimi.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('servis (Frankfurter)', () {
    test('cevap "1 birim = kaç ₺" olarak çevrilir', () {
      final r = ExchangeRates.fromFrankfurter({
        'amount': 1.0,
        'base': 'TRY',
        'date': '2026-11-02',
        'rates': {'USD': 0.02, 'EUR': 0.016},
      });
      expect(r.tryPerUnit['USD'], closeTo(50, 0.0001));
      expect(r.tryPerUnit['EUR'], closeTo(62.5, 0.0001));
      expect(r.date, DateTime(2026, 11, 2));
    });

    test('dio doğru adrese ister ve cevabı çözer', () async {
      final adapter = _FakeAdapter(
        (_) => ResponseBody.fromString(
          jsonEncode({
            'amount': 1.0,
            'base': 'TRY',
            'date': '2026-11-02',
            'rates': {'USD': 0.02},
          }),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        ),
      );
      final dio = createDio()..httpClientAdapter = adapter;
      final r = await FrankfurterRatesRepository(dio).latest();
      expect(r.tryPerUnit['USD'], closeTo(50, 0.0001));
      final uri = adapter.requests.single;
      expect(
        uri.toString(),
        startsWith('https://api.frankfurter.dev/v1/latest'),
      );
      expect(uri.queryParameters['base'], 'TRY');
      expect(uri.queryParameters['symbols'], contains('USD'));
    });

    test('bağlantı hatası Türkçe bir RatesFailure olur', () async {
      final dio = createDio()
        ..httpClientAdapter = _FakeAdapter(
          (o) => throw DioException(
            requestOptions: o,
            type: DioExceptionType.connectionError,
          ),
        );
      expect(
        () => FrankfurterRatesRepository(dio).latest(),
        throwsA(
          isA<RatesFailure>().having(
            (e) => e.message,
            'message',
            'İnternete bağlanılamadı.',
          ),
        ),
      );
    });
  });

  group('RatesBloc', () {
    blocTest<RatesBloc, RatesState>(
      'istek → yükleniyor, sonra kurlar',
      build: () => RatesBloc(repository: _InstantRates()),
      act: (b) => b.add(const RatesRequested()),
      expect: () => [
        const RatesLoading(),
        isA<RatesLoaded>()
            .having((s) => s.rates, 'rates', rates)
            .having((s) => s.handled, 'handled', 1),
      ],
    );

    blocTest<RatesBloc, RatesState>(
      'hata → yükleniyor, sonra hata mesajı',
      build: () => RatesBloc(repository: _FailingRates()),
      act: (b) => b.add(const RatesRequested()),
      expect: () => [
        const RatesLoading(),
        const RatesError(message: 'İnternete bağlanılamadı.', handled: 1),
      ],
    );

    test(
      'istek sürerken basılan "Yenile"ler yok sayılır (droppable)',
      () async {
        final repo = _ControlledRates();
        final bloc = RatesBloc(repository: repo)
          ..add(const RatesRefreshed())
          ..add(const RatesRefreshed())
          ..add(const RatesRefreshed());
        await Future<void>.delayed(Duration.zero);
        expect(repo.calls, 1);

        repo.pending.complete(rates);
        await Future<void>.delayed(Duration.zero);
        expect(bloc.state, isA<RatesLoaded>());

        // İstek bittikten sonra yeni "Yenile" işlenir.
        repo.pending = Completer()..complete(rates);
        bloc.add(const RatesRefreshed());
        await Future<void>.delayed(Duration.zero);
        expect(repo.calls, 2);
        await bloc.close();
      },
    );
  });

  group('LiveRatesBloc', () {
    late _FakeLive live;

    blocTest<LiveRatesBloc, LiveRatesState>(
      'bağlan → canlı kurlar ve yankı → kes → kapandı',
      setUp: () => live = _FakeLive(),
      build: () => LiveRatesBloc(repository: live),
      act: (b) async {
        b.add(const LiveConnectRequested());
        await Future<void>.delayed(Duration.zero);
        live.controller
          ..add(tick(41))
          ..add(tick(42));
        b.add(const LiveMessageSent('merhaba'));
        await Future<void>.delayed(Duration.zero);
        live.controller.add(EchoReply('merhaba', DateTime(2026)));
        await Future<void>.delayed(Duration.zero);
        b.add(const LiveDisconnectRequested());
      },
      wait: const Duration(milliseconds: 20),
      expect: () => [
        const LiveRatesState(status: LiveStatus.connecting),
        isA<LiveRatesState>()
            .having((s) => s.status, 'status', LiveStatus.live)
            .having((s) => s.ticks, 'ticks', 1),
        isA<LiveRatesState>()
            .having((s) => s.last?.usd, 'usd', 42)
            .having((s) => s.previous?.usd, 'previous', 41),
        isA<LiveRatesState>().having((s) => s.echoes, 'echoes', hasLength(1)),
        isA<LiveRatesState>().having(
          (s) => s.status,
          'status',
          LiveStatus.closed,
        ),
      ],
      verify: (_) => expect(live.sent, ['merhaba']),
    );

    test('gerçek sahte soket: bağlanınca kur gelir, kesince kapanır', () async {
      final bloc = LiveRatesBloc(repository: MockLiveRatesRepository())
        ..add(const LiveConnectRequested());
      await bloc.stream.firstWhere((s) => s.status == LiveStatus.live);
      bloc.add(const LiveDisconnectRequested());
      await bloc.stream.firstWhere((s) => s.status == LiveStatus.closed);
      await bloc.close();
    });
  });

  group('TipsBloc', () {
    blocTest<TipsBloc, TipsState>(
      'yükle → hazır; kategori seçilince filtrelenir',
      build: () => TipsBloc(repository: _FakeTips()),
      act: (b) => b
        ..add(const TipsLoaded())
        ..add(const TipsCategorySelected(ExpenseCategory.transport)),
      expect: () => [
        const TipsState(),
        const TipsState(status: TipsStatus.ready, all: tips),
        isA<TipsState>().having((s) => s.visible.map((t) => t.id), 'visible', [
          'akbil',
        ]),
      ],
    );

    blocTest<TipsBloc, TipsState>(
      'hızlı yazarken yalnızca son arama uygulanır (restartable + bekleme)',
      build: () => TipsBloc(
        repository: _FakeTips(),
        debounce: const Duration(milliseconds: 20),
      ),
      seed: () => const TipsState(status: TipsStatus.ready, all: tips),
      act: (b) => b
        ..add(const TipsSearched('k'))
        ..add(const TipsSearched('ka'))
        ..add(const TipsSearched('kahve')),
      wait: const Duration(milliseconds: 60),
      expect: () => [
        isA<TipsState>()
            .having((s) => s.query, 'query', 'kahve')
            .having((s) => s.visible.single.id, 'visible', 'kahve'),
      ],
    );

    test('asset dosyasındaki 16 ipucu okunur', () async {
      final all = await AssetTipsRepository().loadAll();
      expect(all, hasLength(16));
      expect(all.map((t) => t.id).toSet(), hasLength(16));
      expect(all.every((t) => t.monthlySaving > 0), isTrue);
    });
  });

  testWidgets('sayfa: servis kurları, asset ipuçları ve arama', (tester) async {
    await getIt.reset();
    SharedPreferences.setMockInitialValues({});
    await configureDependencies();
    getIt
      ..unregister<RatesRepository>()
      ..registerSingleton<RatesRepository>(_InstantRates())
      ..unregister<TipsRepository>()
      ..registerSingleton<TipsRepository>(_FakeTips())
      ..unregister<LiveRatesRepository>()
      ..registerFactory<LiveRatesRepository>(_FakeLive.new);
    tester.view.physicalSize = const Size(1440, 3120);
    tester.view.devicePixelRatio = 3.75;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const HarcamaApp(watchNetwork: false));
    await tester.pumpAndSettle();
    await openLessonsHub(tester);
    final card = find.byKey(const Key('lessons_bloc'));
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

    expect(find.byKey(const Key('rate_USD')), findsOneWidget);
    expect(find.text('1 USD = 50,00 ₺'), findsOneWidget);

    await tester.tap(find.byKey(const Key('bloc_tabTips')));
    await tester.pumpAndSettle();
    expect(
      find.text('2 / 2 ipucu · aylık ~1.400,00 ₺ tasarruf'),
      findsOneWidget,
    );

    await tester.enterText(find.byKey(const Key('tips_search')), 'kahve');
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('tip_kahve')), findsOneWidget);
    expect(find.byKey(const Key('tip_akbil')), findsNothing);
  });
}
