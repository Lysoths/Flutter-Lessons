import 'package:equatable/equatable.dart';
import 'package:flutter_ders/app/core/network/recording_interceptor.dart';
import 'package:flutter_ders/app/views/view_retrofit/cubit/retrofit_demos.dart';

/// Bir denemenin durumu.
enum RunStatus {
  /// Çalışıyor.
  running,

  /// Başarılı.
  success,

  /// Hata.
  failure,

  /// Kullanıcı iptal etti.
  cancelled,
}

/// DERS 16 — Bir denemenin son çalıştırılışı.
class DemoRun extends Equatable {
  /// Çalıştırma oluşturur.
  const DemoRun({
    required this.status,
    this.progress,
    this.resultType,
    this.resultText,
    this.error,
    this.took,
    this.exchanges = const [],
  });

  /// Durum.
  final RunStatus status;

  /// Yükleme / indirme ilerlemesi (0–1).
  final double? progress;

  /// Dönen Dart nesnesinin tipi (ör. `List<Post> · 10 öğe`).
  final String? resultType;

  /// Dönen nesnenin okunur hâli.
  final String? resultText;

  /// Hata açıklaması.
  final String? error;

  /// Toplam süre.
  final Duration? took;

  /// Bu denemenin ağa attığı istekler.
  final List<NetworkExchange> exchanges;

  /// Değişen alanlarla yeni çalıştırma.
  DemoRun copyWith({
    RunStatus? status,
    double? progress,
    List<NetworkExchange>? exchanges,
  }) => DemoRun(
    status: status ?? this.status,
    progress: progress ?? this.progress,
    resultType: resultType,
    resultText: resultText,
    error: error,
    took: took,
    exchanges: exchanges ?? this.exchanges,
  );

  @override
  List<Object?> get props => [
    status,
    progress,
    resultType,
    resultText,
    error,
    took,
    exchanges.length,
  ];
}

/// DERS 16 — Retrofit ekranının durumu.
class RetrofitLabState extends Equatable {
  /// Durum oluşturur.
  const RetrofitLabState({
    this.runs = const {},
    this.log = const [],
    this.group,
  });

  /// Deneme kimliği → son çalıştırma.
  final Map<String, DemoRun> runs;

  /// Ağdan geçen tüm istekler, yeniden eskiye (en çok 50).
  final List<NetworkExchange> log;

  /// Seçili grup (null: hepsi).
  final DemoGroup? group;

  /// Gösterilecek denemeler.
  List<RetrofitDemo> get visible => [
    for (final d in kRetrofitDemos)
      if (group == null || d.group == group) d,
  ];

  /// Değişen alanlarla yeni durum.
  RetrofitLabState copyWith({
    Map<String, DemoRun>? runs,
    List<NetworkExchange>? log,
    DemoGroup? Function()? group,
  }) => RetrofitLabState(
    runs: runs ?? this.runs,
    log: log ?? this.log,
    group: group == null ? this.group : group(),
  );

  @override
  List<Object?> get props => [runs, log.length, group];

  @override
  String toString() =>
      'RetrofitLabState(${runs.length} deneme, ${log.length} istek, '
      'grup: ${group?.name ?? 'hepsi'})';
}
