import 'package:equatable/equatable.dart';
import 'package:flutter_ders/app/core/locale/app_language.dart';

/// Language currently applied by settings.
final class SettingsState extends Equatable {
  /// Starts in Turkish so the lesson screens and existing tests stay as they
  /// are until the reader picks another language.
  const SettingsState({this.language = AppLanguage.tr});

  /// Selected language.
  final AppLanguage language;

  @override
  List<Object?> get props => [language];
}
