import 'package:flutter/material.dart';
import 'package:flutter_ders/app/app.dart';
import 'package:flutter_ders/app/core/di/injection.dart';
import 'package:flutter_ders/app/core/locale/app_language.dart';
import 'package:flutter_ders/app/views/view_settings/cubit/settings_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await getIt.reset();
    SharedPreferences.setMockInitialValues({});
    await configureDependencies();
  });

  test('the six settings codes map onto Flutter locales', () {
    expect(AppLanguage.values.map((language) => language.code), [
      'en',
      'tr',
      'fr',
      'cn',
      'jp',
      'de',
    ]);
    expect(AppLanguage.en.locale, const Locale('en'));
    expect(AppLanguage.tr.locale, const Locale('tr'));
    expect(AppLanguage.fr.locale, const Locale('fr'));
    expect(AppLanguage.cn.locale, const Locale('zh', 'CN'));
    expect(AppLanguage.jp.locale, const Locale('ja'));
    expect(AppLanguage.de.locale, const Locale('de'));
    expect(AppLanguage.fromCode('jp'), AppLanguage.jp);
    expect(AppLanguage.fromCode('ja'), AppLanguage.tr);
    expect(AppLanguage.fromCode(null), AppLanguage.tr);
  });

  test('the choice is stored as en, tr, fr, cn, jp, or de', () async {
    final cubit = getIt<SettingsCubit>();
    expect(cubit.state.language, AppLanguage.tr);

    await cubit.select(AppLanguage.cn);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(SettingsCubit.storageKey), 'cn');
    expect(cubit.state.language.locale, const Locale('zh', 'CN'));

    await cubit.select(AppLanguage.jp);
    expect(prefs.getString(SettingsCubit.storageKey), 'jp');
  });

  testWidgets('choosing French switches the settings copy', (tester) async {
    await tester.pumpWidget(const HarcamaApp(watchNetwork: false));
    await tester.pumpAndSettle();

    final scrollable = find
        .byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down,
        )
        .first;
    await tester.scrollUntilVisible(
      find.byKey(const Key('expensesView_settings')),
      200,
      scrollable: scrollable,
    );
    expect(find.text('Ayarlar'), findsOneWidget);

    await tester.tap(find.byKey(const Key('expensesView_settings')));
    await tester.pumpAndSettle();
    expect(find.text('Merhaba'), findsOneWidget);
    expect(find.text('中文'), findsOneWidget);
    expect(find.text('日本語'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const Key('settings_language_fr')),
      200,
      scrollable: scrollable,
    );
    await tester.tap(find.byKey(const Key('settings_language_fr')));
    await tester.pumpAndSettle();

    expect(find.text('Réglages'), findsWidgets);
    expect(find.text('Bonjour'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
  });
}
