import 'package:equatable/equatable.dart';
import 'package:flutter_ders/app/core/device/device_info_source.dart';

/// DERS 14 — Cihaz bilgisi ekranının durumu.
sealed class DeviceInfoState extends Equatable {
  const DeviceInfoState();

  @override
  List<Object?> get props => [];
}

/// Henüz okunmadı.
final class DeviceInfoInitial extends DeviceInfoState {
  /// Durumu oluşturur.
  const DeviceInfoInitial();
}

/// Okunuyor; varsa önceki sonuç soluk gösterilir.
final class DeviceInfoLoading extends DeviceInfoState {
  /// Durumu oluşturur.
  const DeviceInfoLoading({this.previous});

  /// Önceki sonuç.
  final DeviceInfoReport? previous;

  @override
  List<Object?> get props => [previous];

  @override
  String toString() => 'DeviceInfoLoading()';
}

/// Okundu.
final class DeviceInfoLoaded extends DeviceInfoState {
  /// Durumu oluşturur.
  const DeviceInfoLoaded({
    required this.report,
    required this.readAt,
    required this.took,
  });

  /// Okunan bilgi.
  final DeviceInfoReport report;

  /// Okunduğu an.
  final DateTime readAt;

  /// Okumanın sürdüğü süre.
  final Duration took;

  /// Toplam alan sayısı (bölümler + sistem özellikleri).
  int get fieldCount =>
      report.sections.fold(0, (sum, s) => sum + s.entries.length) +
      report.systemFeatures.length;

  @override
  List<Object?> get props => [report, readAt, took];

  // Konsola yüzlerce satır yerine özet yazılır.
  @override
  String toString() =>
      'DeviceInfoLoaded($fieldCount alan, ${took.inMilliseconds} ms)';
}

/// Okunamadı.
final class DeviceInfoError extends DeviceInfoState {
  /// Durumu oluşturur.
  const DeviceInfoError(this.message);

  /// Açıklama.
  final String message;

  @override
  List<Object?> get props => [message];
}
