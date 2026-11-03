import 'package:equatable/equatable.dart';

/// DERS 13 — Canlı kur ekranının olayları.
sealed class LiveRatesEvent extends Equatable {
  const LiveRatesEvent();

  @override
  List<Object?> get props => [];
}

/// "Bağlan"a basıldı.
final class LiveConnectRequested extends LiveRatesEvent {
  /// Olayı oluşturur.
  const LiveConnectRequested();
}

/// "Bağlantıyı kes"e basıldı.
final class LiveDisconnectRequested extends LiveRatesEvent {
  /// Olayı oluşturur.
  const LiveDisconnectRequested();
}

/// Sunucuya mesaj gönderildi.
final class LiveMessageSent extends LiveRatesEvent {
  /// [text] için olay oluşturur.
  const LiveMessageSent(this.text);

  /// Gönderilen metin.
  final String text;

  @override
  List<Object?> get props => [text];
}
