import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_ders/app/core/di/injection.dart';
import 'package:flutter_ders/app/core/hardware/hardware_profile.dart';
import 'package:flutter_ders/app/core/hardware/hardware_source.dart';
import 'package:flutter_ders/app/helper/measure_format.dart';
import 'package:flutter_ders/app/helper/money_format.dart';
import 'package:flutter_ders/app/theme/app_theme.dart';
import 'package:flutter_ders/app/views/view_hardware/cubit/hardware_cubit.dart';
import 'package:flutter_ders/app/views/view_hardware/hardware_format.dart';
import 'package:flutter_ders/app/views/view_hardware/widgets/hardware_widgets.dart';
import 'package:flutter_ders/app/widgets/common.dart';

/// DERS 22 — Kendi platform channel'ımızla telefonun donanım profili.
@RoutePage()
class HardwareView extends StatelessWidget {
  /// Sayfayı oluşturur.
  const HardwareView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => HardwareCubit(source: getIt<HardwareSource>())..init(),
      child: const _HardwareBody(),
    );
  }
}

class _HardwareBody extends StatelessWidget {
  const _HardwareBody();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Donanım profili'),
        titleTextStyle: t.titleLarge,
        actions: [
          BlocBuilder<HardwareCubit, HardwareState>(
            buildWhen: (a, b) =>
                a.status != b.status || a.refreshing != b.refreshing,
            builder: (context, s) => s.status == HardwareStatus.ready
                ? IconButton(
                    key: const Key('hardware_refresh'),
                    tooltip: 'Yenile',
                    onPressed: s.refreshing
                        ? null
                        : context.read<HardwareCubit>().refresh,
                    icon: const Icon(Icons.refresh_rounded),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
      body: BlocBuilder<HardwareCubit, HardwareState>(
        builder: (context, s) => switch (s.status) {
          HardwareStatus.loading => const Center(
            child: CircularProgressIndicator(),
          ),
          HardwareStatus.unsupported => const _Message(
            'Donanım kanalı yalnız Android telefonda çalışır.',
          ),
          HardwareStatus.failed => _Message(
            'Donanım bilgisi okunamadı.',
            onRetry: context.read<HardwareCubit>().refresh,
          ),
          HardwareStatus.ready => _ProfileList(state: s, profile: s.profile!),
        },
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text, {this.onRetry});

  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.memory_rounded, size: 40, color: MfColors.slate400),
          const Gap(10),
          Text(text, textAlign: TextAlign.center),
          if (onRetry != null) ...[
            const Gap(12),
            OutlinedButton(
              onPressed: onRetry,
              child: const Text('Tekrar dene'),
            ),
          ],
        ],
      ),
    ),
  );
}

class _ProfileList extends StatelessWidget {
  const _ProfileList({required this.state, required this.profile});

  final HardwareState state;
  final DeviceProfile profile;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cubit = context.read<HardwareCubit>();
    final p = profile;
    final id = p.identity.androidId;
    final screen = p.display;
    final inches = screen.diagonalInches;
    final b = p.battery;
    final phone = p.telephony;

