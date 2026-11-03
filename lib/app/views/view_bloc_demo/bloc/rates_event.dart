import 'package:equatable/equatable.dart';

/// DERS 13 — Kur ekranının gönderebileceği olaylar.
///
/// `sealed`: olay türlerinin listesi burada kapalıdır; derleyici başka
/// türün olmadığını bilir.
sealed class RatesEvent extends Equatable {
  const RatesEvent();

  @override
  List<Object?> get props => [];
}

/// Ekran açıldı, kurlar istendi.
final class RatesRequested extends RatesEvent {
  /// Olayı oluşturur.
  const RatesRequested();
}

/// "Yenile"ye basıldı. İstek sürerken gelen yenileri yok sayılır.
final class RatesRefreshed extends RatesEvent {
  /// Olayı oluşturur.
  const RatesRefreshed();
}
