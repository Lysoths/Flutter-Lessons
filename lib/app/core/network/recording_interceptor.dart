import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

/// DERS 16 — Ağdan geçen bir istek ve cevabı (ekranda gösterilir).
class NetworkExchange {
  /// Kayıt oluşturur.
  NetworkExchange({
    required this.method,
    required this.url,
    required this.requestHeaders,
    required this.requestBody,
    required this.extra,
    required this.startedAt,
    this.demoId,
  });

  /// Bu isteği atan ekran denemesi (Zone'dan okunur; bkz. [RecordingInterceptor.zoneKey]).
  final String? demoId;

  /// HTTP metodu.
  final String method;

  /// Tam adres (sorgu dahil).
  final Uri url;

  /// Giden başlıklar.
  final Map<String, String> requestHeaders;

  /// Giden gövdenin okunur hâli.
  final String? requestBody;

  /// `@Extra` / `@Extras` ile eklenen, ağa gitmeyen bilgiler.
  final Map<String, Object?> extra;

  /// İsteğin başladığı an.
  final DateTime startedAt;

  /// Durum kodu.
  int? statusCode;

  /// Gelen başlıklar.
  Map<String, String> responseHeaders = const {};

  /// Gelen gövdenin okunur hâli.
  String? responseBody;

  /// Hata açıklaması.
  String? error;

  /// Süre.
  Duration? took;
}

/// Her isteği kaydeden Dio interceptor'u. Retrofit'in ürettiği kod Dio
/// kullandığı için, retrofit'le atılan her istek buradan geçer.
///
///   onRequest  → istek çıkmadan önce
///   onResponse → cevap geldikten sonra
///   onError    → hata olursa
class RecordingInterceptor extends Interceptor {
  final _controller = StreamController<NetworkExchange>.broadcast();

  /// İsteği kaydı biten her alışveriş.
  Stream<NetworkExchange> get exchanges => _controller.stream;

  static const _key = 'ders16_exchange';

  /// İsteği hangi denemenin attığını taşıyan Zone anahtarı.
  ///
  /// `runZoned(() => api.getPost(1), zoneValues: {zoneKey: 'get'})`:
  /// retrofit metodunun imzasına dokunmadan, o çağrının içinden çıkan her
  /// isteğe etiket konur (async zincir Zone'u taşır).
  static const zoneKey = #ders16Demo;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[_key] = NetworkExchange(
      method: options.method,
      url: options.uri,
      requestHeaders: {
        for (final e in options.headers.entries) e.key: '${e.value}',
        'content-type': ?options.contentType,
      },
      requestBody: describeBody(options.data),
      extra: {
        for (final e in options.extra.entries)
          if (e.key != _key) e.key: e.value,
      },
      startedAt: DateTime.now(),
      demoId: Zone.current[zoneKey] as String?,
    );
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    _finish(response.requestOptions, response: response);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _finish(err.requestOptions, response: err.response, error: err);
    handler.next(err);
  }

  void _finish(
    RequestOptions options, {
    Response<dynamic>? response,
    DioException? error,
  }) {
    final exchange = options.extra[_key];
    if (exchange is! NetworkExchange) return;
    exchange
      ..statusCode = response?.statusCode
      ..responseHeaders = {
        for (final e
            in response?.headers.map.entries ??
                const <MapEntry<String, List<String>>>[])
          e.key: e.value.join(', '),
      }
      ..responseBody = describeBody(response?.data)
      ..error = error?.message ?? error?.type.name
      ..took = DateTime.now().difference(exchange.startedAt);
    _controller.add(exchange);
  }

  /// Interceptor'u kapatır.
  Future<void> close() => _controller.close();
}

/// Gövdeyi okunur metne çevirir: JSON girintili, bayt ve form özet.
String? describeBody(Object? data) => switch (data) {
  null => null,
  final String s when s.isEmpty => null,
  final String s => s,
  final List<int> bytes => '${bytes.length} bayt (ham veri)',
  final FormData f =>
    'multipart/form-data\n'
        '${[for (final e in f.fields) '  ${e.key} = ${e.value}', for (final e in f.files) '  ${e.key} = 📎 ${e.value.filename} (${e.value.length} bayt)'].join('\n')}',
  final Map<Object?, Object?> m => const JsonEncoder.withIndent(
    '  ',
  ).convert(m),
  final List<Object?> l => const JsonEncoder.withIndent('  ').convert(l),
  _ => '$data',
};
