import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_ders/app/core/di/injection.dart';
import 'package:flutter_ders/app/core/firebase/app_config_cubit.dart';
import 'package:flutter_ders/app/core/firebase/app_texts.dart';
import 'package:flutter_ders/app/core/firebase/remote_app_config.dart';
import 'package:flutter_ders/app/theme/app_theme.dart';
import 'package:flutter_ders/app/views/view_auth/cubit/sign_in_cubit.dart';
import 'package:flutter_ders/app/widgets/common.dart';

/// DERS 18 — Google ile giriş ekranı.
///
/// Bir rota değildir: oturum yokken AppGate uygulamanın yerine bunu
/// gösterir. Tüm metinler Remote Config'teki `dil_metinleri`nden gelir.
class AuthView extends StatelessWidget {
  /// Ekranı oluşturur.
  const AuthView({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => getIt<SignInCubit>(),
    child: const _AuthBody(),
  );
}

class _AuthBody extends StatelessWidget {
  const _AuthBody();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = context.watch<SignInCubit>().state;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          key: const Key('auth_scroll'),
          padding: pagePadding(context).copyWith(top: 12, bottom: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Align(
                alignment: Alignment.centerRight,
                child: LanguageSwitch(),
              ),
              const Spacer(),
              Align(
                alignment: Alignment.centerLeft,
                child: Eyebrow(context.text('uygulama.ad')),
              ),
              const Gap(12),
              Text(context.text('auth.baslik'), style: t.displaySmall),
              const Gap(8),
              Text(context.text('auth.alt_baslik'), style: t.bodyLarge),
              const Spacer(),
              if (s.errorKey case final k?) ...[
                Text(
                  context.text(k),
                  key: const Key('auth_error'),
                  textAlign: TextAlign.center,
                  style: t.bodyMedium?.copyWith(
                    color: k == 'hata.iptal'
                        ? MfColors.slate500
                        : MfColors.red600,
                  ),
                ),
                const Gap(12),
              ],
              FilledButton.icon(
                key: const Key('auth_google'),
                onPressed: s.busy ? null : context.read<SignInCubit>().signIn,
                icon: s.busy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const _GoogleMark(),
                label: Text(context.text('auth.google')),
              ),
              const Gap(12),
              Text(
                context.text('auth.bilgi'),
                textAlign: TextAlign.center,
                style: t.bodySmall?.copyWith(color: MfColors.slate500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Beyaz daire içinde "G" harfi (marka görseli kullanılmaz).
class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) => Container(
    width: 22,
    height: 22,
    alignment: Alignment.center,
    decoration: const BoxDecoration(
      color: Colors.white,
      shape: BoxShape.circle,
    ),
    child: const Text(
      'G',
      style: TextStyle(
        color: MfColors.slate900,
        fontWeight: FontWeight.w800,
        fontSize: 13,
      ),
    ),
  );
}

/// TR / EN / Cihaz seçimi.
class LanguageSwitch extends StatelessWidget {
  /// Oluşturur.
  const LanguageSwitch({super.key});

  @override
  Widget build(BuildContext context) {
    final override = context.select<AppConfigCubit, String?>(
      (c) => c.state.languageOverride,
    );
    return SegmentedButton<String>(
      key: const Key('language_switch'),
      showSelectedIcon: false,
      style: const ButtonStyle(visualDensity: VisualDensity.compact),
      segments: [
        for (final l in kSupportedLanguages)
          ButtonSegment(
            value: l,
            label: Text(l.toUpperCase(), key: Key('lang_$l')),
          ),
        const ButtonSegment(
          value: 'cihaz',
          icon: Icon(
            Icons.phone_android_rounded,
            size: 18,
            key: Key('lang_auto'),
          ),
        ),
      ],
      selected: {override ?? 'cihaz'},
      onSelectionChanged: (s) => context.read<AppConfigCubit>().setLanguage(
        s.first == 'cihaz' ? null : s.first,
      ),
    );
  }
}
