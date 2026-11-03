import 'package:equatable/equatable.dart';
import 'package:flutter_ders/app/models/storage_note.dart';

/// Depolama ekranının ne yaptığı.
enum StorageDemoStatus {
  /// Depo açılıyor.
  loading,

  /// Hazır.
  ready,

  /// Toplu yazma / okuma ölçülüyor.
  benchmarking,

  /// Bir işlem başarısız oldu.
  failure,
}

/// Toplu yazma / okuma ölçümünün sonucu.
typedef StorageBenchmark = ({int count, Duration write, Duration read});

/// DERS 10 — Depolama ekranının durumu.
final class StorageDemoState extends Equatable {
  /// Bir durum oluşturur.
  const StorageDemoState({
    this.status = StorageDemoStatus.loading,
    this.notes = const [],
    this.raw = '',
    this.benchmark,
    this.error,
  });

  /// Ne yapıldığı.
  final StorageDemoStatus status;

  /// Kayıtlar, en yenisi başta.
  final List<StorageNote> notes;

  /// Verinin diskte / bellekte nasıl durduğu.
  final String raw;

  /// Son ölçüm (yoksa `null`).
  final StorageBenchmark? benchmark;

  /// Hata mesajı.
  final String? error;

  /// Değiştirilmiş bir kopya döndürür.
  StorageDemoState copyWith({
    StorageDemoStatus? status,
    List<StorageNote>? notes,
    String? raw,
    StorageBenchmark? benchmark,
    String? error,
  }) => StorageDemoState(
    status: status ?? this.status,
    notes: notes ?? this.notes,
    raw: raw ?? this.raw,
    benchmark: benchmark ?? this.benchmark,
    error: error,
  );

  @override
  List<Object?> get props => [status, notes, raw, benchmark, error];

  @override
  String toString() =>
      'StorageDemoState(${status.name}, ${notes.length} kayıt)';
}
