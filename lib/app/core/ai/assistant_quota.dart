import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────
// DERS 20 — İstemci tarafı kullanım sınırı
//
// Her mesaj Firebase projesinin Gemini kotasından harcar. Asıl koruma
// sunucu tarafındadır (App Check zorunluluğu, AI Logic'in kullanıcı başı
// istek sınırı; bkz. README → Güvenlik). Bu sınıf yalnız uygulamanın kendi
// içinde kazara ya da hızlı tekrarlanan istekleri keser:
//
//   dakikada en çok [perMinute] mesaj   (bellekte, kayan pencere)
//   günde en çok [perDay] mesaj         (telefonda, gün değişince sıfırlanır)
// ─────────────────────────────────────────────────────────────────────────

/// Sınır sonucu.
enum QuotaVerdict {
  /// Gönderilebilir.
  ok,

  /// Dakikalık sınır.
  perMinute,

  /// Günlük sınır.
  perDay,
}

/// Asistan mesajları için kullanım sınırı.
class AssistantQuota {
  /// Oluşturur.
  AssistantQuota({
    required this._prefs,
    DateTime Function()? now,
    this.perMinute = 8,
    this.perDay = 100,
  }) : _now = now ?? DateTime.now;

  final Future<SharedPreferences> Function() _prefs;
  final DateTime Function() _now;

  /// Dakikada en çok.
  final int perMinute;

  /// Günde en çok.
  final int perDay;

  final List<DateTime> _recent = [];

  static const _dayKey = 'asistan_gun';
  static const _countKey = 'asistan_gun_sayi';

  String _day(DateTime d) => '${d.year}-${d.month}-${d.day}';

  /// Bir mesaj hakkı ister; varsa sayar.
  Future<QuotaVerdict> take() async {
    final now = _now();
    _recent.removeWhere((t) => now.difference(t) >= const Duration(minutes: 1));
    if (_recent.length >= perMinute) return QuotaVerdict.perMinute;
    final prefs = await _prefs();
    final today = _day(now);
    final count = prefs.getString(_dayKey) == today
        ? prefs.getInt(_countKey) ?? 0
        : 0;
    if (count >= perDay) return QuotaVerdict.perDay;
    _recent.add(now);
    await prefs.setString(_dayKey, today);
    await prefs.setInt(_countKey, count + 1);
    return QuotaVerdict.ok;
  }

  /// Bugün kalan mesaj.
  Future<int> remainingToday() async {
    final prefs = await _prefs();
    final count = prefs.getString(_dayKey) == _day(_now())
        ? prefs.getInt(_countKey) ?? 0
        : 0;
    return (perDay - count).clamp(0, perDay);
  }
}
