import 'package:flutter/widgets.dart';

/// A language the settings screen can apply.
///
/// [code] is the value stored on the device (`en`, `tr`, `fr`, `cn`, `jp`,
/// `de`). [languageCode] is the Flutter locale. Chinese and Japanese use
/// `zh` and `ja` because those are the codes Flutter ships.
enum AppLanguage {
  /// English.
  en(code: 'en', languageCode: 'en', nativeName: 'English'),

  /// Turkish.
  tr(code: 'tr', languageCode: 'tr', nativeName: 'Türkçe'),

  /// French.
  fr(code: 'fr', languageCode: 'fr', nativeName: 'Français'),

  /// Chinese (Simplified, China). Stored as `cn`.
  cn(code: 'cn', languageCode: 'zh', countryCode: 'CN', nativeName: '中文'),

  /// Japanese. Stored as `jp`.
  jp(code: 'jp', languageCode: 'ja', nativeName: '日本語'),

  /// German.
  de(code: 'de', languageCode: 'de', nativeName: 'Deutsch');

  /// One language option.
  const AppLanguage({
    required this.code,
    required this.languageCode,
    required this.nativeName,
    this.countryCode,
  });

  /// Code saved in preferences. Matches the settings list.
  final String code;

  /// ISO language code passed to [Locale].
  final String languageCode;

  /// Optional region. Chinese uses `CN`.
  final String? countryCode;

  /// Name written in that language.
  final String nativeName;

  /// Locale applied to [MaterialApp].
  Locale get locale => Locale(languageCode, countryCode);

  /// Locales Flutter should accept.
  static List<Locale> get supportedLocales =>
      values.map((language) => language.locale).toList(growable: false);

  /// Reads a stored [code]. Unknown values fall back to Turkish.
  static AppLanguage fromCode(String? code) {
    for (final language in values) {
      if (language.code == code) return language;
    }
    return tr;
  }
}
