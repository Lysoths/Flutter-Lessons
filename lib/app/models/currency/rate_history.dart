import 'package:equatable/equatable.dart';

/// DERS 15 — Bir günün kurları: kod → 1 birimin ₺ karşılığı.
typedef DailyRates = ({DateTime date, Map<String, double> tryPerUnit});

/// Grafikteki tek nokta.
typedef RatePoint = ({DateTime date, double value});

/// Geçmiş gösterim aralığı.
enum HistoryPeriod {
  /// Son 7 gün, her gün.
  week('Haftalık', days: 7, step: 1),

  /// Son 30 gün, iki günde bir.
  month('Aylık', days: 30, step: 2),

  /// Son 90 gün, haftada bir.
  quarter('3 aylık', days: 91, step: 7);

  const HistoryPeriod(this.label, {required this.days, required this.step});

  /// Görünen ad.
  final String label;

  /// Kaç gün geriye gidilir.
  final int days;

  /// Kaç günde bir nokta alınır (istek sayısını sınırlar).
  final int step;

  /// [end] gününden geriye istenecek günler, eskiden yeniye.
  List<DateTime> datesUntil(DateTime end) {
    final day = DateTime(end.year, end.month, end.day);
    return [
      for (var back = days; back >= 0; back -= step)
        day.subtract(Duration(days: back)),
    ];
  }
}

/// Bir para biriminin bir aralıktaki geçmişi.
class RateHistory extends Equatable {
  /// Geçmiş oluşturur.
  const RateHistory({
    required this.code,
    required this.period,
    required this.points,
  });

  /// Para birimi.
  final String code;

  /// Aralık.
  final HistoryPeriod period;

  /// Noktalar, eskiden yeniye.
  final List<RatePoint> points;

  /// En düşük değer.
  double get min => points.map((p) => p.value).reduce((a, b) => a < b ? a : b);

  /// En yüksek değer.
  double get max => points.map((p) => p.value).reduce((a, b) => a > b ? a : b);

  /// İlk noktadan sona yüzde değişim.
  double get changePercent => points.length < 2
      ? 0
      : (points.last.value - points.first.value) / points.first.value * 100;

  @override
  List<Object?> get props => [code, period, points];
}
