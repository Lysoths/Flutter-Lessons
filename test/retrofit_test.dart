import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ders/app/app.dart';
import 'package:flutter_ders/app/core/di/injection.dart';
import 'package:flutter_ders/app/core/network/api_result.dart';
import 'package:flutter_ders/app/core/network/recording_interceptor.dart';
import 'package:flutter_ders/app/core/network/retrofit_client.dart';
import 'package:flutter_ders/app/models/post.dart';
import 'package:flutter_ders/app/views/view_retrofit/cubit/retrofit_demos.dart';
import 'package:flutter_ders/app/views/view_retrofit/cubit/retrofit_lab_cubit.dart';
import 'package:flutter_ders/app/views/view_retrofit/cubit/retrofit_lab_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/lessons.dart';

const _post = {'id': 1, 'userId': 1, 'title': 'Başlık', 'body': 'Metin'};

/// Gerçek ağa çıkmadan cevap veren bağdaştırıcı; gelen istekleri saklar.
class _FakeServer implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  final bodies = <String>[];
  Duration delay = Duration.zero;

  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(o);
    final chunks = await requestStream?.toList() ?? const [];
    bodies.add(utf8.decode([for (final c in chunks) ...c]));
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    final path = o.uri.path;
    ResponseBody json(Object body, [int status = 200]) =>
        ResponseBody.fromString(
          jsonEncode(body),
          status,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        );
    if (path == '/posts/9999') return json(const <String, Object?>{}, 404);
    if (path.startsWith('/status/')) {
      return json(const <String, Object?>{}, int.parse(path.split('/').last));
    }
    if (path == '/posts') {
      return o.method == 'POST'
          ? json({
              ...?(o.data as Map?)?.cast<String, Object?>(),
              'id': 101,
            }, 201)
          : json([
              _post,
              {..._post, 'id': 2},
            ]);
    }
    if (path.startsWith('/posts/')) return json(_post);
    if (path == '/comments') return json(const <Object?>[]);
    return json({
      'json': o.data is FormData ? null : o.data,
      'headers': o.headers,
    });
  }

  @override
  void close({bool force = false}) {}
}

({RetrofitClient api, _FakeServer server}) _client() {
  final server = _FakeServer();
  final dio = Dio()..httpClientAdapter = server;
  return (api: RetrofitClient(dio: dio), server: server);
}

