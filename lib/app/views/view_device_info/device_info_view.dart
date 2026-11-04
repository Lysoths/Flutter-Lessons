import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_ders/app/core/device/device_info_source.dart';
import 'package:flutter_ders/app/core/di/injection.dart';
import 'package:flutter_ders/app/helper/measure_format.dart';
import 'package:flutter_ders/app/models/info_section.dart';
import 'package:flutter_ders/app/theme/app_theme.dart';
import 'package:flutter_ders/app/views/view_device_info/bloc/device_info_bloc.dart';
import 'package:flutter_ders/app/views/view_device_info/bloc/device_info_event.dart';
import 'package:flutter_ders/app/views/view_device_info/bloc/device_info_state.dart';
import 'package:flutter_ders/app/views/view_network/widgets/network_cards.dart';
import 'package:flutter_ders/app/widgets/common.dart';
import 'package:flutter_ders/app/widgets/info_section_card.dart';

// ─────────────────────────────────────────────────────────────────────────
// DERS 14 — 1. ekran: cihaz bilgisi
//
//   Ekran ──add(DeviceInfoRequested)──▶ DeviceInfoBloc ──▶ DeviceInfoSource
//                                             │               (device_info_plus)
//         ◀──── DeviceInfoLoaded(report) ─────┘
//
// "Ekran" bölümü Bloc'tan gelmez: MediaQuery ile her çizimde okunur, telefon
// dönünce kendiliğinden güncellenir.
// ─────────────────────────────────────────────────────────────────────────

/// Cihaz bilgisi sayfası.
@RoutePage()
class DeviceInfoView extends StatelessWidget {
  /// Sayfayı oluşturur.
  const DeviceInfoView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<DeviceInfoBloc>()..add(const DeviceInfoRequested()),
      child: const _DeviceInfoPage(),
    );
  }
}

