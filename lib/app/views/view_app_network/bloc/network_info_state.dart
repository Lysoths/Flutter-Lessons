import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_ders/app/core/device/location_source.dart';
import 'package:flutter_ders/app/core/repository/network_info_repository.dart';
import 'package:flutter_ders/app/models/cloudflare_trace.dart';
import 'package:flutter_ders/app/models/info_section.dart';

/// Bir parçanın yüklenme durumu.
enum PartStatus {
  /// Okunuyor.
  loading,

  /// Hazır.
  ready,

  /// Hata.
  failure,
}

/// DERS 14 — Ağ ekranının durumu.
///
/// İki parça ayrı ayrı yüklenir: cihaz içi bilgi hızlı gelir (≈ 20 ms),
/// trace internete gider (≈ 50–300 ms). Biri beklerken diğeri gösterilir.
class NetworkInfoState extends Equatable {
  /// Durumu oluşturur.
  const NetworkInfoState({
    this.localStatus = PartStatus.loading,
    this.connection = const [],
    this.localSections = const [],
    this.wifiAccess,
    this.traceStatus = PartStatus.loading,
    this.trace,
    this.traceLatency,
    this.traceError,
    this.traceAt,
    this.traceCount = 0,
    this.connectionChanges = 0,
  });

  /// Cihaz içi bilginin durumu.
  final PartStatus localStatus;

  /// Etkin bağlantılar.
  final List<ConnectivityResult> connection;

  /// Bağlantı, Wi-Fi ve arayüz bölümleri.
  final List<InfoSection> localSections;

  /// Wi-Fi adı için gereken konum izni (sorulmadıysa null).
  final LocationAccess? wifiAccess;

  /// Trace isteğinin durumu.
  final PartStatus traceStatus;

  /// Son başarılı trace.
  final CloudflareTrace? trace;

  /// Son isteğin gidiş-dönüş süresi.
  final Duration? traceLatency;

  /// Son hatanın açıklaması.
  final String? traceError;

  /// Son cevabın geldiği an.
  final DateTime? traceAt;

  /// Kaç trace isteği gönderildi.
  final int traceCount;

  /// Ekran açıkken bağlantı kaç kez değişti.
  final int connectionChanges;

  /// Wi-Fi adı okunamadı mı (izin yoksa Android ad vermez)?
  bool get wifiNameMissing => localSections
      .where((s) => s.id == 'wifi')
      .expand((s) => s.entries)
      .any((e) => e.label == kSsidLabel && e.value == '—');

  /// Değişen alanlarla yeni durum.
  NetworkInfoState copyWith({
    PartStatus? localStatus,
    List<ConnectivityResult>? connection,
    List<InfoSection>? localSections,
    LocationAccess? wifiAccess,
    PartStatus? traceStatus,
    CloudflareTrace? trace,
    Duration? traceLatency,
    String? Function()? traceError,
    DateTime? traceAt,
    int? traceCount,
    int? connectionChanges,
  }) => NetworkInfoState(
    localStatus: localStatus ?? this.localStatus,
    connection: connection ?? this.connection,
    localSections: localSections ?? this.localSections,
    wifiAccess: wifiAccess ?? this.wifiAccess,
    traceStatus: traceStatus ?? this.traceStatus,
    trace: trace ?? this.trace,
    traceLatency: traceLatency ?? this.traceLatency,
    traceError: traceError == null ? this.traceError : traceError(),
    traceAt: traceAt ?? this.traceAt,
    traceCount: traceCount ?? this.traceCount,
    connectionChanges: connectionChanges ?? this.connectionChanges,
  );

  @override
  List<Object?> get props => [
    localStatus,
    connection,
    localSections,
    wifiAccess,
    traceStatus,
    trace,
    traceLatency,
    traceError,
    traceAt,
    traceCount,
    connectionChanges,
  ];

  // IP, Wi-Fi adı gibi değerler konsola (AppBlocObserver) yazılmasın.
  @override
  String toString() =>
      'NetworkInfoState(yerel: ${localStatus.name}, '
      'bağlantı: ${connection.map((c) => c.name).join('+')}, '
      'trace: ${traceStatus.name} #$traceCount'
      '${traceLatency == null ? '' : ' ${traceLatency!.inMilliseconds} ms'})';
}
