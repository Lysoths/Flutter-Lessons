import 'package:flutter_ders/app/core/base/base_view_model_cubit.dart';
import 'package:flutter_ders/app/core/locale/app_language.dart';
import 'package:flutter_ders/app/views/view_settings/cubit/settings_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Remembers the language chosen on the settings screen.
class SettingsCubit extends BaseViewModelCubit<SettingsState> {
  /// Reads the last choice from [preferences]. Missing or unknown codes
  /// stay on Turkish.
  SettingsCubit({required SharedPreferences preferences})
    : _preferences = preferences,
      super(
        SettingsState(
          language: AppLanguage.fromCode(preferences.getString(storageKey)),
        ),
      );

  /// Preference key. Values are `en`, `tr`, `fr`, `cn`, `jp`, `de`.
  static const storageKey = 'settings.language';

  final SharedPreferences _preferences;

  /// Saves [language] and rebuilds the app locale.
  Future<void> select(AppLanguage language) async {
    if (state.language == language) return;
    await _preferences.setString(storageKey, language.code);
    stateChanger(SettingsState(language: language));
  }
}
