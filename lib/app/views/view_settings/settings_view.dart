import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_ders/app/core/locale/app_copy.dart';
import 'package:flutter_ders/app/core/locale/app_language.dart';
import 'package:flutter_ders/app/core/locale/app_text.dart';
import 'package:flutter_ders/app/theme/app_theme.dart';
import 'package:flutter_ders/app/views/view_settings/cubit/settings_cubit.dart';
import 'package:flutter_ders/app/views/view_settings/cubit/settings_state.dart';
import 'package:flutter_ders/app/widgets/common.dart';

/// Language settings. The choice applies to every screen.
@RoutePage()
class SettingsView extends StatelessWidget {
  /// Creates the settings screen.
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, state) {
        final copy = AppCopy.of(state.language);
        final theme = Theme.of(context).textTheme;
        return Scaffold(
          appBar: AppBar(
            title: AppText(copy.settingsTitle),
            titleTextStyle: theme.titleLarge,
          ),
          body: ListView(
            padding: pagePadding(context).copyWith(top: 8, bottom: 24),
            children: [
              AppText(copy.greeting, style: theme.headlineSmall),
              const Gap(8),
              AppText(
                copy.languageBody,
                style: theme.bodyMedium?.copyWith(color: MfColors.slate600),
              ),
              const Gap(24),
              AppText(copy.languageHeading, style: theme.titleMedium),
              const Gap(12),
              for (final language in AppLanguage.values) ...[
                _LanguageTile(
                  language: language,
                  selected: language == state.language,
                  activeLabel: copy.active,
                  onTap: () {
                    unawaited(context.read<SettingsCubit>().select(language));
                  },
                ),
                const Gap(8),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _LanguageTile extends StatelessWidget {
  const _LanguageTile({
    required this.language,
    required this.selected,
    required this.activeLabel,
    required this.onTap,
  });

  final AppLanguage language;
  final bool selected;
  final String activeLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(16);
    return Material(
      color: selected ? const Color(0xFFEFF6FF) : MfColors.slate50,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(
          color: selected ? MfColors.blue600 : MfColors.slate200,
        ),
      ),
      child: InkWell(
        key: Key('settings_language_${language.code}'),
        borderRadius: radius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              AppText(
                language.code.toUpperCase(),
                style: theme.labelLarge?.copyWith(
                  color: selected ? MfColors.blue600 : MfColors.slate500,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: AppText(language.nativeName, style: theme.titleMedium),
              ),
              if (selected)
                AppText(
                  activeLabel,
                  style: theme.labelMedium?.copyWith(color: MfColors.blue600),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
