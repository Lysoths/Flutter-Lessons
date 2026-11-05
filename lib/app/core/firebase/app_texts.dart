import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_ders/app/core/firebase/app_config_cubit.dart';

/// DERS 18 — Remote Config'teki dil metinlerine erişim.
///
/// `context.text('auth.giris')` build içinde kullanılır; dil ya da metin
/// değişince widget yeniden çizilir. Olay işleyicilerde (onPressed)
/// `context.readText(...)` kullanılır.
extension AppTextsX on BuildContext {
  /// Geçerli dilde metin (dinler).
  String text(String key) =>
      select<AppConfigCubit, String>((c) => c.state.t(key));

  /// Geçerli dilde metin (dinlemez).
  String readText(String key) => read<AppConfigCubit>().state.t(key);
}
