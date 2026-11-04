import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_ders/app/core/locale/app_language.dart';

/// User-facing copy for the active locale.
///
/// Turkish source strings are the keys. Turkish itself returns the source,
/// so the lesson tests keep matching the same words.
final class AppStrings {
  /// Copy for [language], using [phrases] when the language is not Turkish.
  AppStrings(this.language, this.phrases);

  /// Language these phrases belong to.
  final AppLanguage language;

  /// Turkish source → translation. Empty for Turkish.
  final Map<String, String> phrases;

  /// Strings from the nearest [AppStringsDelegate].
  static AppStrings of(BuildContext context) {
    return Localizations.of<AppStrings>(context, AppStrings) ??
        AppStrings(AppLanguage.tr, const {});
  }

  /// [source] in [language]. Unknown copy stays as written.
  String translate(String source) {
    if (language == AppLanguage.tr || source.isEmpty) return source;
    final exact = phrases[source];
    if (exact != null) return exact;
    // Headers pass an already uppercased label, such as GÖRSELLER.
    if (source.length > 1 && source == source.toUpperCase()) {
      for (final entry in phrases.entries) {
        if (entry.key.toUpperCase() == source) {
          return entry.value.toUpperCase();
        }
      }
    }
    return _pattern(source) ?? source;
  }

  String? _pattern(String source) {
    final deleted = RegExp(r'^(.+) harcaması silindi$').firstMatch(source);
    if (deleted != null) {
      final label = translate(deleted.group(1)!);
      return switch (language) {
        AppLanguage.en => '$label expense deleted',
        AppLanguage.fr => 'Dépense « $label » supprimée',
        AppLanguage.de => '$label-Ausgabe gelöscht',
        AppLanguage.cn => '已删除$label支出',
        AppLanguage.jp => '$labelの支出を削除しました',
        AppLanguage.tr => source,
      };
    }

    final scenario = RegExp(r'^Senaryo (\d+) / (\d+)$').firstMatch(source);
    if (scenario != null) {
      final a = scenario.group(1)!;
      final b = scenario.group(2)!;
      return switch (language) {
        AppLanguage.en => 'Scenario $a / $b',
        AppLanguage.fr => 'Scénario $a / $b',
        AppLanguage.de => 'Szenario $a / $b',
        AppLanguage.cn => '场景 $a / $b',
        AppLanguage.jp => 'シナリオ $a / $b',
        AppLanguage.tr => source,
      };
    }

    final count = RegExp(r'^(\d+) kayıt$').firstMatch(source);
    if (count != null) {
      final n = count.group(1)!;
      return switch (language) {
        AppLanguage.en => '$n records',
        AppLanguage.fr => '$n enregistrements',
        AppLanguage.de => '$n Einträge',
        AppLanguage.cn => '$n 条记录',
        AppLanguage.jp => '$n 件',
        AppLanguage.tr => source,
      };
    }

    final allTime = RegExp(r'^Tüm zamanlar (.+)$').firstMatch(source);
    if (allTime != null) {
      final money = allTime.group(1)!;
      return switch (language) {
        AppLanguage.en => 'All time $money',
        AppLanguage.fr => 'Depuis toujours $money',
        AppLanguage.de => 'Gesamt $money',
        AppLanguage.cn => '全部时间 $money',
        AppLanguage.jp => '全期間 $money',
        AppLanguage.tr => source,
      };
    }

    final history = RegExp(r'^(.+) geçmişi$').firstMatch(source);
    if (history != null) {
      final name = history.group(1)!;
      return switch (language) {
        AppLanguage.en => '$name history',
        AppLanguage.fr => 'Historique $name',
        AppLanguage.de => '$name-Verlauf',
        AppLanguage.cn => '$name历史',
        AppLanguage.jp => '$nameの履歴',
        AppLanguage.tr => source,
      };
    }

    final points = RegExp(r'^(\d+) nokta$').firstMatch(source);
    if (points != null) {
      final n = points.group(1)!;
      return switch (language) {
        AppLanguage.en => '$n points',
        AppLanguage.fr => '$n points',
        AppLanguage.de => '$n Punkte',
        AppLanguage.cn => '$n 个点',
        AppLanguage.jp => '$n 点',
        AppLanguage.tr => source,
      };
    }

    final dated = _translateDate(source);
    if (dated != null) return dated;

    final paren = RegExp(r'^(.+?)( \(.+\))$').firstMatch(source);
    if (paren != null) {
      final head = phrases[paren.group(1)!];
      if (head != null) return '$head${paren.group(2)}';
    }

    final colon = RegExp(r'^([^:]+): (.+)$').firstMatch(source);
    if (colon != null) {
      final head = phrases[colon.group(1)!];
      final tail = colon.group(2)!;
      if (head != null && tail.length <= 32) return '$head: $tail';
    }

    return null;
  }

  String? _translateDate(String source) {
    const months = [
      'Ocak',
      'Şubat',
      'Mart',
      'Nisan',
      'Mayıs',
      'Haziran',
      'Temmuz',
      'Ağustos',
      'Eylül',
      'Ekim',
      'Kasım',
      'Aralık',
    ];
    final match = RegExp(
      '^(?:(\\d{1,2}) )?(${months.join('|')})(?: (\\d{4}))?\$',
    ).firstMatch(source);
    if (match == null) return null;
    final name = phrases[match.group(2)!];
    if (name == null) return null;
    final day = match.group(1);
    final year = match.group(3);
    if (day == null && year == null) return name;
    if (day == null) return '$name $year';
    if (year == null) return '$day $name';
    return '$day $name $year';
  }
}

/// Loads [AppStrings] for the locale selected in settings.
final class AppStringsDelegate extends LocalizationsDelegate<AppStrings> {
  /// Creates the delegate.
  const AppStringsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<AppStrings> load(Locale locale) async {
    final language = AppLanguage.fromLocale(locale);
    if (language == AppLanguage.tr) {
      return AppStrings(language, const {});
    }
    final code = switch (language) {
      AppLanguage.en => 'en',
      AppLanguage.fr => 'fr',
      AppLanguage.de => 'de',
      AppLanguage.cn => 'zh',
      AppLanguage.jp => 'ja',
      AppLanguage.tr => 'tr',
    };
    final raw = await rootBundle.loadString('assets/l10n/$code.json');
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      return AppStrings(language, const {});
    }
    final phrases = <String, String>{};
    for (final entry in decoded.entries) {
      final value = entry.value;
      if (value is String) phrases[entry.key] = value;
    }
    return AppStrings(language, phrases);
  }

  @override
  bool shouldReload(covariant AppStringsDelegate old) => false;
}

/// Reads translated copy from the active [AppStrings].
extension AppStringsContext on BuildContext {
  /// [source] in the language chosen in settings.
  String s(String source) => AppStrings.of(this).translate(source);
}
