import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

/// DERS 16 — Bir isteğin sonucu: başarı ya da hata, ikisi de değer.
///
/// `try/catch` yazmak yerine `switch (sonuç)` ile ele alınır.
sealed class ApiResult<T> {
  const ApiResult();
}

/// İstek başarılı.
final class ApiSuccess<T> extends ApiResult<T> {
  /// Sonuç oluşturur.
  const ApiSuccess(this.data);

  /// Gelen veri.
  final T data;
}

/// İstek başarısız.
final class ApiFailure<T> extends ApiResult<T> {
  /// Sonuç oluşturur.
  const ApiFailure(this.message, {this.statusCode});

  /// Türkçe açıklama.
  final String message;

  /// HTTP durum kodu (varsa).
  final int? statusCode;
}

/// `@UseCallAdapter(ResultCallAdapter)`: üretilen `Future<T>` çağrısını
/// `Future<ApiResult<T>>`'ye çevirir; hata fırlatmaz, değer döndürür.
class ResultCallAdapter<T>
    extends CallAdapter<Future<T>, Future<ApiResult<T>>> {
  @override
  Future<ApiResult<T>> adapt(Future<T> Function() call) async {
    try {
      return ApiSuccess(await call());
    } on DioException catch (e) {
      return ApiFailure(
        describeDioError(e),
        statusCode: e.response?.statusCode,
      );
    }
  }
}

/// Dio hatasının Türkçe açıklaması.
String describeDioError(DioException e) => switch (e.type) {
  DioExceptionType.connectionTimeout => 'Bağlantı zaman aşımına uğradı.',
  DioExceptionType.sendTimeout => 'Gönderme zaman aşımına uğradı.',
  DioExceptionType.receiveTimeout => 'Cevap zaman aşımına uğradı.',
  DioExceptionType.transformTimeout => 'Cevap çözülürken zaman aşımı oldu.',
  DioExceptionType.badResponse => 'Sunucu ${e.response?.statusCode} döndürdü.',
  DioExceptionType.cancel => 'İstek iptal edildi.',
  DioExceptionType.connectionError => 'İnternete bağlanılamadı.',
  DioExceptionType.badCertificate => 'Sertifika geçersiz.',
  DioExceptionType.unknown => 'Bilinmeyen hata: ${e.error}',
};
