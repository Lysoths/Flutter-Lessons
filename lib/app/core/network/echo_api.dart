// dio'nun da `Headers` sınıfı var; anotasyon retrofit'inki olsun.
import 'package:dio/dio.dart' hide Headers;
import 'package:retrofit/retrofit.dart';

part 'echo_api.g.dart';

// ─────────────────────────────────────────────────────────────────────────
// DERS 16 — httpbin.org: gelen isteği olduğu gibi geri yansıtır (başlıklar,
// sorgu, form, dosya). Retrofit'in isteği NASIL kurduğunu görmek için.
// Cevaplar ham `Map` olarak alınır.
// ─────────────────────────────────────────────────────────────────────────

/// httpbin: istek yansıtıcı.
@RestApi(baseUrl: 'https://httpbin.org')
abstract class EchoApi {
  /// [dio] ile çalışan üretilmiş istemciyi verir.
  factory EchoApi(Dio dio, {String? baseUrl}) = _EchoApi;

  /// `@HEAD`: GET gibi ama gövde gelmez; yalnızca başlıklar.
  @HEAD('/get')
  Future<HttpResponse<void>> head();

  /// `@OPTIONS`: sunucu bu adreste hangi metotlara izin veriyor? (`Allow`)
  @OPTIONS('/anything')
  Future<HttpResponse<void>> options();

  /// `@Headers` (sabit, her istekte) + `@Header` (çağrıda verilen).
  @Headers(<String, dynamic>{'X-Ders': '16', 'Accept': 'application/json'})
  @GET('/headers')
  Future<Map<String, Object?>> headers(@Header('X-Kullanici') String user);

  /// `@FormUrlEncoded` + `@Field`: `ad=Ayşe&yas=30` biçiminde form gövdesi.
  @FormUrlEncoded()
  @POST('/post')
  Future<Map<String, Object?>> form(
    @Field('ad') String name,
    @Field('yas') int age,
  );

  /// Varsayılan: değeri null olan alan gövdeden ÇIKARILIR (`{}` gider).
  @POST('/post')
  Future<Map<String, Object?>> absentField(@Field('not') String? note);

  /// `@PreventNullToAbsent`: null alan çıkarılmaz, `{"not": null}` gider
  /// (sunucuda bir alanı silmek için).
  @PreventNullToAbsent()
  @POST('/post')
  Future<Map<String, Object?>> nullField(@Field('not') String? note);

  /// `@MultiPart` + `@Part`: dosya yükleme gövdesi (multipart/form-data).
  @MultiPart()
  @POST('/post')
  Future<Map<String, Object?>> upload(
    @Part(name: 'aciklama') String description,
    @Part(name: 'dosya', fileName: 'ders16.txt') List<int> file,
    @SendProgress() ProgressCallback? onSendProgress,
  );

  /// `@Body` + `@BodyExtra`: nesneye ek alan katar, tek JSON gider.
  @POST('/post')
  Future<Map<String, Object?>> bodyExtra(
    @Body() Map<String, dynamic> body,
    @BodyExtra('gonderim') String sentAt,
  );

  /// `@NoBody`: POST ama gövdesiz.
  @NoBody()
  @POST('/post')
  Future<Map<String, Object?>> noBody();

  /// `@CancelRequest`: sunucu 5 sn bekletir; `CancelToken` ile iptal edilir.
  @GET('/delay/5')
  Future<Map<String, Object?>> slow(@CancelRequest() CancelToken cancelToken);

  /// `@DioResponseType(bytes)` + `@ReceiveProgress`: ham bayt, indirme ilerlemesi.
  @DioResponseType(ResponseType.bytes)
  @GET('/bytes/{size}')
  Future<List<int>> download(
    @Path('size') int size,
    @ReceiveProgress() ProgressCallback? onReceiveProgress,
  );

  /// `@Extra` (sabit) + `@Extras` (çağrıda): isteğe ağa GİTMEYEN not eklenir;
  /// yalnızca interceptor'lar görür.
  @Extra(<String, Object>{'ders': 16})
  @GET('/get')
  Future<Map<String, Object?>> extras(@Extras() Map<String, dynamic> extras);

  /// `@DioOptions`: bu tek isteğe özel Dio ayarı (ör. 1 sn zaman aşımı).
  @GET('/delay/{seconds}')
  Future<Map<String, Object?>> withOptions(
    @Path('seconds') int seconds,
    @DioOptions() Options options,
  );

  /// `@CacheControl`: `Cache-Control` başlığını anotasyondan kurar.
  @CacheControl(maxAge: 60, noTransform: true)
  @GET('/headers')
  Future<Map<String, Object?>> cacheControl();

  /// Hata: `/status/404` gibi istenen durum kodunu döndürür.
  @GET('/status/{code}')
  Future<HttpResponse<void>> status(@Path('code') int code);
}
