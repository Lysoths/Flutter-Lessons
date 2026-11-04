import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_ders/app/core/device/location_source.dart';
import 'package:flutter_ders/app/core/repository/network_info_repository.dart';
import 'package:flutter_ders/app/helper/measure_format.dart';
import 'package:flutter_ders/app/theme/app_theme.dart';
import 'package:flutter_ders/app/views/view_app_network/bloc/network_info_bloc.dart';
import 'package:flutter_ders/app/views/view_app_network/bloc/network_info_event.dart';
import 'package:flutter_ders/app/views/view_app_network/bloc/network_info_state.dart';
import 'package:flutter_ders/app/views/view_network/widgets/network_cards.dart';
import 'package:flutter_ders/app/widgets/common.dart';
import 'package:flutter_ders/app/widgets/info_section_card.dart';

/// DERS 14 — Ağ sekmesi.
class NetworkInfoTab extends StatelessWidget {
  /// Sekmeyi oluşturur.
  const NetworkInfoTab({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final bloc = context.read<NetworkInfoBloc>();
    return SingleChildScrollView(
      key: const Key('network_info_list'),
      padding: pagePadding(context).copyWith(top: 16, bottom: 32),
      child: BlocBuilder<NetworkInfoBloc, NetworkInfoState>(
        builder: (context, state) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Telefon internete hangi adresten çıktığını bilemez; '
              'Cloudflare\'e sorar. IP\'ler gizli başlar, dokununca görünür.',
              style: t.bodyMedium,
            ),
            const Gap(12),
            const CodeBox('''
GET https://1.1.1.1/cdn-cgi/trace   (dio, düz metin)
→ ip=…  loc=TR  colo=IST  tls=TLSv1.3  http=http/1.1

on<NetworkInfoRefreshed>(_, transformer: droppable());
on<NetworkConnectivityChanged>(_, transformer: restartable());'''),
            const Gap(12),
            Row(
              children: [
                FilledButton.icon(
                  key: const Key('network_info_refresh'),
                  onPressed: () => bloc.add(const NetworkInfoRefreshed()),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Yenile'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'İstek: ${state.traceCount} · '
                    'bağlantı değişimi: ${state.connectionChanges}\n'
                    'Wi-Fi\'yi kapatıp açınca kendiliğinden yenilenir.',
                    key: const Key('network_info_counts'),
                    style: t.bodySmall,
                  ),
                ),
              ],
            ),
            const Gap(12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final c in state.connection)
                  Eyebrow(
                    connectivityLabel(c),
                    color: MfColors.emerald500,
                    background: MfColors.emerald500.withValues(alpha: 0.1),
                  ),
              ],
            ),
            const Gap(12),
            _TracePart(state),
            if (state.localStatus == PartStatus.loading &&
                state.localSections.isEmpty)
              const LinearProgressIndicator(),
            if (state.localStatus == PartStatus.failure)
              const Text('Cihaz içi ağ bilgisi okunamadı.'),
            // Wi-Fi'deyken ad gelmediyse sebep konum iznidir.
            if (state.connection.contains(ConnectivityResult.wifi) &&
                state.localStatus == PartStatus.ready &&
                state.wifiNameMissing)
              _WifiAccessCard(state.wifiAccess),
            for (final s in state.localSections) InfoSectionCard(s),
          ],
        ),
      ),
    );
  }
}

class _TracePart extends StatelessWidget {
  const _TracePart(this.state);

  final NetworkInfoState state;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final trace = state.trace;
    final loading = state.traceStatus == PartStatus.loading;
    String two(int n) => n.toString().padLeft(2, '0');
    final at = state.traceAt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (loading) const LinearProgressIndicator(key: Key('trace_loading')),
        if (state.traceError case final message?)
          Container(
            key: const Key('trace_error'),
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.cloud_off_rounded, color: MfColors.red600),
                const SizedBox(width: 10),
                Expanded(child: Text(message, style: t.titleSmall)),
              ],
            ),
          ),
        if (state.traceLatency case final latency? when at != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Gidiş-dönüş ${formatDuration(latency)} · '
              '${two(at.hour)}:${two(at.minute)}:${two(at.second)}',
              key: const Key('trace_latency'),
              style: t.bodySmall,
            ),
          ),
        if (trace != null)
          Opacity(
            opacity: loading ? 0.4 : 1,
            child: Column(
              children: [
                for (final s in trace.toSections()) InfoSectionCard(s),
              ],
            ),
          ),
      ],
    );
  }
}

class _WifiAccessCard extends StatelessWidget {
  const _WifiAccessCard(this.access);

  final LocationAccess? access;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      key: const Key('wifi_access'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MfColors.blue50,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on_rounded, color: MfColors.blue700),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Android, Wi-Fi adını (SSID) ve BSSID\'yi yalnızca konum izni '
              'olan uygulamalara verir.'
              '${access == null ? '' : '\nDurum: ${access!.label}'}',
              style: t.bodySmall,
            ),
          ),
          TextButton(
            key: const Key('wifi_access_button'),
            onPressed: () => context.read<NetworkInfoBloc>().add(
              const NetworkWifiAccessRequested(),
            ),
            child: const Text('İzin ver'),
          ),
        ],
      ),
    );
  }
}
