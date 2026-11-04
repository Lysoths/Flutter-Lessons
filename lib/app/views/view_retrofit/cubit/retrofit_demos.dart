import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_ders/app/core/network/api_result.dart';
import 'package:flutter_ders/app/core/network/retrofit_client.dart';
import 'package:flutter_ders/app/models/post.dart';
import 'package:retrofit/retrofit.dart';

/// DERS 16 — Denemelerin grupları.
enum DemoGroup {
  /// GET, POST, PUT, PATCH, DELETE, HEAD, OPTIONS.
  methods('HTTP metotları'),

  /// Yol, sorgu, başlık.
  params('Parametreler'),

  /// JSON, form, multipart, gövdesiz.
  body('Gövde türleri'),

  /// İptal, ilerleme, extra, options, cache.
  dio('Dio özellikleri'),

  /// HttpResponse, CallAdapter, hata kodları.
  response('Cevap ve hata');

  const DemoGroup(this.label);

  /// Görünen ad.
  final String label;
}

/// Bir denemenin kullanıcıdan aldığı değer.
typedef DemoInput = ({String key, String label, String initial, bool numeric});

/// Çalışan denemeye verilen kancalar (ilerleme, iptal).
typedef DemoHooks = ({
  ProgressCallback onSendProgress,
  ProgressCallback onReceiveProgress,
  CancelToken cancelToken,
});

/// Bir retrofit özelliğinin canlı denemesi.
class RetrofitDemo {
  /// Deneme oluşturur.
  const RetrofitDemo({
    required this.id,
    required this.group,
    required this.annotation,
    required this.title,
    required this.description,
    required this.code,
    required this.run,
    this.inputs = const [],
    this.cancellable = false,
    this.showsProgress = false,
  });

  /// Kimlik (anahtar ve test için).
  final String id;

  /// Grup.
  final DemoGroup group;

  /// Kullanılan anotasyon(lar), ör. `@GET + @Path`.
  final String annotation;

  /// Başlık.
  final String title;

  /// Kısa açıklama.
  final String description;

  /// Arayüzdeki tanımı.
  final String code;

  /// Kullanıcının değiştirebileceği değerler.
  final List<DemoInput> inputs;

  /// Çalışırken "İptal" düğmesi gösterilsin mi?
  final bool cancellable;

  /// İlerleme çubuğu gösterilsin mi?
  final bool showsProgress;

  /// İsteği atar; dönen Dart nesnesi ekranda gösterilir.
  final Future<Object?> Function(
    RetrofitClient api,
    Map<String, String> input,
    DemoHooks hooks,
  )
  run;
}

DemoInput _text(String key, String label, String initial) =>
    (key: key, label: label, initial: initial, numeric: false);

DemoInput _number(String key, String label, int initial) =>
    (key: key, label: label, initial: '$initial', numeric: true);

int _int(Map<String, String> input, String key, [int fallback = 1]) =>
    int.tryParse(input[key]?.trim() ?? '') ?? fallback;

String _str(Map<String, String> input, String key) => input[key]?.trim() ?? '';

