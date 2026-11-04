import 'package:flutter_ders/app/core/locale/app_language.dart';

/// Strings for the settings screen and the home entry that opens it.
final class AppCopy {
  /// One language's copy.
  const AppCopy({
    required this.appTitle,
    required this.settingsTitle,
    required this.settingsSubtitle,
    required this.languageHeading,
    required this.languageBody,
    required this.greeting,
    required this.active,
  });

  /// Window title.
  final String appTitle;

  /// Settings screen title and the home card title.
  final String settingsTitle;

  /// Home card subtitle.
  final String settingsSubtitle;

  /// Section title above the language list.
  final String languageHeading;

  /// Explains what the choice changes.
  final String languageBody;

  /// Short line that changes with the language, so the switch is obvious.
  final String greeting;

  /// Label on the selected language.
  final String active;

  /// Copy for [language].
  static AppCopy of(AppLanguage language) => _copies[language]!;

  static const Map<AppLanguage, AppCopy> _copies = {
    AppLanguage.en: AppCopy(
      appTitle: 'Expense Tracker',
      settingsTitle: 'Settings',
      settingsSubtitle: 'English, Turkish, French, Chinese, Japanese, German',
      languageHeading: 'Language',
      languageBody:
          'The choice is saved on this device. Settings and the system '
          'locale follow it. Lesson screens keep their original copy.',
      greeting: 'Hello',
      active: 'Active',
    ),
    AppLanguage.tr: AppCopy(
      appTitle: 'Harcama Takibim',
      settingsTitle: 'Ayarlar',
      settingsSubtitle: 'İngilizce, Türkçe, Fransızca, Çince, Japonca, Almanca',
      languageHeading: 'Dil',
      languageBody:
          'Seçim bu cihaza kaydedilir. Ayarlar ve sistem dili buna uyar. '
          'Ders ekranları kendi metninde kalır.',
      greeting: 'Merhaba',
      active: 'Seçili',
    ),
    AppLanguage.fr: AppCopy(
      appTitle: 'Suivi des dépenses',
      settingsTitle: 'Réglages',
      settingsSubtitle: 'Anglais, turc, français, chinois, japonais, allemand',
      languageHeading: 'Langue',
      languageBody:
          'Le choix est enregistré sur cet appareil. Les réglages et la '
          'langue du système suivent ce choix. Les écrans de cours gardent '
          'leur texte d’origine.',
      greeting: 'Bonjour',
      active: 'Active',
    ),
    AppLanguage.cn: AppCopy(
      appTitle: '支出记录',
      settingsTitle: '设置',
      settingsSubtitle: '英语、土耳其语、法语、中文、日语、德语',
      languageHeading: '语言',
      languageBody: '选择会保存在这台设备上。设置和系统语言会随之切换。课程页面仍使用原文。',
      greeting: '你好',
      active: '当前',
    ),
    AppLanguage.jp: AppCopy(
      appTitle: '支出トラッカー',
      settingsTitle: '設定',
      settingsSubtitle: '英語、トルコ語、フランス語、中国語、日本語、ドイツ語',
      languageHeading: '言語',
      languageBody: '選択はこの端末に保存されます。設定とシステムの言語が切り替わります。レッスン画面は元の文章のままです。',
      greeting: 'こんにちは',
      active: '選択中',
    ),
    AppLanguage.de: AppCopy(
      appTitle: 'Ausgaben',
      settingsTitle: 'Einstellungen',
      settingsSubtitle:
          'Englisch, Türkisch, Französisch, Chinesisch, Japanisch, Deutsch',
      languageHeading: 'Sprache',
      languageBody:
          'Die Auswahl wird auf diesem Gerät gespeichert. Einstellungen und '
          'die Systemsprache folgen ihr. Die Lektionsseiten behalten ihren '
          'Originaltext.',
      greeting: 'Hallo',
      active: 'Aktiv',
    ),
  };
}
