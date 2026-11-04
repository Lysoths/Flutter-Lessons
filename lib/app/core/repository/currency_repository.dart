import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_ders/app/models/currency/currency_info.dart';
import 'package:flutter_ders/app/models/currency/rate_history.dart';

/// DERS 15 — Kur servisi başarısız olursa fırlatılır.
class CurrencyFailure implements Exception {
  /// Hata oluşturur.
  const CurrencyFailure(this.message);

  /// Kullanıcıya gösterilecek açıklama.
  final String message;

  @override
  String toString() => message;
}

/// Kurların nereden geldiğini ViewModel'den gizler (MVVM'deki Model).
abstract interface class CurrencyRepository {
  /// En son yayınlanan günün kurları.
  Future<DailyRates> latest();

  /// [date] gününün kurları.
  Future<DailyRates> onDate(DateTime date);
}

/// currency-api (github.com/fawazahmed0/exchange-api): ücretsiz, anahtar
/// istemez, her gün için ayrı bir JSON dosyası. Aynı dosya iki yerde durur;
/// biri açılmazsa diğeri denenir:
///
///   1. jsDelivr:   https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@2026.11.3/v1/currencies/try.min.json
///   2. pages.dev:  https://2026-11-03.currency-api.pages.dev/v1/currencies/try.min.json
///
///   {"date":"2026-11-03","try":{"usd":0.0200,"eur":0.0178, ...}}
///
/// Bazı mobil operatörler pages.dev adreslerini engelliyor (bağlantı TLS
/// aşamasında kesiliyor); bu yüzden jsDelivr önce gelir.
///
/// Cevap "1 ₺ = 0,02 USD" der; bize "1 USD = kaç ₺" lazım, tersi alınır.
/// Aynı gün iki kez istenmez (önbellek): aralık değiştirince eski günler
/// yeniden indirilmez.
class CurrencyApiRepository implements CurrencyRepository {
  /// [dio] üzerinden çalışan depo oluşturur.
  CurrencyApiRepository(this._dio);

  /// [date] günü (null: en son gün) için denenecek adresler, sırayla.
  static List<String> urlsFor(DateTime? date) {
    const file = 'v1/currencies/try.min.json';
    // jsDelivr sürüm adı başında sıfır olmadan yazılır: 2026.8.6.
    final npm = date == null
        ? 'latest'
        : '${date.year}.${date.month}.${date.day}';
    final pages = date == null ? 'latest' : _day(date);
    return [
      'https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@$npm/$file',
      'https://$pages.currency-api.pages.dev/$file',
    ];
  }

  final Dio _dio;
  final _cache = <String, Future<DailyRates>>{};

  // "latest" her yenilemede değişebilir; önbelleğe alınmaz.
  @override
  Future<DailyRates> latest() => _fetch(null);

  @override
  Future<DailyRates> onDate(DateTime date) {
    final day = _day(date);
    return _cache.putIfAbsent(day, () async {
      try {
        return await _fetch(date);
      } on Object {
        // Hata önbellekte kalmasın; bir sonraki istek yeniden denesin.
        unawaited(_cache.remove(day));
        rethrow;
      }
    });
  }

  Future<DailyRates> _fetch(DateTime? date) async {
    final urls = urlsFor(date);
    for (final (i, url) in urls.indexed) {
      try {
        return await _fetchFrom(url);
      } on CurrencyFailure {
        // Son adres de olmadıysa hatayı ver; yoksa sıradakini dene.
        if (i == urls.length - 1) rethrow;
      }
    }
    throw const CurrencyFailure('Kurlar alınamadı.');
  }

  Future<DailyRates> _fetchFrom(String url) async {
    try {
      final response = await _dio.get<String>(
        url,
        options: Options(responseType: ResponseType.plain),
      );
      final json = jsonDecode(response.data!) as Map<String, Object?>;
      final rates = json['try']! as Map<String, Object?>;
      return (
        date: DateTime.parse(json['date']! as String),
        tryPerUnit: {
          for (final c in kTrackedCurrencies)
            if (rates[c.code.toLowerCase()] case final num v when v != 0)
              c.code: 1 / v.toDouble(),
        },
      );
    } on DioException catch (e) {
      throw CurrencyFailure(switch (e.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.receiveTimeout ||
        DioExceptionType.sendTimeout => 'Kur servisi zamanında cevap vermedi.',
        DioExceptionType.connectionError => 'İnternete bağlanılamadı.',
        DioExceptionType.badResponse =>
          'Kur servisi hata döndürdü (${e.response?.statusCode}).',
        _ => 'Kurlar alınamadı.',
      });
    } on FormatException {
      throw const CurrencyFailure('Kur servisinin cevabı okunamadı.');
    }
  }
}

String _day(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';
