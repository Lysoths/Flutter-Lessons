import 'package:dio/dio.dart';
import 'package:flutter_ders/app/models/exchange_rates.dart';

/// DERS 13 — Kur servisi isteği başarısız olursa fırlatılır; mesajı
/// ekranda gösterilecek Türkçe açıklamadır.
class RatesFailure implements Exception {
  /// Hata oluşturur.
  const RatesFailure(this.message);

  /// Kullanıcıya gösterilecek açıklama.
  final String message;

  @override
  String toString() => message;
}

/// Döviz kurlarının nereden geldiğini Bloc'tan gizler.
abstract interface class RatesRepository {
  /// Güncel kurları getirir; olmazsa [RatesFailure] fırlatır.
  Future<ExchangeRates> latest();
}

/// Frankfurter (frankfurter.dev): Avrupa Merkez Bankası'nın günlük
/// kurları. Ücretsiz, anahtar istemez; isteğe kişisel veri eklenmez.
///
/// İstek `dio` ile yapılır (masterfabric_core da dio kullanır):
///   GET https://api.frankfurter.dev/v1/latest?base=TRY&symbols=USD,EUR,...
class FrankfurterRatesRepository implements RatesRepository {
  /// [dio] üzerinden çalışan depo oluşturur.
  FrankfurterRatesRepository(this._dio);

  /// Servisin kök adresi.
  static const baseUrl = 'https://api.frankfurter.dev/v1/';

  final Dio _dio;

  @override
  Future<ExchangeRates> latest() async {
    try {
      final response = await _dio.get<Map<String, Object?>>(
        'latest',
        queryParameters: {'base': 'TRY', 'symbols': kCurrencies.keys.join(',')},
      );
      return ExchangeRates.fromFrankfurter(response.data!);
    } on DioException catch (e) {
      throw RatesFailure(switch (e.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.receiveTimeout ||
        DioExceptionType.sendTimeout => 'Sunucu zamanında cevap vermedi.',
        DioExceptionType.connectionError => 'İnternete bağlanılamadı.',
        DioExceptionType.badResponse =>
          'Sunucu hata döndürdü (${e.response?.statusCode}).',
        _ => 'Kurlar alınamadı.',
      });
    }
  }
}

/// Uygulamanın tek `Dio` örneği: kök adres ve zaman aşımları burada.
Dio createDio() => Dio(
  BaseOptions(
    baseUrl: FrankfurterRatesRepository.baseUrl,
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 8),
  ),
);