class _DeviceInfoPage extends StatelessWidget {
  const _DeviceInfoPage();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cihaz bilgisi'),
        titleTextStyle: t.titleLarge,
        actions: [
          IconButton(
            key: const Key('deviceInfo_refresh'),
            tooltip: 'Yenile',
            onPressed: () =>
                context.read<DeviceInfoBloc>().add(const DeviceInfoRefreshed()),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: BlocBuilder<DeviceInfoBloc, DeviceInfoState>(
        builder: (context, state) {
          final (report, loading) = switch (state) {
            DeviceInfoLoaded(:final report) => (report, false),
            DeviceInfoLoading(:final previous) => (previous, true),
            _ => (null, state is DeviceInfoInitial),
          };
          return SingleChildScrollView(
            key: const Key('deviceInfo_list'),
            padding: pagePadding(context).copyWith(top: 16, bottom: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Uygulamanın izin istemeden okuyabildiği her şey. Bilgiler '
                  'yalnızca ekranda gösterilir; kaydedilmez, gönderilmez.',
                  style: t.bodyMedium,
                ),
                const Gap(12),
                const CodeBox('''
final info = await DeviceInfoPlugin().androidInfo;
info.model;            // Build.MODEL
info.version.sdkInt;   // Build.VERSION.SDK_INT
info.physicalRamSize;  // ActivityManager.MemoryInfo (MB)
info.systemFeatures;   // PackageManager özellik listesi'''),
                const Gap(12),
                if (loading) const LinearProgressIndicator(),
                if (state case DeviceInfoLoaded(
                  :final readAt,
                  :final took,
                )) ...[
                  _Summary(state: state, readAt: readAt, took: took),
                  const Gap(12),
                ],
                if (state case DeviceInfoError(:final message))
                  Text(message, key: const Key('deviceInfo_error')),
                const _ScreenCard(),
                if (report != null)
                  Opacity(
                    opacity: loading ? 0.4 : 1,
                    child: _ReportBody(report),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.state,
    required this.readAt,
    required this.took,
  });

  final DeviceInfoLoaded state;
  final DateTime readAt;
  final Duration took;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    String two(int n) => n.toString().padLeft(2, '0');
    return Container(
      key: const Key('deviceInfo_summary'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MfColors.blue50,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        '${state.fieldCount} alan · ${state.report.raw.length} ham anahtar · '
        'okuma ${formatDuration(took)} · '
        '${two(readAt.hour)}:${two(readAt.minute)}:${two(readAt.second)}',
        style: t.titleSmall?.copyWith(color: MfColors.blue700),
      ),
    );
  }
}

/// Ekran: MediaQuery ve View'dan canlı.
class _ScreenCard extends StatelessWidget {
  const _ScreenCard();

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final view = View.of(context);
    final px = view.physicalSize;
    String insets(EdgeInsets e) =>
        'üst ${e.top.round()} · alt ${e.bottom.round()} · '
        'sol ${e.left.round()} · sağ ${e.right.round()}';
    return InfoSectionCard(
      InfoSection(
        id: 'screen',
        title: 'Ekran (canlı, MediaQuery)',
        entries: [
          InfoEntry(
            'Fiziksel çözünürlük',
            '${px.width.round()} × ${px.height.round()} px',
          ),
          InfoEntry(
            'Mantıksal boyut',
            '${mq.size.width.round()} × ${mq.size.height.round()} dp',
          ),
          InfoEntry(
            'Piksel oranı (dpr)',
            mq.devicePixelRatio.toStringAsFixed(2),
          ),
          InfoEntry(
            'Yenileme hızı',
            '${view.display.refreshRate.toStringAsFixed(0)} Hz',
          ),
          InfoEntry(
            'Yön',
            mq.orientation == Orientation.portrait ? 'Dikey' : 'Yatay',
          ),
          InfoEntry('Güvenli alan', insets(mq.padding)),
          InfoEntry('Klavye alanı', '${mq.viewInsets.bottom.round()} dp'),
          InfoEntry('Yazı ölçeği', '${mq.textScaler.scale(10) / 10}×'),
          InfoEntry(
            'Tema',
            mq.platformBrightness == Brightness.dark ? 'Koyu' : 'Açık',
          ),
          InfoEntry('Kalın yazı', orDash(mq.boldText)),
          InfoEntry('Yüksek kontrast', orDash(mq.highContrast)),
          InfoEntry('Animasyonlar kapalı', orDash(mq.disableAnimations)),
          InfoEntry('24 saat biçimi', orDash(mq.alwaysUse24HourFormat)),
          InfoEntry('Erişilebilir gezinme', orDash(mq.accessibleNavigation)),
        ],
      ),
    );
  }
}

class _ReportBody extends StatelessWidget {
  const _ReportBody(this.report);

  final DeviceInfoReport report;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final s in report.sections) InfoSectionCard(s),
        if (report.systemFeatures.isNotEmpty)
          _Expandable(
            key: const Key('deviceInfo_features'),
            icon: Icons.checklist_rounded,
            title: 'Sistem özellikleri (${report.systemFeatures.length})',
            subtitle: 'PackageManager: kamera, NFC, parmak izi, 5G ...',
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final f in report.systemFeatures)
                  Eyebrow(
                    f
                        .replaceFirst('android.hardware.', '')
                        .replaceFirst('android.software.', 'yazılım · '),
                    color: MfColors.slate600,
                    background: MfColors.slate100,
                  ),
              ],
            ),
          ),
        _Expandable(
          key: const Key('deviceInfo_raw'),
          icon: Icons.data_object_rounded,
          title: 'Ham veri (${report.raw.length} anahtar)',
          subtitle: 'Eklentinin döndürdüğü Map, olduğu gibi',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final e in report.raw.entries)
                if (e.key != 'systemFeatures')
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '${e.key}: ',
                            style: const TextStyle(
                              color: MfColors.blue700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          TextSpan(text: '${e.value}'),
                        ],
                      ),
                      style: t.bodySmall?.copyWith(fontFamily: 'monospace'),
                    ),
                  ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Expandable extends StatelessWidget {
  const _Expandable({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: MfColors.slate200),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: IconBadge(icon),
        title: Text(title, style: t.titleSmall),
        subtitle: Text(subtitle, style: t.bodySmall),
        shape: const Border(),
        collapsedShape: const Border(),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        children: [child],
      ),
    );
  }
}