    return ListView(
      key: const Key('hardware_list'),
      padding: pagePadding(context).copyWith(top: 8, bottom: 40),
      children: [
        Text(
          'Bilgiler Kotlin tarafındaki kendi kanalımızla Android '
          "API'lerinden okunur. Hiçbiri kaydedilmez, gönderilmez ya da "
          'log\'a yazılmaz.',
          style: t.bodyMedium,
        ),
        const Gap(14),
        HardwareHero(profile: p),
        const Gap(12),
        LiveCard(live: state.live, history: state.currentHistory, cpu: p.cpu),
        const Gap(18),
        HardwareSection(
          id: 'identity',
          icon: Icons.badge_rounded,
          title: 'Kimlik',
          summary: 'Üretici, model, Android ID, IMEI',
          initiallyOpen: true,
          children: [
            InfoRow('Üretici', p.identity.manufacturer),
            InfoRow('Model', p.identity.model),
            InfoRow('Kod adı', p.identity.device),
            InfoRow('Ürün', p.identity.product),
            InfoRow('Donanım', p.identity.hardware),
            InfoRow('Anakart', p.identity.board),
            InfoRow(
              'Android ID',
              id == null ? null : (state.idRevealed ? id : maskId(id)),
              key: const Key('hardware_android_id'),
              trailing: id == null
                  ? null
                  : IconButton(
                      key: const Key('hardware_reveal_id'),
                      visualDensity: VisualDensity.compact,
                      tooltip: state.idRevealed ? 'Gizle' : 'Göster',
                      onPressed: cubit.toggleId,
                      icon: Icon(
                        state.idRevealed
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        size: 18,
                      ),
                    ),
            ),
            Text(
              'Android ID bu uygulamaya ve kullanıcıya özeldir; başka '
              'uygulama farklısını görür, fabrika ayarında değişir.',
              style: t.bodySmall,
            ),
            ImeiPanel(
              result: state.imei,
              busy: state.imeiBusy,
              onTry: cubit.tryImei,
            ),
          ],
        ),
        HardwareSection(
          id: 'system',
          icon: Icons.android_rounded,
          title: 'Sistem',
          summary: [
            if (p.system.release != null) 'Android ${p.system.release}',
            if (p.system.securityPatch != null)
              'yama ${p.system.securityPatch}',
          ].join(' · '),
          children: [
            InfoRow('Android', p.system.release),
            InfoRow('API düzeyi', p.system.sdk?.toString()),
            InfoRow('Güvenlik yaması', p.system.securityPatch),
            InfoRow('Derleme', p.system.build),
            InfoRow(
              'Derleme tarihi',
              p.system.buildTime == null
                  ? null
                  : formatDate(p.system.buildTime!),
            ),
            InfoRow('Çekirdek', p.system.kernel),
            InfoRow('Bootloader', p.system.bootloader),
            InfoRow('Açık kalma', formatUptime(p.system.uptime)),
            InfoRow('Dil', p.system.locale),
            InfoRow('Saat dilimi', p.system.timeZone),
            InfoRow('Parmak izi', p.system.fingerprint),
          ],
        ),
        HardwareSection(
          id: 'cpu',
          icon: Icons.memory_rounded,
          title: 'İşlemci, RAM, depolama',
          summary:
              '${p.cpu.cores} çekirdek · ${formatBytes(p.memory.total)} RAM',
          children: [
            InfoRow('Yonga', [?p.cpu.socMaker, ?p.cpu.socModel].join(' ')),
            InfoRow('Çekirdekler', formatClusters(p.cpu)),
            InfoRow('ABI', p.cpu.abis.join(', ')),
            const Gap(6),
            UsageBar(
              label: 'RAM',
              used: p.memory.total - p.memory.free,
              total: p.memory.total,
            ),
            UsageBar(
              label: 'Dahili depolama',
              used: p.storage.total - p.storage.free,
              total: p.storage.total,
            ),
            InfoRow(
              'Uygulama sınırı',
              p.memory.appLimitMb == null ? null : '${p.memory.appLimitMb} MB',
            ),
            InfoRow('Bellek az mı', p.memory.low ? 'Evet' : 'Hayır'),
          ],
        ),
        HardwareSection(
          id: 'battery',
          icon: Icons.battery_charging_full_rounded,
          title: 'Pil',
          summary: [
            if (b.percent != null) '%${b.percent}',
            batteryHealthLabel(b.health),
            if (b.temperature != null) '${formatDecimal(b.temperature!)} °C',
          ].join(' · '),
          children: [
            InfoRow('Doluluk', b.percent == null ? null : '%${b.percent}'),
            InfoRow('Durum', batteryStatusLabel(b.status)),
            InfoRow('Kaynak', plugLabel(b.source)),
            InfoRow('Sağlık', batteryHealthLabel(b.health)),
            InfoRow(
              'Sıcaklık',
              b.temperature == null
                  ? null
                  : '${formatDecimal(b.temperature!)} °C',
            ),
            InfoRow('Voltaj', b.voltageMv == null ? null : '${b.voltageMv} mV'),
            InfoRow(
              'Kalan şarj',
              b.chargeMah == null ? null : '${b.chargeMah} mAh',
            ),
            InfoRow('Şarj döngüsü', b.cycles?.toString() ?? 'Üretici vermiyor'),
            InfoRow('Kimya', b.technology),
          ],
        ),
        HardwareSection(
          id: 'display',
          icon: Icons.smartphone_rounded,
          title: 'Ekran',
          summary:
              '${screen.width} × ${screen.height}'
              '${inches == null ? '' : ' · ${formatDecimal(inches)}"'}'
              '${screen.refreshRate == null ? '' : ' · ${formatDecimal(screen.refreshRate!)} Hz'}',
          children: [
            InfoRow('Çözünürlük', '${screen.width} × ${screen.height} piksel'),
            InfoRow(
              'Köşegen',
              inches == null ? null : '${formatDecimal(inches)} inç (yaklaşık)',
            ),
            InfoRow(
              'Yoğunluk',
              [
                if (screen.dpi != null) '${screen.dpi} dpi sınıfı',
                if (screen.xdpi != null) '${screen.xdpi!.round()} ppi',
              ].join(' · '),
            ),
            InfoRow(
              'Yenileme',
              screen.refreshRates.isEmpty
                  ? null
                  : screen.refreshRates
                        .map((r) => '${formatDecimal(r)} Hz')
                        .join(', '),
            ),
            InfoRow('HDR', screen.hdr.isEmpty ? 'Yok' : screen.hdr.join(', ')),
            InfoRow(
              'Yazı ölçeği',
              screen.fontScale == null
                  ? null
                  : '× ${formatDecimal(screen.fontScale!, 2)}',
            ),
          ],
        ),
        HardwareSection(
          id: 'cameras',
          icon: Icons.photo_camera_rounded,
          title: 'Kameralar',
          summary: '${p.cameras.length} kamera',
          children: [
            for (final c in p.cameras)
              InfoRow(
                '${facingLabel(c.facing)} · #${c.id}',
                [
                  if (c.megapixels != null)
                    '${formatDecimal(c.megapixels!)} MP',
                  if (c.focalLengths.isNotEmpty)
                    '${c.focalLengths.map(formatDecimal).join('/')} mm',
                  if (c.stabilized) 'OIS',
                  if (c.flash) 'flaş',
                ].join(' · '),
              ),
            Text(
              'Arka kameralar çoğu telefonda tek bir "mantıksal" kamera '
              'altında birleşir; uygulamaya hepsi ayrı görünmeyebilir.',
              style: t.bodySmall,
            ),
          ],
        ),
        HardwareSection(
          id: 'sensors',
          icon: Icons.explore_rounded,
          title: 'Sensörler',
          summary: '${p.sensors.length} sensör',
          children: [
            for (final s in p.sensors)
              InfoRow(
                s.shortType.isEmpty ? '?' : s.shortType,
                [
                  s.name,
                  ?s.vendor,
                  if (s.powerMa != null) '${formatDecimal(s.powerMa!, 2)} mA',
                ].join(' · '),
              ),
          ],
        ),
        HardwareSection(
          id: 'features',
          icon: Icons.checklist_rounded,
          title: 'Donanım özellikleri',
          summary:
              '${p.features.values.where((v) => v).length} / '
              '${p.features.length} var',
          children: [FeatureChips(features: p.features)],
        ),
        HardwareSection(
          id: 'phone',
          icon: Icons.sim_card_rounded,
          title: 'SIM ve mobil ağ',
          summary: [?phone.operatorName, ?phone.network].join(' · '),
          children: [
            if (!phone.present)
              const InfoRow('Telefon', 'Bu cihazda yok')
            else ...[
              InfoRow('Şebeke', phone.operatorName),
              InfoRow('SIM operatörü', phone.simOperator),
              InfoRow('SIM ülkesi', phone.simCountry),
              InfoRow('Şebeke ülkesi', phone.networkCountry),
              InfoRow('Dolaşım', phone.roaming ? 'Evet' : 'Hayır'),
              InfoRow('SIM yuvası', phone.slots?.toString()),
              InfoRow('Tür', phone.phoneType),
              if (phone.granted) ...[
                InfoRow('Etkin SIM', phone.activeSims?.toString()),
                InfoRow('Veri ağı', phone.network),
              ] else ...[
                const Gap(6),
                Text(
                  'Veri ağı türü (5G/4G) ve etkin SIM sayısı için telefon '
                  'izni gerekir.',
                  style: t.bodySmall,
                ),
                const Gap(8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.tonalIcon(
                    key: const Key('hardware_phone_allow'),
                    onPressed: cubit.requestPhoneAccess,
                    icon: const Icon(Icons.lock_open_rounded, size: 18),
                    label: const Text('İzin ver'),
                  ),
                ),
              ],
            ],
          ],
        ),
      ],
    );
  }
}
