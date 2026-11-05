import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ders/app/app.dart';
import 'package:flutter_ders/app/core/cache/app_image_cache.dart';
import 'package:flutter_ders/app/core/cache/image_fetchers.dart';
import 'package:flutter_ders/app/core/cache/image_memory_controller.dart';
import 'package:flutter_ders/app/core/cache/image_source.dart';
import 'package:flutter_ders/app/core/di/injection.dart';
import 'package:flutter_ders/app/models/image_demo_sources.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/lessons.dart';

/// Asset'teki gerçek PNG'ler (base64 çözülmüş).
final List<Uint8List> _pngs = [
  for (final g
      in (jsonDecode(File(kBase64Asset).readAsStringSync())
              as Map<String, Object?>)['gorseller']!
          as List)
    decodeBase64Image((g as Map<String, Object?>)['veri']! as String),
];

class _FakeFetcher implements ImageFetcher {
  int calls = 0;
  Completer<void>? gate;

  /// Sıradaki cevaplar; boşsa ilk PNG.
  final queue = <Uint8List>[];

  @override
  Future<Uint8List> fetch(
    CachedImageSource source, {
    FetchProgress? onProgress,
  }) async {
    calls++;
    await gate?.future;
    final bytes = queue.isEmpty ? _pngs.first : queue.removeAt(0);
    onProgress?.call(bytes.length, bytes.length);
    return bytes;
  }
}

class _Env {
  _Env() {
    cache = _make();
  }

  final dir = Directory.systemTemp.createTempSync('ders17_');
  final fetcher = _FakeFetcher();
  final memory = ImageCache();
  String _version = '1.0.0+1';
  late AppImageCache cache;

  AppImageCache _make() => AppImageCache(
    rootDirectory: () async => dir,
    appVersion: () async => _version,
    fetcher: fetcher,
    prefs: SharedPreferences.getInstance,
    memory: memory,
    maxRetries: 1,
  );

  /// Uygulama yeni sürümle yeniden açıldı.
  void relaunch(String version) {
    _version = version;
    cache = _make();
  }

  void dispose() => dir.deleteSync(recursive: true);
}

