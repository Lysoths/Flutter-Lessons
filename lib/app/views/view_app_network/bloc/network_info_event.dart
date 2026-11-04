import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:equatable/equatable.dart';

/// DERS 14 — Ağ bilgisi ekranının olayları.
sealed class NetworkInfoEvent extends Equatable {
  const NetworkInfoEvent();

  @override
  List<Object?> get props => [];
}

/// Ekran açıldı: bilgiler okunur, bağlantı değişiklikleri dinlenmeye başlar.
final class NetworkInfoStarted extends NetworkInfoEvent {
  /// Olayı oluşturur.
  const NetworkInfoStarted();
}

/// "Yenile"ye basıldı. Okuma sürerken gelenler yok sayılır (droppable).
final class NetworkInfoRefreshed extends NetworkInfoEvent {
  /// Olayı oluşturur.
  const NetworkInfoRefreshed();
}

/// Bağlantı türü değişti (Wi-Fi → mobil ...). Bloc kendi gönderir.
final class NetworkConnectivityChanged extends NetworkInfoEvent {
  /// Olayı oluşturur.
  const NetworkConnectivityChanged(this.connection);

  /// Yeni bağlantılar.
  final List<ConnectivityResult> connection;

  @override
  List<Object?> get props => [connection];
}

/// Wi-Fi adını görmek için konum izni istendi.
final class NetworkWifiAccessRequested extends NetworkInfoEvent {
  /// Olayı oluşturur.
  const NetworkWifiAccessRequested();
}