/// Tüm denemeler, ekrandaki sırayla.
final List<RetrofitDemo> kRetrofitDemos = [
  // ── HTTP metotları ────────────────────────────────────────────────────
  RetrofitDemo(
    id: 'get',
    group: DemoGroup.methods,
    annotation: '@GET + @Path',
    title: 'Tek kaydı getir',
    description:
        'Yoldaki {id} yerine parametre yazılır; cevap Post.fromJson ile '
        'tipli nesneye çevrilir.',
    code: "@GET('/posts/{id}')\nFuture<Post> getPost(@Path('id') int id);",
    inputs: [_number('id', 'id (1–100)', 1)],
    run: (api, i, _) => api.posts.getPost(_int(i, 'id')),
  ),
  RetrofitDemo(
    id: 'post',
    group: DemoGroup.methods,
    annotation: '@POST + @Body',
    title: 'Yeni kayıt oluştur',
    description:
        'Nesne toJson ile JSON gövdeye çevrilir. Sunucu 201 döner ve yeni '
        'kimliği (101) verir; sahte sunucu olduğu için kaydetmez.',
    code: "@POST('/posts')\nFuture<Post> createPost(@Body() PostDraft draft);",
    inputs: [
      _text('title', 'Başlık', 'Retrofit dersi'),
      _text('body', 'Metin', 'POST ile gönderildi.'),
    ],
    run: (api, i, _) => api.posts.createPost(
      PostDraft(userId: 1, title: _str(i, 'title'), body: _str(i, 'body')),
    ),
  ),
  RetrofitDemo(
    id: 'put',
    group: DemoGroup.methods,
    annotation: '@PUT',
    title: 'Kaydı tamamen değiştir',
    description:
        'PUT kaydın TAMAMINI gönderilen gövdeyle değiştirir; gönderilmeyen '
        'alan silinmiş sayılır.',
    code:
        "@PUT('/posts/{id}')\nFuture<Post> replacePost(\n"
        "  @Path('id') int id, @Body() PostDraft draft);",
    inputs: [
      _number('id', 'id', 1),
      _text('title', 'Yeni başlık', 'Baştan yazıldı'),
      _text('body', 'Yeni metin', 'PUT: her alan yeniden.'),
    ],
    run: (api, i, _) => api.posts.replacePost(
      _int(i, 'id'),
      PostDraft(userId: 1, title: _str(i, 'title'), body: _str(i, 'body')),
    ),
  ),
  RetrofitDemo(
    id: 'patch',
    group: DemoGroup.methods,
    annotation: '@PATCH',
    title: 'Kaydın bir alanını değiştir',
    description:
        'PATCH yalnızca gönderilen alanları değiştirir. Cevapta metin (body) '
        'eski hâliyle durur, yalnızca başlık değişir.',
    code:
        "@PATCH('/posts/{id}')\nFuture<Post> patchPost(\n"
        "  @Path('id') int id, @Body() Map<String, dynamic> changes);",
    inputs: [
      _number('id', 'id', 1),
      _text('title', 'Yeni başlık', 'Yalnız başlık'),
    ],
    run: (api, i, _) =>
        api.posts.patchPost(_int(i, 'id'), {'title': _str(i, 'title')}),
  ),
  RetrofitDemo(
    id: 'delete',
    group: DemoGroup.methods,
    annotation: '@DELETE',
    title: 'Kaydı sil',
    description:
        'Cevap gövdesi boş; sonucu durum kodundan anlarız (200). Bu yüzden '
        'dönüş tipi HttpResponse<void>.',
    code:
        "@DELETE('/posts/{id}')\n"
        "Future<HttpResponse<void>> deletePost(@Path('id') int id);",
    inputs: [_number('id', 'id', 1)],
    run: (api, i, _) => api.posts.deletePost(_int(i, 'id')),
  ),
  RetrofitDemo(
    id: 'head',
    group: DemoGroup.methods,
    annotation: '@HEAD',
    title: 'Yalnızca başlıkları al',
    description:
        'GET ile aynı ama gövde gelmez. Dosyayı indirmeden boyutunu '
        '(content-length) ya da var olup olmadığını öğrenmek için.',
    code: "@HEAD('/get')\nFuture<HttpResponse<void>> head();",
    run: (api, _, _) => api.echo.head(),
  ),
  RetrofitDemo(
    id: 'options',
    group: DemoGroup.methods,
    annotation: '@OPTIONS',
    title: 'İzin verilen metotları sor',
    description:
        'Sunucu bu adreste hangi metotları kabul ettiğini `allow` başlığında '
        'söyler. Tarayıcılar CORS ön kontrolünde bunu kullanır.',
    code: "@OPTIONS('/anything')\nFuture<HttpResponse<void>> options();",
    run: (api, _, _) => api.echo.options(),
  ),

  // ── Parametreler ──────────────────────────────────────────────────────
  RetrofitDemo(
    id: 'query',
    group: DemoGroup.params,
    annotation: '@Query',
    title: 'Sorgu parametresi',
    description:
        'Adresin sonuna ?userId=1 eklenir; kullanıcının yazıları gelir.',
    code:
        "@GET('/posts')\n"
        "Future<List<Post>> getPostsByUser(@Query('userId') int userId);",
    inputs: [_number('userId', 'userId (1–10)', 1)],
    run: (api, i, _) => api.posts.getPostsByUser(_int(i, 'userId')),
  ),
  RetrofitDemo(
    id: 'queries',
    group: DemoGroup.params,
    annotation: '@Queries',
    title: 'Map ile çok sorgu',
    description:
        'Bir Map\'in her anahtarı ayrı sorgu parametresi olur. Boş bırakılan '
        'değer adrese eklenmez.',
    code:
        "@GET('/comments')\nFuture<List<Comment>> getComments(\n"
        '  @Queries() Map<String, dynamic> filters);',
    inputs: [
      _number('postId', 'postId', 1),
      _text('email', 'email (boş olabilir)', ''),
    ],
    run: (api, i, _) => api.posts.getComments({
      'postId': _int(i, 'postId'),
      if (_str(i, 'email').isNotEmpty) 'email': _str(i, 'email'),
    }),
  ),
  RetrofitDemo(
    id: 'headers',
    group: DemoGroup.params,
    annotation: '@Headers + @Header',
    title: 'İstek başlıkları',
    description:
        '@Headers her istekte aynı başlıkları ekler; @Header değeri çağrıda '
        'verilir. httpbin gelen başlıkları geri yansıtır.',
    code:
        "@Headers({'X-Ders': '16', 'Accept': 'application/json'})\n"
        "@GET('/headers')\n"
        "Future<Map<String, dynamic>> headers(@Header('X-Kullanici') String user);",
    inputs: [_text('user', 'X-Kullanici', 'ogrenci')],
    run: (api, i, _) => api.echo.headers(_str(i, 'user')),
  ),

  // ── Gövde türleri ─────────────────────────────────────────────────────
  RetrofitDemo(
    id: 'form',
    group: DemoGroup.body,
    annotation: '@FormUrlEncoded + @Field',
    title: 'Form gövdesi',
    description:
        'HTML formu gibi ad=Ayşe&yas=30 biçiminde gider '
        '(application/x-www-form-urlencoded). httpbin "form" alanında gösterir.',
    code:
        "@FormUrlEncoded()\n@POST('/post')\nFuture<Map<String, dynamic>> form(\n"
        "  @Field('ad') String name, @Field('yas') int age);",
    inputs: [_text('name', 'ad', 'Ayşe'), _number('age', 'yaş', 30)],
    run: (api, i, _) => api.echo.form(_str(i, 'name'), _int(i, 'age', 30)),
  ),
  RetrofitDemo(
    id: 'null',
    group: DemoGroup.body,
    annotation: '@PreventNullToAbsent',
    title: 'null alan: çıkar mı, gider mi?',
    description:
        'Aynı null değer iki kez gönderilir. Varsayılanda alan gövdeden '
        'çıkarılır ({}); @PreventNullToAbsent ile {"not": null} gider.',
    code:
        "@PreventNullToAbsent()\n@POST('/post')\n"
        "Future<Map<String, dynamic>> nullField(@Field('not') String? note);",
    inputs: [_text('note', 'not (boş = null)', '')],
    run: (api, i, _) async {
      final note = _str(i, 'note').isEmpty ? null : _str(i, 'note');
      final absent = await api.echo.absentField(note);
      final kept = await api.echo.nullField(note);
      return {
        'varsayılan': absent['json'],
        '@PreventNullToAbsent': kept['json'],
      };
    },
  ),
  RetrofitDemo(
    id: 'multipart',
    group: DemoGroup.body,
    annotation: '@MultiPart + @Part + @SendProgress',
    title: 'Dosya yükle',
    description:
        'multipart/form-data: metin alanı ve dosya aynı gövdede. Yükleme '
        'ilerlemesi @SendProgress ile gelir.',
    code:
        "@MultiPart()\n@POST('/post')\nFuture<Map<String, dynamic>> upload(\n"
        "  @Part(name: 'aciklama') String description,\n"
        "  @Part(name: 'dosya', fileName: 'ders16.txt') List<int> file,\n"
        '  @SendProgress() ProgressCallback? onSendProgress);',
    inputs: [
      _text('desc', 'aciklama', 'Ders 16 dosyası'),
      _number('kb', 'boyut (KB)', 256),
    ],
    showsProgress: true,
    run: (api, i, h) async {
      final size = _int(i, 'kb', 256).clamp(1, 2048) * 1024;
      final bytes = utf8
          .encode('Retrofit dersi. ' * (size ~/ 16 + 1))
          .sublist(0, size);
      final r = await api.echo.upload(_str(i, 'desc'), bytes, h.onSendProgress);
      return {
        'form': r['form'],
        'files': {
          for (final e in ((r['files'] as Map?) ?? const {}).entries)
            e.key: '${'${e.value}'.length} karakter geldi',
        },
      };
    },
  ),
  RetrofitDemo(
    id: 'bodyextra',
    group: DemoGroup.body,
    annotation: '@Body + @BodyExtra',
    title: 'Gövdeye ek alan kat',
    description:
        'Var olan gövdeye DTO yazmadan tek alan eklenir; ikisi tek JSON '
        'olarak gider.',
    code:
        "@POST('/post')\nFuture<Map<String, dynamic>> bodyExtra(\n"
        '  @Body() Map<String, dynamic> body,\n'
        "  @BodyExtra('gonderim') String sentAt);",
    inputs: [_text('title', 'baslik', 'Ek alan')],
    run: (api, i, _) async => (await api.echo.bodyExtra({
      'baslik': _str(i, 'title'),
    }, DateTime.now().toIso8601String()))['json'],
  ),
  RetrofitDemo(
    id: 'nobody',
    group: DemoGroup.body,
    annotation: '@NoBody',
    title: 'Gövdesiz POST',
    description:
        'Bazı servisler POST\'ta gövde istemez (ör. "işlemi başlat"). '
        'content-length 0 gider.',
    code: "@NoBody()\n@POST('/post')\nFuture<Map<String, dynamic>> noBody();",
    run: (api, _, _) async {
      final r = await api.echo.noBody();
      return {'data': r['data'], 'json': r['json']};
    },
  ),

  // ── Dio özellikleri ───────────────────────────────────────────────────
  RetrofitDemo(
    id: 'cancel',
    group: DemoGroup.dio,
    annotation: '@CancelRequest',
    title: 'İsteği iptal et',
    description:
        'Sunucu 5 sn bekletir. Beklerken "İptal"e bas: CancelToken isteği '
        'keser, DioException(cancel) gelir.',
    code:
        "@GET('/delay/5')\nFuture<Map<String, dynamic>> slow(\n"
        '  @CancelRequest() CancelToken cancelToken);',
    cancellable: true,
    run: (api, _, h) => api.echo.slow(h.cancelToken),
  ),
  RetrofitDemo(
    id: 'download',
    group: DemoGroup.dio,
    annotation: '@DioResponseType + @ReceiveProgress',
    title: 'Bayt indir, ilerlemeyi izle',
    description:
        'Cevap JSON değil ham bayt (ResponseType.bytes). İndirme ilerlemesi '
        '@ReceiveProgress ile gelir.',
    code:
        '@DioResponseType(ResponseType.bytes)\n'
        "@GET('/bytes/{size}')\nFuture<List<int>> download(\n"
        "  @Path('size') int size,\n"
        '  @ReceiveProgress() ProgressCallback? onReceiveProgress);',
    inputs: [_number('size', 'bayt (en çok 102400)', 102400)],
    showsProgress: true,
    run: (api, i, h) async {
      final bytes = await api.echo.download(
        _int(i, 'size', 102400).clamp(1, 102400),
        h.onReceiveProgress,
      );
      return '${bytes.length} bayt geldi · ilk 8: ${bytes.take(8).toList()}';
    },
  ),
  RetrofitDemo(
    id: 'extra',
    group: DemoGroup.dio,
    annotation: '@Extra + @Extras',
    title: 'İsteğe ağa gitmeyen not ekle',
    description:
        'Extra sunucuya GİTMEZ; yalnızca interceptor\'lar görür (ör. "bu '
        'isteğe token ekleme"). Aşağıdaki kayıtta "extra" satırına bak.',
    code:
        "@Extra({'ders': 16})\n@GET('/get')\n"
        'Future<Map<String, dynamic>> extras(@Extras() Map<String, dynamic> extras);',
    inputs: [_text('note', 'extras: not', 'yalnızca-yerel')],
    run: (api, i, _) async {
      final r = await api.echo.extras({'not': _str(i, 'note')});
      return {'sunucunun gördüğü başlıklar': r['headers']};
    },
  ),
  RetrofitDemo(
    id: 'options_timeout',
    group: DemoGroup.dio,
    annotation: '@DioOptions',
    title: 'Tek isteğe özel ayar',
    description:
        'Options yalnızca bu çağrıya uygulanır. Sunucu 3 sn bekletir, '
        'zaman aşımı 1 sn: receiveTimeout hatası gelir. Süreyi artırıp dene.',
    code:
        "@GET('/delay/{seconds}')\nFuture<Map<String, dynamic>> withOptions(\n"
        "  @Path('seconds') int seconds, @DioOptions() Options options);",
    inputs: [
      _number('seconds', 'sunucu bekletmesi (sn)', 3),
      _number('timeout', 'zaman aşımı (sn)', 1),
    ],
    run: (api, i, _) => api.echo.withOptions(
      _int(i, 'seconds', 3).clamp(0, 8),
      Options(receiveTimeout: Duration(seconds: _int(i, 'timeout'))),
    ),
  ),
  RetrofitDemo(
    id: 'cache',
    group: DemoGroup.dio,
    annotation: '@CacheControl',
    title: 'Cache-Control başlığı',
    description:
        'Anotasyondaki değerlerden "max-age=60, no-transform" başlığı kurulur. '
        'Önbelleği yapan Dio değil; bir cache interceptor ya da sunucu okur.',
    code:
        '@CacheControl(maxAge: 60, noTransform: true)\n'
        "@GET('/headers')\nFuture<Map<String, dynamic>> cacheControl();",
    run: (api, _, _) async => {
      'Cache-Control':
          ((await api.echo.cacheControl())['headers']
              as Map?)?['Cache-Control'],
    },
  ),

  // ── Cevap ve hata ─────────────────────────────────────────────────────
  RetrofitDemo(
    id: 'httpresponse',
    group: DemoGroup.response,
    annotation: 'HttpResponse<T>',
    title: 'Veri + ham cevap',
    description:
        'Yalnızca Post değil, durum kodu ve başlıklar da gelir: '
        'r.data → Post, r.response.statusCode → 200.',
    code:
        "@GET('/posts/{id}')\n"
        "Future<HttpResponse<Post>> getPostWithResponse(@Path('id') int id);",
    inputs: [_number('id', 'id', 2)],
    run: (api, i, _) => api.posts.getPostWithResponse(_int(i, 'id', 2)),
  ),
  RetrofitDemo(
    id: 'adapter',
    group: DemoGroup.response,
    annotation: '@UseCallAdapter',
    title: 'Hata fırlatmayan çağrı',
    description:
        'ResultCallAdapter, Future<Post>\'u Future<ApiResult<Post>>\'a çevirir. '
        '9999 dene: 404 istisna olarak değil ApiFailure DEĞERİ olarak gelir.',
    code:
        '@UseCallAdapter(ResultCallAdapter)\n'
        "@GET('/posts/{id}')\n"
        "Future<ApiResult<Post>> safeGetPost(@Path('id') int id);",
    inputs: [_number('id', 'id (9999 = yok)', 9999)],
    run: (api, i, _) => api.posts.safeGetPost(_int(i, 'id', 9999)),
  ),
  RetrofitDemo(
    id: 'status',
    group: DemoGroup.response,
    annotation: 'DioException',
    title: 'Sunucu hatası',
    description:
        'İstenen durum kodu döner. 2xx dışı kodlarda Dio DioException '
        '(badResponse) fırlatır; ekran onu Türkçe mesaja çevirir.',
    code:
        "@GET('/status/{code}')\n"
        "Future<HttpResponse<void>> status(@Path('code') int code);",
    inputs: [_number('code', 'durum kodu', 404)],
    run: (api, i, _) => api.echo.status(_int(i, 'code', 404).clamp(100, 599)),
  ),
];

