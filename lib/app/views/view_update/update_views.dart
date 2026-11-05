import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_ders/app/core/analytics/app_events.dart';
import 'package:flutter_ders/app/core/firebase/app_config_cubit.dart';
import 'package:flutter_ders/app/core/firebase/app_texts.dart';
import 'package:flutter_ders/app/core/firebase/remote_app_config.dart';
import 'package:flutter_ders/app/theme/app_theme.dart';
import 'package:flutter_ders/app/widgets/common.dart';
import 'package:url_launcher/url_launcher.dart';

/// Güncelleme adresini (yalnız izinli sunucu) dışarıda açar.
Future<void> openUpdateUrl(BuildContext context) async {
  final s = context.read<AppConfigCubit>().state;
  final url = s.config.policy.updateUrl;
  track(
    AppEvent.updateOpened,
    s.updateStatus == UpdateStatus.forced ? 'zorunlu' : 'istege_bagli',
  );
  if (url != null) {
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }
}

/// DERS 18 — Zorunlu güncelleme ekranı.
///
/// Yüklü sürüm `min_surum`un altındaysa AppGate uygulamanın yerine bunu
/// gösterir. Geri tuşu çalışmaz; konsolda `min_surum` düşürülünce ekran
/// kendiliğinden kalkar (canlı güncelleme).
class ForceUpdateView extends StatelessWidget {
  /// Ekranı oluşturur.
  const ForceUpdateView({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = context.watch<AppConfigCubit>().state;
    return PopScope(
      canPop: false,
      child: Scaffold(
        key: const Key('force_update'),
        body: SafeArea(
          child: Padding(
            padding: pagePadding(context).copyWith(top: 24, bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                const Icon(
                  Icons.system_update_rounded,
                  size: 64,
                  color: MfColors.red600,
                ),
                const Gap(20),
                Text(
                  context.text('guncelleme.zorunlu_baslik'),
                  textAlign: TextAlign.center,
                  style: t.headlineSmall,
                ),
                const Gap(10),
                Text(
                  context.text('guncelleme.zorunlu_metin'),
                  textAlign: TextAlign.center,
                  style: t.bodyLarge,
                ),
                const Gap(24),
                VersionTable(state: s),
                const Spacer(),
                FilledButton.icon(
                  key: const Key('force_update_open'),
                  onPressed: s.config.policy.updateUrl == null
                      ? null
                      : () => openUpdateUrl(context),
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: Text(context.text('guncelleme.guncelle')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Yüklü / en düşük / en son sürüm tablosu.
class VersionTable extends StatelessWidget {
  /// Oluşturur.
  const VersionTable({required this.state, super.key});

  /// Ayar durumu.
  final AppConfigState state;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = state.config.policy;
    Widget row(String key, String? v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(context.text(key), style: t.bodyMedium)),
          Text(v ?? '—', style: t.titleSmall),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MfColors.slate50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          row('guncelleme.yuklu', state.installedVersion),
          row('guncelleme.en_dusuk', p.min?.toString()),
          row('guncelleme.en_son', p.latest?.toString()),
        ],
      ),
    );
  }
}

/// DERS 18 — İsteğe bağlı güncelleme kartı (ekranın altında, kapatılabilir).
class OptionalUpdateCard extends StatelessWidget {
  /// Oluşturur.
  const OptionalUpdateCard({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cubit = context.read<AppConfigCubit>();
    final latest = context.select<AppConfigCubit, String?>(
      (c) => c.state.config.policy.latest?.toString(),
    );
    return Material(
      key: const Key('optional_update'),
      color: MfColors.slate900,
      elevation: 6,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          children: [
            const Icon(Icons.new_releases_rounded, color: MfColors.blue100),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${context.text('guncelleme.istege_baslik')} · $latest',
                    style: t.titleSmall?.copyWith(color: Colors.white),
                  ),
                  Text(
                    context.text('guncelleme.istege_metin'),
                    style: t.bodySmall?.copyWith(color: MfColors.slate200),
                  ),
                ],
              ),
            ),
            TextButton(
              key: const Key('optional_update_later'),
              onPressed: cubit.dismissOptionalUpdate,
              child: Text(
                context.text('guncelleme.sonra'),
                style: const TextStyle(color: MfColors.slate200),
              ),
            ),
            TextButton(
              key: const Key('optional_update_open'),
              onPressed: () => openUpdateUrl(context),
              child: Text(
                context.text('guncelleme.guncelle'),
                style: const TextStyle(color: MfColors.blue100),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
