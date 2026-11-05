import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_ders/app/app.dart';
import 'package:flutter_ders/app/core/di/injection.dart';
import 'package:flutter_ders/app/core/firebase/app_config_cubit.dart';
import 'package:flutter_ders/app/core/firebase/firebase_services.dart';
import 'package:flutter_ders/app/core/firebase/remote_app_config.dart';
import 'package:flutter_ders/app/core/firebase/session_cubit.dart';
import 'package:flutter_ders/app/views/view_auth/cubit/sign_in_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/lessons.dart';

final _template = File('remoteconfig.template.json').readAsStringSync();
final _defaults = defaultsFromTemplate(_template);

/// Yerel kaynak + istenen sürüm ve oturumla DI'yi kurar, ayarları yükler.
Future<LocalConfigSource> _setup({
  Map<String, String> remote = const {},
  String version = '1.0.0',
  AppUser? user = LocalAuthRepository.kDemoUser,
}) async {
  await getIt.reset();
  SharedPreferences.setMockInitialValues({});
  await configureDependencies();
  final source = LocalConfigSource(remote: remote);
  await getIt.unregister<ConfigSource>();
  await getIt.unregister<AppConfigCubit>();
  await getIt.unregister<AuthRepository>();
  await getIt.unregister<SessionCubit>();
  final auth = LocalAuthRepository(user: user);
  getIt
    ..registerSingleton<ConfigSource>(source)
    ..registerSingleton<AuthRepository>(auth)
    ..registerSingleton(
      AppConfigCubit(
        source: source,
        template: () async => _template,
        appVersion: () async => version,
        prefs: SharedPreferences.getInstance,
        deviceLanguage: 'tr',
      ),
    )
    ..registerSingleton(
      SessionCubit(auth: auth, crash: getIt<CrashReporter>()),
    );
  await getIt<AppConfigCubit>().start();
  return source;
}

/// Ayarlar ve oturum, runAsync içinde kurulduğu için akış olayları gerçek
/// olay döngüsünde gelir: önce ona bir tur verilir, sonra çizilir.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  }
  await tester.pumpAndSettle();
}

