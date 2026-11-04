import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_ders/app/views/view_app_network/bloc/app_info_bloc.dart';
import 'package:flutter_ders/app/views/view_network/widgets/network_cards.dart';
import 'package:flutter_ders/app/widgets/common.dart';
import 'package:flutter_ders/app/widgets/info_section_card.dart';

/// DERS 14 — Uygulama sekmesi.
class AppInfoTab extends StatelessWidget {
  /// Sekmeyi oluşturur.
  const AppInfoTab({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: pagePadding(context).copyWith(top: 16, bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Uygulamanın kendisi: Android paket yöneticisinin bildiği sürüm, '
            'kurulum zamanı ve imza; derlemeye gömülen Flutter sürümü.',
            style: t.bodyMedium,
          ),
          const Gap(12),
          const CodeBox('''
final p = await PackageInfo.fromPlatform();
p.version;       // pubspec.yaml → version: 1.0.0+1
p.installTime;   // PackageManager.firstInstallTime
FlutterVersion.version; // flutter run derlemeye gömer'''),
          const Gap(12),
          BlocBuilder<AppInfoBloc, AppInfoState>(
            builder: (context, state) => switch (state) {
              AppInfoLoading() => const Center(
                child: CircularProgressIndicator(),
              ),
              AppInfoError(:final message) => Text(message),
              AppInfoLoaded(:final sections) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [for (final s in sections) InfoSectionCard(s)],
              ),
            },
          ),
        ],
      ),
    );
  }
}
