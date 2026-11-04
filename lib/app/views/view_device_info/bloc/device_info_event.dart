import 'package:equatable/equatable.dart';

/// DERS 14 — Cihaz bilgisi ekranının olayları.
sealed class DeviceInfoEvent extends Equatable {
  const DeviceInfoEvent();

  @override
  List<Object?> get props => [];
}

/// Ekran açıldı.
final class DeviceInfoRequested extends DeviceInfoEvent {
  /// Olayı oluşturur.
  const DeviceInfoRequested();
}

/// "Yenile"ye basıldı: RAM ve disk gibi değişen değerler yeniden okunur.
final class DeviceInfoRefreshed extends DeviceInfoEvent {
  /// Olayı oluşturur.
  const DeviceInfoRefreshed();
}
