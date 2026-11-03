import 'package:equatable/equatable.dart';
import 'package:flutter_ders/app/helper/mock_socket.dart';

/// Canlı bağlantının hâli.
enum LiveStatus {
  /// Hiç bağlanılmadı.
  idle('Bağlı değil'),

  /// Bağlanıyor / ilk veri bekleniyor.
  connecting('Bağlanıyor'),

  /// Veri akıyor.
  live('Canlı'),

  /// Bağlantı kapandı.
  closed('Kapandı'),

  /// Bağlantı hata verdi.
  failure('Hata');

  const LiveStatus(this.label);

  /// Görünen ad.
  final String label;
}

/// DERS 13 — Canlı kur ekranının durumu (tek sınıf + status alanı).
final class LiveRatesState extends Equatable {
  /// Durumu oluşturur.
  const LiveRatesState({
    this.status = LiveStatus.idle,
    this.last,
    this.previous,
    this.ticks = 0,
    this.echoes = const [],
    this.error,
  });

  /// Bağlantının hâli.
  final LiveStatus status;

  /// Son gelen kur.
  final RateTick? last;

  /// Ondan önceki kur (yükseldi mi düştü mü?).
  final RateTick? previous;

  /// Gelen kur mesajı sayısı.
  final int ticks;

  /// Sunucunun geri yolladığı mesajlar, en yenisi başta.
  final List<EchoReply> echoes;

  /// Hata açıklaması.
  final String? error;

  /// Değiştirilmiş bir kopya döndürür.
  LiveRatesState copyWith({
    LiveStatus? status,
    RateTick? last,
    RateTick? previous,
    int? ticks,
    List<EchoReply>? echoes,
    String? error,
  }) => LiveRatesState(
    status: status ?? this.status,
    last: last ?? this.last,
    previous: previous ?? this.previous,
    ticks: ticks ?? this.ticks,
    echoes: echoes ?? this.echoes,
    error: error,
  );

  @override
  List<Object?> get props => [status, last, previous, ticks, echoes, error];

  @override
  String toString() => 'LiveRatesState(${status.name}, $ticks kur)';
}
