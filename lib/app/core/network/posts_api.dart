import 'package:dio/dio.dart';
import 'package:flutter_ders/app/core/network/api_result.dart';
import 'package:flutter_ders/app/models/post.dart';
import 'package:retrofit/retrofit.dart';

part 'posts_api.g.dart';

// ─────────────────────────────────────────────────────────────────────────
// DERS 16 — retrofit: REST servisini bir Dart ARAYÜZÜ olarak yaz, kodu
// üretilsin.
//
//   @GET('/posts/{id}')
//   Future<Post> getPost(@Path('id') int id);
//
// `dart run build_runner build` → posts_api.g.dart: Dio ile isteği atan,
// JSON'u Post.fromJson ile çeviren sınıf (_PostsApi). C#'taki Refit ve
// Android'deki Retrofit ile aynı fikir.
//
// Sunucu: jsonplaceholder.typicode.com — sahte REST. Yazma istekleri
// (POST/PUT/PATCH/DELETE) gerçekçi cevap döner ama hiçbir şeyi kaydetmez.
// ─────────────────────────────────────────────────────────────────────────

/// jsonplaceholder: yazılar ve yorumlar.
@RestApi(baseUrl: 'https://jsonplaceholder.typicode.com')
abstract class PostsApi {
  /// [dio] ile çalışan üretilmiş istemciyi verir.
  factory PostsApi(Dio dio, {String? baseUrl}) = _PostsApi;

  /// `@GET` + `@Path`: yoldaki `{id}` yerine parametre yazılır.
  @GET('/posts/{id}')
  Future<Post> getPost(@Path('id') int id);

  /// `@Query`: `?userId=1` sorgu parametresi.
  @GET('/posts')
  Future<List<Post>> getPostsByUser(@Query('userId') int userId);

  /// `@Queries`: bir Map'in tamamı sorgu parametresi olur.
  @GET('/comments')
  Future<List<Comment>> getComments(@Queries() Map<String, dynamic> filters);

  /// `HttpResponse<T>`: veri + ham cevap (durum kodu, başlıklar).
  @GET('/posts/{id}')
  Future<HttpResponse<Post>> getPostWithResponse(@Path('id') int id);

  /// `@POST` + `@Body`: nesne `toJson` ile JSON gövdeye çevrilir.
  @POST('/posts')
  Future<Post> createPost(@Body() PostDraft draft);

  /// `@PUT`: kaydın TAMAMI yenisiyle değiştirilir.
  @PUT('/posts/{id}')
  Future<Post> replacePost(@Path('id') int id, @Body() PostDraft draft);

  /// `@PATCH`: yalnızca gönderilen alanlar değişir (gövde bir Map).
  @PATCH('/posts/{id}')
  Future<Post> patchPost(
    @Path('id') int id,
    @Body() Map<String, dynamic> changes,
  );

  /// `@DELETE`: gövdesiz cevap; durum kodu `HttpResponse` ile okunur.
  @DELETE('/posts/{id}')
  Future<HttpResponse<void>> deletePost(@Path('id') int id);

  /// `@UseCallAdapter`: `Future<Post>` yerine `Future<ApiResult<Post>>`.
  /// Hata fırlatılmaz; sonuç `ApiSuccess` ya da `ApiFailure` olarak gelir.
  @UseCallAdapter(ResultCallAdapter)
  @GET('/posts/{id}')
  Future<ApiResult<Post>> safeGetPost(@Path('id') int id);
}
