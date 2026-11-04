import 'package:dio/dio.dart';
import 'package:flutter_ders/app/models/currency/news_article.dart';
import 'package:xml/xml.dart';

/// DERS 15 — Haber kaynağı (RSS beslemesi).
typedef NewsFeed = ({String name, String url});

/// Okunan haberler ve okunamayan kaynaklar.
typedef NewsResult = ({List<NewsArticle> articles, List<String> failedSources});

/// Hiçbir kaynak okunamadı.
class NewsFailure implements Exception {
  /// Hata oluşturur.
  const NewsFailure(this.message);

  /// Kullanıcıya gösterilecek açıklama.
  final String message;

  @override
  String toString() => message;
}

/// Haberlerin nereden geldiğini ViewModel'den gizler.
abstract interface class NewsRepository {
  /// Kaynaklardaki son haberler, yeniden eskiye.
  Future<NewsResult> latest();
}

/// Ekonomi haberleri: Anadolu Ajansı ve TRT Haber RSS beslemeleri.
const kNewsFeeds = <NewsFeed>[
  (
    name: 'Anadolu Ajansı',
    url: 'https://www.aa.com.tr/tr/rss/default?cat=ekonomi',
  ),
  (name: 'TRT Haber', url: 'https://www.trthaber.com/ekonomi_articles.rss'),
];

/// Yalnızca bu alan adlarındaki haberler tarayıcıda açılır.
const kNewsHosts = {'www.aa.com.tr', 'aa.com.tr', 'www.trthaber.com'};

/// RSS 2.0 beslemelerini `xml` paketiyle okur.
///
/// ```xml
/// <item>
///   <title>…</title> <link>…</link> <description>…</description>
///   <pubDate>Wed, 04 Nov 2026 13:24:07 +0300</pubDate>
///   <image>…</image> | <media:content url="…"/> | <enclosure url="…"/>
/// </item>
/// ```
///
/// Kaynaklar aynı anda istenir; biri çökerse diğerinin haberleri gösterilir.
class RssNewsRepository implements NewsRepository {
  /// [dio] üzerinden çalışan depo oluşturur.
  RssNewsRepository(this._dio, {List<NewsFeed>? feeds})
    : _feeds = feeds ?? kNewsFeeds;

  final Dio _dio;
  final List<NewsFeed> _feeds;

  @override
  Future<NewsResult> latest() async {
    final results = await Future.wait(
      _feeds.map((f) async {
        try {
          return (feed: f, items: await _read(f));
        } on Object {
          return (feed: f, items: null);
        }
      }),
    );
    final failed = [
      for (final r in results)
        if (r.items == null) r.feed.name,
    ];
    if (failed.length == _feeds.length) {
      throw const NewsFailure('Haber kaynaklarına ulaşılamadı.');
    }
    // Aynı haber iki ajansta da çıkabilir: başlığa göre bir kez.
    final seen = <String>{};
    final articles = [for (final r in results) ...?r.items]
      ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    return (
      articles: [
        for (final a in articles)
          if (seen.add(trLower(a.title))) a,
      ],
      failedSources: failed,
    );
  }

  Future<List<NewsArticle>> _read(NewsFeed feed) async {
    final response = await _dio.get<String>(
      feed.url,
      options: Options(responseType: ResponseType.plain),
    );
    return parseRss(response.data ?? '', source: feed.name);
  }
}

/// RSS metnini haberlere çevirir; eksik alanlı öğeler atlanır.
List<NewsArticle> parseRss(String body, {required String source}) {
  // AA'nın dosyası görünmez bir BOM karakteriyle başlıyor.
  final doc = XmlDocument.parse(body.replaceFirst('\uFEFF', '').trim());
  return [
    for (final item in doc.findAllElements('item')) ?_article(item, source),
  ];
}

NewsArticle? _article(XmlElement item, String source) {
  String? text(String name) => switch (item.getElement(name)?.innerText) {
    final s? when s.trim().isNotEmpty => s.trim(),
    _ => null,
  };
  final title = text('title');
  final link = Uri.tryParse(text('link') ?? '');
  final date = parseRfc822(text('pubDate') ?? '');
  if (title == null || link == null || date == null) return null;
  final rawSummary = text('description') ?? '';
  final summary = stripHtml(rawSummary);
  final image =
      text('image') ??
      item.getElement('media:content')?.getAttribute('url') ??
      item.getElement('enclosure')?.getAttribute('url') ??
      RegExp('<img[^>]+src="([^"]+)"').firstMatch(rawSummary)?.group(1);
  return NewsArticle(
    id: text('guid') ?? link.toString(),
    title: title,
    summary: summary,
    link: link,
    source: source,
    publishedAt: date,
    imageUrl: image,
    currencies: detectCurrencies('$title $summary'),
  );
}

/// HTML etiketlerini ve sık kullanılan karakter kodlarını temizler.
String stripHtml(String html) => html
    .replaceAll(RegExp('<[^>]*>'), ' ')
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&amp;', '&')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

const _months = {
  'Jan': 1,
  'Feb': 2,
  'Mar': 3,
  'Apr': 4,
  'May': 5,
  'Jun': 6,
  'Jul': 7,
  'Aug': 8,
  'Sep': 9,
  'Oct': 10,
  'Nov': 11,
  'Dec': 12,
};

/// RSS tarihini çözer: `Wed, 04 Nov 2026 13:24:07 +0300` → yerel saat.
DateTime? parseRfc822(String s) {
  final m = RegExp(
    r'(\d{1,2}) (\w{3}) (\d{4}) (\d{2}):(\d{2})(?::(\d{2}))? ?([+-]\d{4}|GMT|UTC|Z)?',
  ).firstMatch(s);
  final month = _months[m?.group(2)];
  if (m == null || month == null) return null;
  final utc = DateTime.utc(
    int.parse(m.group(3)!),
    month,
    int.parse(m.group(1)!),
    int.parse(m.group(4)!),
    int.parse(m.group(5)!),
    int.parse(m.group(6) ?? '0'),
  );
  final zone = m.group(7);
  if (zone == null || !zone.startsWith(RegExp('[+-]'))) return utc.toLocal();
  final sign = zone.startsWith('-') ? -1 : 1;
  final offset = Duration(
    hours: int.parse(zone.substring(1, 3)),
    minutes: int.parse(zone.substring(3, 5)),
  );
  // 13:24 +0300 → UTC 10:24.
  return utc.subtract(offset * sign).toLocal();
}
