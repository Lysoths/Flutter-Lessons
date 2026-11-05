import 'package:flutter_ders/app/core/analytics/app_events.dart';
import 'package:flutter_ders/app/core/base/base_change_notifier_view_model.dart';
import 'package:flutter_ders/app/core/repository/news_repository.dart';
import 'package:flutter_ders/app/models/currency/news_article.dart';

/// DERS 15 — 3. bölüm: finans haberleri.
///
/// Süzme (para birimine göre) ve "okundu" işareti ViewModel'de tutulur;
/// View yalnızca [visible] listesini çizer.
class NewsViewModel extends BaseChangeNotifierViewModel {
  /// [repository] üzerinden çalışan ViewModel oluşturur.
  NewsViewModel({required this._repository});

  final NewsRepository _repository;

  List<NewsArticle> _articles = const [];
  List<String> _failedSources = const [];
  String? _filter;
  final _read = <String>{};

  /// Tüm haberler.
  List<NewsArticle> get articles => _articles;

  /// Süzgece uyan haberler.
  List<NewsArticle> get visible => switch (_filter) {
    null => _articles,
    final code => [
      for (final a in _articles)
        if (a.currencies.contains(code)) a,
    ],
  };

  /// Seçili süzgeç (null: hepsi).
  String? get filter => _filter;

  /// Haberlerde geçen para birimleri ve haber sayıları, çoktan aza.
  List<({String code, int count})> get mentioned {
    final counts = <String, int>{};
    for (final a in _articles) {
      for (final c in a.currencies) {
        counts[c] = (counts[c] ?? 0) + 1;
      }
    }
    return [for (final e in counts.entries) (code: e.key, count: e.value)]
      ..sort((a, b) => b.count.compareTo(a.count));
  }

  /// Okunamayan kaynaklar.
  List<String> get failedSources => _failedSources;

  /// Haber açıldı mı?
  bool isRead(NewsArticle article) => _read.contains(article.id);

  /// Haberleri getirir.
  Future<void> load() => runTask(() async {
    final result = await _repository.latest();
    _articles = result.articles;
    _failedSources = result.failedSources;
  }, describe: (e) => e is NewsFailure ? e.message : 'Haberler alınamadı.');

  /// Süzgeci değiştirir; aynı koda tekrar basmak süzgeci kaldırır.
  void toggleFilter(String? code) {
    _filter = code == _filter ? null : code;
    track(AppEvent.newsFiltered, _filter ?? 'tumu');
    notifyListeners();
  }

  /// Haber açıldı (modal).
  void markRead(NewsArticle article) {
    track(AppEvent.newsOpened);
    if (_read.add(article.id)) notifyListeners();
  }
}