void main() {
  group('PostsApi (üretilen kod)', () {
    test('@GET + @Path: JSON tipli Post olur', () async {
      final c = _client();
      final post = await c.api.posts.getPost(7);
      expect(post, isA<Post>());
      expect(post.title, 'Başlık');
      expect(
        c.server.requests.single.uri.toString(),
        'https://jsonplaceholder.typicode.com/posts/7',
      );
    });

    test('@Query ve @Queries adrese yazılır', () async {
      final c = _client();
      await c.api.posts.getPostsByUser(3);
      await c.api.posts.getComments({'postId': 1, 'email': 'a@b.c'});
      expect(c.server.requests[0].uri.query, 'userId=3');
      expect(c.server.requests[1].uri.queryParameters, {
        'postId': '1',
        'email': 'a@b.c',
      });
    });

    test(
      '@Body nesneyi JSON gövdeye çevirir; PATCH yalnız alanı gönderir',
      () async {
        final c = _client();
        final created = await c.api.posts.createPost(
          const PostDraft(userId: 1, title: 'Yeni', body: 'B'),
        );
        expect(created.id, 101);
        expect(jsonDecode(c.server.bodies[0]), {
          'userId': 1,
          'title': 'Yeni',
          'body': 'B',
        });
        await c.api.posts.patchPost(1, {'title': 'T'});
        expect(c.server.requests[1].method, 'PATCH');
        expect(jsonDecode(c.server.bodies[1]), {'title': 'T'});
      },
    );

    test('HttpResponse durum kodunu verir', () async {
      final c = _client();
      final r = await c.api.posts.deletePost(1);
      expect(r.response.statusCode, 200);
      expect(c.server.requests.single.method, 'DELETE');
    });

    test('@UseCallAdapter: 404 istisna değil ApiFailure değeri', () async {
      final c = _client();
      final ok = await c.api.posts.safeGetPost(1);
      final missing = await c.api.posts.safeGetPost(9999);
      expect(ok, isA<ApiSuccess<Post>>());
      expect(
        missing,
        isA<ApiFailure<Post>>().having((f) => f.statusCode, 'statusCode', 404),
      );
    });
  });

  group('EchoApi (üretilen kod)', () {
    test('@Headers sabit, @Header çağrıdan', () async {
      final c = _client();
      await c.api.echo.headers('ogrenci');
      final h = c.server.requests.single.headers;
      expect(h['X-Ders'], '16');
      expect(h['X-Kullanici'], 'ogrenci');
    });

    test('@FormUrlEncoded: ad=…&yas=… gövdesi', () async {
      final c = _client();
      await c.api.echo.form('Ayşe', 30);
      expect(
        c.server.requests.single.contentType,
        Headers.formUrlEncodedContentType,
      );
      expect(Uri.splitQueryString(c.server.bodies.single), {
        'ad': 'Ayşe',
        'yas': '30',
      });
    });

    test(
      'null alan: varsayılan çıkarır, @PreventNullToAbsent gönderir',
      () async {
        final c = _client();
        await c.api.echo.absentField(null);
        await c.api.echo.nullField(null);
        expect(jsonDecode(c.server.bodies[0]), <String, Object?>{});
        expect(jsonDecode(c.server.bodies[1]), {'not': null});
      },
    );

    test('@NoBody, @CacheControl, @Extra, @DioOptions', () async {
      final c = _client();
      await c.api.echo.noBody();
      await c.api.echo.cacheControl();
      await c.api.echo.extras({'not': 'yerel'});
      await c.api.echo.withOptions(
        0,
        Options(receiveTimeout: const Duration(seconds: 1)),
      );
      final r = c.server.requests;
      expect(r[0].data, isNull);
      expect(r[1].headers['Cache-Control'], 'max-age=60, no-transform');
      expect(r[2].extra, containsPair('ders', 16));
      expect(r[2].extra, containsPair('not', 'yerel'));
      expect(r[2].headers.containsKey('not'), isFalse, reason: 'ağa gitmez');
      expect(r[3].receiveTimeout, const Duration(seconds: 1));
    });

    test('@MultiPart: alan ve dosya; @SendProgress ilerleme verir', () async {
      final c = _client();
      final progress = <double>[];
      await c.api.echo.upload(
        'açıklama',
        List.filled(4096, 65),
        (sent, total) => progress.add(sent / total),
      );
      final body = c.server.bodies.single;
      expect(body, contains('name="aciklama"'));
      expect(body, contains('filename="ders16.txt"'));
      expect(progress.last, 1);
    });
  });

  group('RetrofitLabCubit', () {
    RetrofitDemo demo(String id) =>
        kRetrofitDemos.firstWhere((d) => d.id == id);

    test('her deneme benzersiz kimlikli ve bir gruba ait', () {
      final ids = kRetrofitDemos.map((d) => d.id).toSet();
      expect(ids.length, kRetrofitDemos.length);
      for (final g in DemoGroup.values) {
        expect(kRetrofitDemos.where((d) => d.group == g), isNotEmpty);
      }
    });

    test('çalıştırma: sonuç tipi ve isteğin denemeye etiketlenmesi', () async {
      final c = _client();
      final cubit = RetrofitLabCubit(api: c.api);
      await cubit.run(demo('get'), {'id': '5'});
      await pumpEventQueue();
      final run = cubit.state.runs['get']!;
      expect(run.status, RunStatus.success);
      expect(run.resultType, 'Post');
      expect(run.exchanges.single.demoId, 'get');
      expect(run.exchanges.single.statusCode, 200);
      expect(cubit.state.log, hasLength(1));
      await cubit.close();
    });

    test('hata ve CallAdapter sonucu failure olarak görünür', () async {
      final c = _client();
      final cubit = RetrofitLabCubit(api: c.api);
      await cubit.run(demo('status'), {'code': '500'});
      await cubit.run(demo('adapter'), {'id': '9999'});
      expect(cubit.state.runs['status']!.error, 'Sunucu 500 döndürdü.');
      expect(cubit.state.runs['adapter']!.status, RunStatus.failure);
      expect(cubit.state.runs['adapter']!.resultType, 'ApiFailure');
      await cubit.close();
    });

    test('iptal: CancelToken isteği keser', () async {
      final c = _client();
      c.server.delay = const Duration(seconds: 2);
      final cubit = RetrofitLabCubit(api: c.api);
      final running = cubit.run(demo('cancel'), const {});
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(cubit.state.runs['cancel']!.status, RunStatus.running);
      cubit.cancel(demo('cancel'));
      await running;
      expect(cubit.state.runs['cancel']!.status, RunStatus.cancelled);
      await cubit.close();
    });

    test('grup süzgeci', () async {
      final cubit = RetrofitLabCubit(api: _client().api)
        ..showGroup(DemoGroup.body);
      expect(
        cubit.state.visible.every((d) => d.group == DemoGroup.body),
        isTrue,
      );
      cubit.showGroup(null);
      expect(cubit.state.visible, hasLength(kRetrofitDemos.length));
      await cubit.close();
    });
  });

  test('describeBody: JSON girintili, bayt özet', () {
    expect(describeBody({'a': 1}), '{\n  "a": 1\n}');
    expect(describeBody(List.filled(10, 0)), '10 bayt (ham veri)');
    expect(describeBody(''), isNull);
  });

  testWidgets('ekran: kartı aç, gönder, sonucu ve ağ kaydını gör', (
    tester,
  ) async {
    await getIt.reset();
    SharedPreferences.setMockInitialValues({});
    await configureDependencies();
    final c = _client();
    getIt
      ..unregister<RetrofitClient>()
      ..registerSingleton<RetrofitClient>(c.api);
    tester.view.physicalSize = const Size(1440, 3120);
    tester.view.devicePixelRatio = 3.75;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const HarcamaApp(watchNetwork: false));
    await tester.pumpAndSettle();
    await openLessonsHub(tester);
    final card = find.byKey(const Key('lessons_retrofit'));
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

    await tester.tap(find.byKey(const Key('demo_get')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('input_get_id')), '3');
    await tester.ensureVisible(find.byKey(const Key('send_get')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('send_get')));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('result_get')), findsOneWidget);
    expect(c.server.requests.single.uri.path, '/posts/3');
    expect(find.text('Ağdan geçenler (1)'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const Key('retrofit_group_body')),
      -300,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('retrofit_list')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('retrofit_group_body')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('demo_get')), findsNothing);
    expect(find.byKey(const Key('demo_form')), findsOneWidget);

    await tester.tap(find.byKey(const Key('retrofit_log')));
    await tester.pumpAndSettle();
    expect(find.text('Ağ kaydı (1)'), findsOneWidget);
  });
}