/// Dönen Dart nesnesini ekranda gösterilecek metne çevirir: tipiyle birlikte.
({String type, String text}) describeResult(Object? value) {
  const json = JsonEncoder.withIndent('  ');
  String pretty(Object? v) {
    try {
      return json.convert(v);
    } on Object {
      return '$v';
    }
  }

  return switch (value) {
    null => (type: 'void', text: '(gövde yok)'),
    final Post p => (type: 'Post', text: pretty(p.toJson())),
    final List<Post> l => (
      type: 'List<Post> · ${l.length} öğe',
      text: l.map((p) => '#${p.id} ${p.title}').join('\n'),
    ),
    final List<Comment> l => (
      type: 'List<Comment> · ${l.length} öğe',
      text: l.map((c) => '#${c.id} ${c.name}').join('\n'),
    ),
    final HttpResponse<Object?> r => (
      type: 'HttpResponse<${r.data == null ? 'void' : r.data.runtimeType}>',
      text:
          'response.statusCode: ${r.response.statusCode}\n'
          'response.headers:\n'
          '${(r.response.headers.map.entries.toList()..sort((a, b) => a.key.compareTo(b.key))).map((e) => '  ${e.key}: ${e.value.join(', ')}').join('\n')}'
          '${r.data == null ? '' : '\n\ndata:\n${describeResult(r.data).text}'}',
    ),
    final ApiSuccess<Post> s => (
      type: 'ApiSuccess<Post>',
      text: pretty(s.data.toJson()),
    ),
    final ApiFailure<Object?> f => (
      type: 'ApiFailure',
      text: 'message: ${f.message}\nstatusCode: ${f.statusCode}',
    ),
    final String s => (type: 'String', text: s),
    // Çalışma anındaki iç tip (CastMap, _Map) yerine bildirilen tip.
    final Map<Object?, Object?> m => (
      type: 'Map<String, Object?>',
      text: pretty(m),
    ),
    _ => (type: value.runtimeType.toString(), text: pretty(value)),
  };
}