const _s3 = NetworkImageSource(
  'https://ornek.s3.amazonaws.com/a.png',
  name: 'a',
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Bütünlük', () {
    test('PNG/JPEG/GIF bitiş işaretleri', () {
      final png = _pngs.first;
      expect(hasCompleteStructure(png), isTrue);
      expect(hasCompleteStructure(png.sublist(0, png.length - 10)), isFalse);
      final jpeg = Uint8List.fromList([
        0xFF,
        0xD8,
        ...List.filled(20, 1),
        0xFF,
        0xD9,
      ]);
      expect(hasCompleteStructure(jpeg), isTrue);
      expect(hasCompleteStructure(jpeg.sublist(0, 15)), isFalse);
      final gif = Uint8List.fromList([
        0x47,
        0x49,
        0x46,
        ...List.filled(20, 0),
        0x3B,
      ]);
      expect(hasCompleteStructure(gif), isTrue);
      expect(hasCompleteStructure(Uint8List(4)), isFalse);
    });

    test('yarım PNG çözülebilir sayılmaz', () async {
      final png = _pngs.first;
      expect(await isDecodable(png), isTrue);
      expect(await isDecodable(png.sublist(0, png.length ~/ 2)), isFalse);
    });

    test('base64: data adresi ve çıplak metin; bozuğu reddeder', () {
      final raw = base64Encode(_pngs.first);
      expect(decodeBase64Image('data:image/png;base64,$raw'), _pngs.first);
      expect(decodeBase64Image(raw), _pngs.first);
      expect(
        () => decodeBase64Image('data:image/png;base64,***'),
        throwsA(isA<ImageFetchFailure>()),
      );
    });
  });

  group('AppImageCache', () {
    late _Env env;
    setUp(() => env = _Env());
    tearDown(() => env.dispose());

    test('ilk yükleme indirir, ikincisi diskten', () async {
      await env.cache.load(_s3);
      await env.cache.load(_s3);
      expect(env.fetcher.calls, 1);
      expect(env.cache.stats.downloads, 1);
      expect(env.cache.stats.diskHits, 1);
      expect(env.cache.diskUsage().files, 1);
    });

    test('aynı anda iki istek: tek indirme', () async {
      env.fetcher.gate = Completer();
      final a = env.cache.load(_s3);
      final b = env.cache.load(_s3);
      env.fetcher.gate!.complete();
      await Future.wait([a, b]);
      expect(env.fetcher.calls, 1);
      expect(env.cache.stats.sharedRequests, 1);
    });

    test('yarım gelen veri yeniden denenir; olmazsa diske yazılmaz', () async {
      final half = _pngs.first.sublist(0, 200);
      env.fetcher.queue.addAll([half, half]);
      await expectLater(env.cache.load(_s3), throwsA(isA<ImageFetchFailure>()));
      expect(env.cache.stats.retries, 1);
      expect(env.cache.diskUsage().files, 0);
      expect(
        env.dir
            .listSync(recursive: true)
            .where((f) => f.path.endsWith('.part')),
        isEmpty,
      );
      // Bir sonraki deneme sağlam gelir.
      await env.cache.load(_s3);
      expect(env.cache.diskUsage().files, 1);
    });

    test('diskte bozulan dosya silinip yeniden indirilir', () async {
      await env.cache.load(_s3);
      expect(await env.cache.corrupt(_s3), isTrue);
      final bytes = await env.cache.load(_s3);
      expect(bytes, _pngs.first);
      expect(env.cache.stats.corrupted, 1);
      expect(env.fetcher.calls, 2);
    });

    test('yeni sürüm: eski önbellek ve bellek boşalır', () async {
      final first = await env.cache.ensureReady();
      expect(first.previous, isNull);
      expect(first.cleared, isFalse);
      await env.cache.load(_s3);

      env.relaunch('1.0.0+1');
      final same = await env.cache.ensureReady();
      expect(same.cleared, isFalse);
      expect(env.cache.isOnDisk(_s3), isTrue);

      env.relaunch('1.1.0+2');
      final upgraded = await env.cache.ensureReady();
      expect(upgraded.previous, '1.0.0+1');
      expect(upgraded.cleared, isTrue);
      expect(upgraded.removedFiles, 1);
      expect(env.cache.isOnDisk(_s3), isFalse);
      await env.cache.load(_s3);
      expect(env.fetcher.calls, 2, reason: 'yeni sürümde yeniden indirilir');
    });
  });

  group('DefaultImageFetcher', () {
    test('HTTP: content-length eksik gelirse hata', () async {
      final dio = Dio()
        ..httpClientAdapter = _BytesAdapter(
          Uint8List.fromList([1, 2, 3]),
          contentLength: 10,
        );
      await expectLater(
        DefaultImageFetcher(dio).fetch(_s3),
        throwsA(
          isA<ImageFetchFailure>().having(
            (e) => e.message,
            'message',
            contains('Eksik indirme'),
          ),
        ),
      );
    });

    test('SFTP kaynağı bağlayıcıya gider', () async {
      SftpImageSource? asked;
      final fetcher = DefaultImageFetcher(
        Dio(),
        sftp: (s, _) async {
          asked = s;
          return _pngs.first;
        },
      );
      expect(await fetcher.fetch(kSftpSources.first), _pngs.first);
      expect(asked!.path, '/pub/example/KeyGenerator.png');
      expect(asked!.hostKeyFingerprints, kSftpHostKeys);
    });
  });

  group('ImageMemoryController', () {
    test('bütçe RAM\'in %2\'si, 48–256 MB arası', () {
      expect(ImageMemoryController.budgetFor(null), 100 << 20);
      expect(ImageMemoryController.budgetFor(1024), 48 << 20);
      expect(
        ImageMemoryController.budgetFor(8192),
        (8192 * 0.02 * (1 << 20)).round(),
      );
      expect(ImageMemoryController.budgetFor(16384), 256 << 20);
    });

    test('başlar, bütçeyi kurar; arka planda yarıya iner', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final cache = ImageCache();
      final c = ImageMemoryController(
        totalRamMb: () async => 12288,
        cache: cache,
        interval: const Duration(hours: 1),
        rss: () => 1,
      );
      final reasons = <TrimReason>[];
      c.trims.listen((t) => reasons.add(t.reason));
      await c.start();
      final budget = ImageMemoryController.budgetFor(12288);
      final atStart = cache.maximumSizeBytes;
      c.didChangeAppLifecycleState(AppLifecycleState.paused);
      final paused = cache.maximumSizeBytes;
      c.didChangeAppLifecycleState(AppLifecycleState.resumed);
      final resumed = cache.maximumSizeBytes;
      c.didHaveMemoryPressure();
      await Future<void>.delayed(Duration.zero);
      await c.dispose();
      expect(atStart, budget);
      expect(paused, budget ~/ 2);
      expect(resumed, budget);
      expect(reasons, [TrimReason.background, TrimReason.systemPressure]);
    });
  });

  testWidgets('ekran: önceden yükle → kaynak, sonra bellek; sürüm taklidi', (
    tester,
  ) async {
    final env = _Env();
    addTearDown(env.dispose);
    await getIt.reset();
    await configureDependencies();
    final memory = ImageMemoryController(
      totalRamMb: () async => 8192,
      interval: const Duration(hours: 1),
      rss: () => 0,
    );
    getIt
      ..unregister<AppImageCache>()
      ..registerSingleton<AppImageCache>(env.cache)
      ..unregister<ImageMemoryController>()
      ..registerSingleton<ImageMemoryController>(memory);
    tester.view.physicalSize = const Size(1440, 3120);
    tester.view.devicePixelRatio = 3.75;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const HarcamaApp(watchNetwork: false));
    await tester.pumpAndSettle();
    await openLessonsHub(tester);
    final card = find.byKey(const Key('lessons_imageCache'));
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
    // Asset okuma ve dosya işleri gerçek zamanlı.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('tile_Mavi gradyan')), findsOneWidget);

    await tester.tap(find.byKey(const Key('kind_s3')));
    await tester.pumpAndSettle();
    expect(find.byKey(Key('tile_${kS3Sources.first.label}')), findsOneWidget);

    await tester.tap(find.byKey(const Key('cache_precache')));
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
    }
    expect(find.textContaining('görsel hazır'), findsOneWidget);
    expect(find.text('Kaynak'), findsWidgets);

    await tester.tap(find.byKey(const Key('cache_precache')));
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    expect(find.text('Bellek'), findsWidgets);
    expect(env.fetcher.calls, kS3Sources.length, reason: 'yeniden indirilmedi');

    await tester.ensureVisible(find.byKey(const Key('cache_upgrade')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cache_upgrade')));
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    expect(find.textContaining('0.9.0+1 → 1.0.0+1'), findsOneWidget);
    expect(env.cache.diskUsage().files, 0);
    // Zamanlayıcı test bitmeden kapanmalı.
    await memory.dispose();
  });
}

class _BytesAdapter implements HttpClientAdapter {
  _BytesAdapter(this.bytes, {required this.contentLength});

  final Uint8List bytes;
  final int contentLength;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromBytes(
    bytes,
    200,
    headers: {
      'content-length': ['$contentLength'],
    },
  );

  @override
  void close({bool force = false}) {}
}
