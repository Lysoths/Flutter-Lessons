import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ders/app/app.dart';
import 'package:flutter_ders/app/core/base/base_change_notifier_view_model.dart';
import 'package:flutter_ders/app/core/di/injection.dart';
import 'package:flutter_ders/app/core/repository/currency_repository.dart';
import 'package:flutter_ders/app/core/repository/news_repository.dart';
import 'package:flutter_ders/app/core/repository/rates_repository.dart';
import 'package:flutter_ders/app/models/currency/currency_info.dart';
import 'package:flutter_ders/app/models/currency/news_article.dart';
import 'package:flutter_ders/app/models/currency/rate_history.dart';
import 'package:flutter_ders/app/views/view_currency/view_model/currency_view_model.dart';
import 'package:flutter_ders/app/views/view_currency/view_model/history_view_model.dart';
import 'package:flutter_ders/app/views/view_currency/view_model/news_view_model.dart';
import 'package:flutter_ders/app/views/view_currency/view_model/rates_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/lessons.dart';

const _aaSample = '''﻿<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0"><channel>
<item>
  <guid isPermaLink="false">1</guid>
  <link>https://www.aa.com.tr/tr/ekonomi/dolar-haberi/1</link>
  <title>Dolar/TL güne yükselişle başladı</title>
  <description>Dolar ve avro TL karşısında değer kazandı.</description>
  <pubDate>Wed, 04 Nov 2026 10:00:00 +0300</pubDate>
  <image>https://cdnuploads.aa.com.tr/1.jpg</image>
</item>
<item><title>Tarihi eksik haber</title><link>https://www.aa.com.tr/x</link></item>
</channel></rss>''';

const _trtSample = '''<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:media="http://search.yahoo.com/mrss/"><channel>
<item>
  <guid>https://www.trthaber.com/haber/ekonomi/2.html</guid>
  <pubDate>Wed, 04 Nov 2026 11:30:00 +0300</pubDate>
  <title>İSVİÇRE Merkez Bankası faizi sabit tuttu</title>
  <description><![CDATA[<img src="https://trthaberstatic.cdn.wp.trt.com.tr/2.jpg"/>Frank &amp; faiz kararı.]]></description>
  <media:content url="https://trthaberstatic.cdn.wp.trt.com.tr/2.jpg" type="image/jpeg"/>
  <link>https://www.trthaber.com/haber/ekonomi/2.html</link>
</item>
<item>
  <guid>https://www.trthaber.com/haber/ekonomi/3.html</guid>
  <pubDate>Wed, 04 Nov 2026 09:00:00 +0300</pubDate>
  <title>Dolar/TL güne yükselişle başladı</title>
  <description>Aynı haber, ikinci kaynak.</description>
  <link>https://www.trthaber.com/haber/ekonomi/3.html</link>
</item>
</channel></rss>''';

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.respond);

  final ResponseBody Function(RequestOptions options) respond;
  final requests = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options.uri.toString());
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

final _latestDay = DateTime(2026, 11, 3);

/// Gün başına USD = 40 + gün sırası / 10; diğerleri USD'den türetilir.
class _FakeCurrency implements CurrencyRepository {
  final asked = <DateTime>[];
  Completer<void>? gate;

  DailyRates _rates(DateTime day) {
    final usd = 40 + day.difference(DateTime(2026)).inDays / 10;
    return (
      date: day,
      tryPerUnit: {
        for (final (i, c) in kTrackedCurrencies.indexed) c.code: usd + i,
      },
    );
  }

  @override
  Future<DailyRates> latest() async => _rates(_latestDay);

  @override
  Future<DailyRates> onDate(DateTime date) async {
    asked.add(date);
    await gate?.future;
    // Hafta sonu: Cuma'nın kuru döner (gerçek servis gibi).
    var day = date;
    while (day.weekday > 5) {
      day = day.subtract(const Duration(days: 1));
    }
    return _rates(day);
  }
}

class _FakeNews implements NewsRepository {
  bool fail = false;

  @override
  Future<NewsResult> latest() async {
    if (fail) throw const NewsFailure('Haber kaynaklarına ulaşılamadı.');
    return (
      articles: [
        ...parseRss(_trtSample, source: 'TRT Haber'),
        ...parseRss(_aaSample, source: 'Anadolu Ajansı'),
      ],
      failedSources: const <String>[],
    );
  }
}

