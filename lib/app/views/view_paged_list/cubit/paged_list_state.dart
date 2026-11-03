import 'package:equatable/equatable.dart';
import 'package:flutter_ders/app/models/expense.dart';

/// Sayfalı listenin ne yaptığı.
enum PagedListStatus {
  /// İlk sayfa bekleniyor; listede henüz bir şey yok.
  initialLoading,

  /// Gösterilecek kayıtlar hazır.
  ready,

  /// Liste görünüyor, sonraki sayfa bekleniyor.
  loadingMore,

  /// Son istek başarısız oldu.
  failure,
}

/// DERS 7 — Sayfalı listenin durumu.
final class PagedListState extends Equatable {
  /// Bir durum oluşturur.
  const PagedListState({
    this.status = PagedListStatus.initialLoading,
    this.items = const [],
    this.page = 0,
    this.hasMore = true,
    this.total = 0,
  });

  /// Ne yapıldığı.
  final PagedListStatus status;

  /// Şimdiye kadar gelen tüm sayfaların kayıtları, sırayla.
  final List<Expense> items;

  /// Son yüklenen sayfa (henüz yoksa 0).
  final int page;

  /// Depoda gelmemiş kayıt var mı.
  final bool hasMore;

  /// Depodaki toplam kayıt sayısı (ilk sayfadan sonra bilinir).
  final int total;

  /// Değiştirilmiş bir kopya döndürür.
  PagedListState copyWith({
    PagedListStatus? status,
    List<Expense>? items,
    int? page,
    bool? hasMore,
    int? total,
  }) => PagedListState(
    status: status ?? this.status,
    items: items ?? this.items,
    page: page ?? this.page,
    hasMore: hasMore ?? this.hasMore,
    total: total ?? this.total,
  );

  @override
  List<Object?> get props => [status, items, page, hasMore, total];

  /// Hata ayıklama kaydında 500 kaydın hepsini yazmamak için kısa özet.
  @override
  String toString() =>
      'PagedListState(${status.name}, ${items.length}/$total kayıt, '
      'sayfa $page, devamı: $hasMore)';
}