void main() {
  group('şablon ve çözümleme', () {
    test('şablondaki her parametre okunur; iki dilde aynı anahtarlar', () {
      expect(_defaults.keys, {
        RcKeys.design,
        RcKeys.texts,
        RcKeys.language,
        RcKeys.minVersion,
        RcKeys.latestVersion,
        RcKeys.updateUrl,
      });
      final texts = jsonDecode(_defaults[RcKeys.texts]!) as Map;
      expect(
        (texts['tr'] as Map).keys.toSet(),
        (texts['en'] as Map).keys.toSet(),
      );
    });

    test('bozuk değerler varsayılanda kalır', () {
      final c = RemoteAppConfig.parse({
        RcKeys.design: '{"birincil":"mavi","kose":99,"yazi_olcegi":1.2}',
        RcKeys.texts: 'json değil',
        RcKeys.minVersion: 'abc',
        RcKeys.updateUrl: 'https://kotu.example.com/indir',
      }, fallback: _defaults);
      expect(c.design.primary, const DesignTokens().primary);
      expect(c.design.radius, const DesignTokens().radius);
      expect(c.design.textScale, 1.2);
      expect(c.text('tr', 'auth.google'), 'Google ile devam et');
      expect(c.policy.min, isNull);
      expect(c.policy.updateUrl, isNull, reason: 'izinsiz sunucu');
    });

    test('uzaktaki metinde eksik anahtar uygulamadakiyle tamamlanır', () {
      final c = RemoteAppConfig.parse({
        RcKeys.texts: '{"en":{"auth.google":"Log in with Google"}}',
      }, fallback: _defaults);
      expect(c.text('en', 'auth.google'), 'Log in with Google');
      expect(c.text('en', 'auth.cikis'), 'Sign out');
      expect(c.text('en', 'olmayan.anahtar'), 'olmayan.anahtar');
    });

    test('sürüm kuralları', () {
      const p = VersionPolicy(
        min: SemVer(1, 2, 0),
        latest: SemVer(1, 4, 0),
        updateUrl: null,
      );
      expect(p.statusFor(SemVer.tryParse('1.1.9')), UpdateStatus.forced);
      expect(p.statusFor(SemVer.tryParse('1.2.0+7')), UpdateStatus.optional);
      expect(p.statusFor(SemVer.tryParse('1.4')), UpdateStatus.upToDate);
      expect(p.statusFor(SemVer.tryParse('2.0.0-beta')), UpdateStatus.upToDate);
      expect(p.statusFor(null), UpdateStatus.upToDate);
    });

    test('dil: seçim > Remote Config > cihaz > tr', () {
      final c = RemoteAppConfig.parse(_defaults);
      expect(c.resolveLanguage(deviceLanguage: 'en'), 'en');
      expect(c.resolveLanguage(deviceLanguage: 'de'), 'tr');
      expect(c.resolveLanguage(override: 'tr', deviceLanguage: 'en'), 'tr');
      final rc = RemoteAppConfig.parse({
        RcKeys.language: 'en',
      }, fallback: _defaults);
      expect(rc.resolveLanguage(deviceLanguage: 'tr'), 'en');
    });
  });

  group('Google ile giriş', () {
    test('hata kodları metin anahtarına çevrilir', () {
      expect(
        AuthFailure.fromGoogle(GoogleSignInExceptionCode.canceled).cancelled,
        isTrue,
      );
      expect(
        AuthFailure.fromGoogle(
          GoogleSignInExceptionCode.clientConfigurationError,
        ).key,
        'hata.yapilandirma',
      );
      expect(
        AuthFailure.fromFirebase('operation-not-allowed').key,
        'hata.yontem_kapali',
      );
      expect(AuthFailure.fromFirebase('yeni-bir-kod').key, 'hata.bilinmeyen');
    });

    test('vazgeçmek raporlanmaz, yapılandırma hatası raporlanır', () async {
      final crash = MemoryCrashReporter();
      final auth = LocalAuthRepository(
        user: null,
        failure: const AuthFailure('hata.iptal'),
      );
      final c = SignInCubit(auth: auth, crash: crash);
      await c.signIn();
      expect(c.state.errorKey, 'hata.iptal');
      expect(crash.records, isEmpty);

      auth.failure = const AuthFailure('hata.yapilandirma');
      await c.signIn();
      expect(crash.records.single, startsWith('error:'));
      await c.close();
    });
  });

  group('uygulama kapısı', () {
    testWidgets('oturum yoksa giriş ekranı; Google ile girince uygulama', (
      tester,
    ) async {
      await tester.runAsync(() => _setup(user: null));
      await tester.pumpWidget(const HarcamaApp(watchNetwork: false));
      await tester.pumpAndSettle();
      expect(find.text('Hoş geldin'), findsOneWidget);
      expect(find.text('Google ile devam et'), findsOneWidget);
      expect(find.byKey(const Key('expensesView_add')), findsNothing);

      await tester.tap(find.byKey(const Key('auth_google')));
      await _settle(tester);
      expect(find.byKey(const Key('expensesView_add')), findsOneWidget);
    });

    testWidgets('vazgeçince giriş ekranında kalınır', (tester) async {
      await tester.runAsync(() async {
        await _setup(user: null);
        (getIt<AuthRepository>() as LocalAuthRepository).failure =
            const AuthFailure('hata.iptal');
      });
      await tester.pumpWidget(const HarcamaApp(watchNetwork: false));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('auth_google')));
      await _settle(tester);
      expect(find.text('Giriş iptal edildi.'), findsOneWidget);
      expect(find.byKey(const Key('expensesView_add')), findsNothing);
    });

    testWidgets('dil düğmesi metinleri değiştirir', (tester) async {
      await tester.runAsync(() => _setup(user: null));
      await tester.pumpWidget(const HarcamaApp(watchNetwork: false));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('lang_en')));
      await tester.pumpAndSettle();
      expect(find.text('Welcome'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
      await tester.tap(find.byKey(const Key('lang_tr')));
      await tester.pumpAndSettle();
      expect(find.text('Google ile devam et'), findsOneWidget);
    });

    testWidgets('min_surum altı kilitlenir; konsoldan düşürülünce açılır', (
      tester,
    ) async {
      final source = await tester.runAsync(
        () => _setup(remote: {RcKeys.minVersion: '2.0.0'}),
      );
      await tester.pumpWidget(const HarcamaApp(watchNetwork: false));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('force_update')), findsOneWidget);
      expect(find.text('Güncelleme gerekli'), findsOneWidget);
      expect(find.byKey(const Key('expensesView_add')), findsNothing);

      // Konsolda yayınlanmış gibi: canlı güncelleme.
      source!.publish({RcKeys.minVersion: '1.0.0'});
      await _settle(tester);
      expect(find.byKey(const Key('force_update')), findsNothing);
      expect(find.byKey(const Key('expensesView_add')), findsOneWidget);
    });

    testWidgets('son_surum altı kapatılabilir kart', (tester) async {
      await tester.runAsync(
        () => _setup(remote: {RcKeys.latestVersion: '1.1.0'}),
      );
      await tester.pumpWidget(const HarcamaApp(watchNetwork: false));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('optional_update')), findsOneWidget);
      expect(find.textContaining('1.1.0'), findsOneWidget);
      await tester.tap(find.byKey(const Key('optional_update_later')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('optional_update')), findsNothing);
    });

    testWidgets('tasarım belirteçleri temaya canlı yansır', (tester) async {
      final source = await tester.runAsync(_setup);
      await tester.pumpWidget(const HarcamaApp(watchNetwork: false));
      await tester.pumpAndSettle();
      ThemeData theme() =>
          Theme.of(tester.element(find.byKey(const Key('expensesView_add'))));
      expect(theme().colorScheme.primary, const Color(0xFF2563EB));

      source!.publish({RcKeys.design: '{"birincil":"#16A34A","kose":4}'});
      await _settle(tester);
      expect(theme().colorScheme.primary, const Color(0xFF16A34A));
      final shape =
          theme().filledButtonTheme.style!.shape!.resolve({})!
              as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(4));
      expect(getIt<AppConfigCubit>().state.lastUpdatedKeys, {RcKeys.design});
    });

    testWidgets('Firebase sayfası: çıkış yapınca giriş ekranına dönülür', (
      tester,
    ) async {
      await tester.runAsync(_setup);
      await tester.pumpWidget(const HarcamaApp(watchNetwork: false));
      await tester.pumpAndSettle();
      await openLessonsHub(tester);
      await tester.scrollUntilVisible(
        find.byKey(const Key('lessons_firebase')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('lessons_firebase')));
      await tester.pumpAndSettle();
      expect(find.text('deneme@ornek.com'), findsOneWidget);
      expect(find.text('Sunucu'), findsNothing);

      await tester.scrollUntilVisible(
        find.byKey(const Key('firebase_nonfatal')),
        300,
        scrollable: find.descendant(
          of: find.byKey(const Key('firebase_scroll')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('firebase_nonfatal')));
      await tester.pumpAndSettle();
      expect(
        (getIt<CrashReporter>() as MemoryCrashReporter).records.last,
        startsWith('error:'),
      );

      await tester.scrollUntilVisible(
        find.byKey(const Key('firebase_signout')),
        -300,
        scrollable: find.descendant(
          of: find.byKey(const Key('firebase_scroll')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('firebase_signout')));
      await _settle(tester);
      expect(find.text('Hoş geldin'), findsOneWidget);
      expect(context(tester).read<SessionCubit>().state.signedIn, isFalse);
    });
  });
}

BuildContext context(WidgetTester tester) =>
    tester.element(find.byKey(const Key('auth_scroll')));