CurrencyViewModel _vm(_FakeCurrency c, _FakeNews n) => CurrencyViewModel(
  rates: RatesViewModel(repository: c),
  history: HistoryViewModel(repository: c),
  news: NewsViewModel(repository: n),
);

void main() {
  group('Model yardımcıları', () {
    test('RSS tarihi saat dilimiyle çözülür', () {
      final d = parseRfc822('Wed, 04 Nov 2026 13:24:07 +0300')!;
      expect(d.toUtc(), DateTime.utc(2026, 11, 4, 10, 24, 7));
      expect(parseRfc822('Tue, 03 Nov 2026 08:00:00 GMT')!.toUtc().hour, 8);
      expect(parseRfc822('dün'), isNull);
    });

    test('HTML temizlenir, Türkçe büyük harfle para birimi bulunur', () {
      expect(stripHtml('<b>Frank</b> &amp;  faiz'), 'Frank & faiz');
      expect(detectCurrencies('DOLAR ve AVRO yükseldi'), ['USD', 'EUR']);
      expect(detectCurrencies('İSVİÇRE Merkez Bankası'), ['CHF']);
      expect(detectCurrencies('Japonya yeni bir rekor'), ['JPY']);
      expect(detectCurrencies('Altın fiyatları'), isEmpty);
    });

    test('kur ve yüzde biçimi', () {
      expect(formatTryRate(41.2345), '41,23 ₺');
      expect(formatTryRate(0.31874), '0,3187 ₺');
      expect(formatTryRate(1234.5), '1.234,50 ₺');
      expect(formatChange(0.4211), '+0,42 %');
      expect(formatChange(-1.1), '-1,10 %');
    });

    test('aralıklar istenecek günleri üretir', () {
      final end = DateTime(2026, 11, 3);
      expect(HistoryPeriod.week.datesUntil(end).length, 8);
      expect(HistoryPeriod.month.datesUntil(end).length, 16);
      expect(HistoryPeriod.quarter.datesUntil(end).length, 14);
      expect(HistoryPeriod.week.datesUntil(end).last, end);
    });
  });

  group('parseRss', () {
    test('AA (BOM, image) ve TRT (CDATA, media:content)', () {
      final aa = parseRss(_aaSample, source: 'AA');
      expect(aa, hasLength(1), reason: 'tarihi eksik öğe atlanır');
      expect(aa.single.imageUrl, 'https://cdnuploads.aa.com.tr/1.jpg');
      expect(aa.single.currencies, ['USD', 'EUR']);

      final trt = parseRss(_trtSample, source: 'TRT');
      expect(trt.first.summary, 'Frank & faiz kararı.');
      expect(trt.first.imageUrl, startsWith('https://trthaberstatic'));
      expect(trt.first.currencies, ['CHF']);
    });
  });

  group('Depolar', () {
    test('kur: ₺ karşılığı tersi alınır, gün önbellekte kalır', () async {
      final adapter = _FakeAdapter(
        (o) => ResponseBody.fromString(
          '{"date":"2026-11-03","try":{"usd":0.025,"eur":0.02,"xyz":1}}',
          200,
        ),
      );
      final repo = CurrencyApiRepository(
        createDio()..httpClientAdapter = adapter,
      );
      final day = await repo.onDate(DateTime(2026, 8, 6));
      expect(day.tryPerUnit, {'USD': 40, 'EUR': 50});
      await repo.onDate(DateTime(2026, 8, 6));
      await repo.latest();
      await repo.latest();
      expect(adapter.requests, [
        CurrencyApiRepository.urlsFor(DateTime(2026, 8, 6)).first,
        CurrencyApiRepository.urlsFor(null).first,
        CurrencyApiRepository.urlsFor(null).first,
      ]);
      expect(adapter.requests.first, contains('currency-api@2026.8.6/'));
    });

    test('kur: jsDelivr açılmazsa pages.dev denenir', () async {
      final adapter = _FakeAdapter((o) {
        if (o.uri.host == 'cdn.jsdelivr.net') {
          throw DioException.connectionError(requestOptions: o, reason: 'x');
        }
        return ResponseBody.fromString(
          '{"date":"2026-11-03","try":{"usd":0.025}}',
          200,
        );
      });
      final repo = CurrencyApiRepository(
        createDio()..httpClientAdapter = adapter,
      );
      final day = await repo.onDate(DateTime(2026, 11, 3));
      expect(day.tryPerUnit['USD'], 40);
      expect(
        adapter.requests.last,
        contains('2026-11-03.currency-api.pages.dev'),
      );
    });

    test('kur: iki adres de olmazsa Türkçe hata, önbellekte kalmaz', () async {
      var fail = true;
      final adapter = _FakeAdapter((o) {
        if (fail) {
          throw DioException.connectionError(requestOptions: o, reason: 'x');
        }
        return ResponseBody.fromString('{"date":"2026-11-03","try":{}}', 200);
      });
      final repo = CurrencyApiRepository(
        createDio()..httpClientAdapter = adapter,
      );
      await expectLater(
        repo.onDate(DateTime(2026, 11, 3)),
        throwsA(
          isA<CurrencyFailure>().having(
            (e) => e.message,
            'message',
            'İnternete bağlanılamadı.',
          ),
        ),
      );
      expect(adapter.requests, hasLength(2));
      fail = false;
      await repo.onDate(DateTime(2026, 11, 3));
      expect(adapter.requests, hasLength(3));
    });

    test(
      'haber: kaynaklar birleşir, aynı başlık bir kez, biri çökebilir',
      () async {
        final adapter = _FakeAdapter((o) {
          final url = o.uri.toString();
          if (url.contains('bozuk')) {
            throw DioException.connectionError(requestOptions: o, reason: 'x');
          }
          return ResponseBody.fromString(
            url.contains('aa.com.tr') ? _aaSample : _trtSample,
            200,
          );
        });
        final repo = RssNewsRepository(
          createDio()..httpClientAdapter = adapter,
          feeds: const [
            (name: 'AA', url: 'https://www.aa.com.tr/rss'),
            (name: 'TRT', url: 'https://www.trthaber.com/rss'),
            (name: 'Bozuk', url: 'https://bozuk.example/rss'),
          ],
        );
        final r = await repo.latest();
        expect(r.failedSources, ['Bozuk']);
        expect(r.articles.map((a) => a.source), ['TRT', 'AA']);
        expect(
          r.articles.first.publishedAt.isAfter(r.articles.last.publishedAt),
          isTrue,
        );
      },
    );

    test('haber: hiçbir kaynak yoksa NewsFailure', () async {
      final repo = RssNewsRepository(
        createDio()
          ..httpClientAdapter = _FakeAdapter(
            (o) => throw DioException.connectionError(
              requestOptions: o,
              reason: 'x',
            ),
          ),
      );
      await expectLater(repo.latest(), throwsA(isA<NewsFailure>()));
    });
  });

  group('ViewModel', () {
    test('Rates: 10 kur ve önceki güne göre değişim', () async {
      final vm = RatesViewModel(repository: _FakeCurrency());
      var notified = 0;
      vm.addListener(() => notified++);
      await vm.load();
      expect(vm.status, ViewStatus.ready);
      expect(vm.quotes, hasLength(10));
      expect(vm.quotes.first.changePercent, greaterThan(0));
      expect(notified, 2, reason: 'busy, sonra ready');
      vm
        ..select('EUR')
        ..select('EUR');
      expect(vm.selected, 'EUR');
      expect(notified, 3, reason: 'aynı seçim tekrar bildirmez');
    });

    test('History: hafta sonu tekrarları bir kez; aralık değişir', () async {
      final repo = _FakeCurrency();
      final vm = HistoryViewModel(repository: repo)
        ..configure(code: 'USD', endDate: _latestDay);
      await vm.load();
      // 27.10–03.11: 8 gün, 31.10–01.11 hafta sonu → 6 farklı gün.
      expect(vm.history!.points, hasLength(6));
      await vm.showPeriod(HistoryPeriod.quarter);
      expect(vm.history!.period, HistoryPeriod.quarter);
      expect(vm.history!.changePercent, greaterThan(0));
    });

    test('History: eski istek yeni sonucun üzerine yazmaz', () async {
      final repo = _FakeCurrency()..gate = Completer();
      final vm = HistoryViewModel(repository: repo)
        ..configure(code: 'USD', endDate: _latestDay);
      final first = vm.load();
      final second = vm.showCurrency('EUR');
      repo.gate!.complete();
      await Future.wait([first, second]);
      expect(vm.history!.code, 'EUR');
      expect(vm.status, ViewStatus.ready);
    });

    test('News: süzgeç, sayım ve okundu', () async {
      final vm = NewsViewModel(repository: _FakeNews());
      await vm.load();
      expect(vm.articles, hasLength(3));
      expect(vm.mentioned.first, (code: 'USD', count: 2));
      vm.toggleFilter('CHF');
      expect(vm.visible, hasLength(1));
      vm.toggleFilter('CHF');
      expect(vm.filter, isNull);
      vm.markRead(vm.articles.first);
      expect(vm.isRead(vm.articles.first), isTrue);
    });

    test('Üst ViewModel: hepsini yükler, seçim grafiği değiştirir', () async {
      final repo = _FakeCurrency();
      final vm = _vm(repo, _FakeNews());
      await vm.init();
      expect(vm.rates.quotes, hasLength(10));
      expect(vm.history.history!.code, 'USD');
      expect(vm.news.articles, isNotEmpty);
      expect(vm.refreshedAt, isNotNull);

      await vm.selectCurrency('GBP');
      expect(vm.rates.selected, 'GBP');
      expect(vm.history.history!.code, 'GBP');
    });

    test('Üst ViewModel: bir bölüm çökerse diğerleri çalışır', () async {
      final vm = _vm(_FakeCurrency(), _FakeNews()..fail = true);
      await vm.init();
      expect(vm.news.status, ViewStatus.failure);
      expect(vm.news.error, 'Haber kaynaklarına ulaşılamadı.');
      expect(vm.rates.status, ViewStatus.ready);
    });

    test('dispose altları da kapatır; geç gelen cevap hata vermez', () async {
      final repo = _FakeCurrency()..gate = Completer();
      final vm = _vm(repo, _FakeNews());
      final loading = vm.init();
      vm.dispose();
      expect(vm.history.isDisposed, isTrue);
      repo.gate!.complete();
      await loading;
    });
  });

  testWidgets('ekran: kurlar, seçim, aralık ve haber modalı', (tester) async {
    await getIt.reset();
    SharedPreferences.setMockInitialValues({});
    await configureDependencies();
    getIt
      ..unregister<CurrencyRepository>()
      ..registerSingleton<CurrencyRepository>(_FakeCurrency())
      ..unregister<NewsRepository>()
      ..registerSingleton<NewsRepository>(_FakeNews());
    tester.view.physicalSize = const Size(1440, 3120);
    tester.view.devicePixelRatio = 3.75;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const HarcamaApp(watchNetwork: false));
    await tester.pumpAndSettle();
    await openLessonsHub(tester);
    final card = find.byKey(const Key('lessons_currency'));
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

    for (final c in kTrackedCurrencies) {
      expect(find.byKey(Key('quote_${c.code}')), findsOneWidget);
    }
    expect(find.text('🇺🇸 USD geçmişi'), findsOneWidget);

    await tester.tap(find.byKey(const Key('quote_EUR')));
    await tester.pumpAndSettle();
    expect(find.text('🇪🇺 EUR geçmişi'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('period_month')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('period_month')));
    await tester.pumpAndSettle();
    final history = tester
        .element(find.byKey(const Key('history_card')))
        .read<HistoryViewModel>();
    expect(history.period, HistoryPeriod.month);
    expect(
      find.text('${history.history!.points.length} nokta'),
      findsOneWidget,
    );

    final news = find.byKey(const Key('news_1'));
    await tester.scrollUntilVisible(
      news,
      300,
      scrollable: find.descendant(
        of: find.byKey(const Key('currency_scroll')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(news);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('news_detail')), findsOneWidget);
    expect(find.text('Anadolu Ajansı sitesinde oku'), findsOneWidget);
    expect(find.textContaining('okundu'), findsOneWidget);
  });
}
