import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ders/app/core/analytics/app_events.dart';
import 'package:flutter_ders/app/core/di/injection.dart';
import 'package:flutter_ders/app/helper/network_checker.dart';
import 'package:flutter_ders/app/views/view_network/widgets/network_cards.dart';
import 'package:flutter_ders/app/views/view_network/widgets/socket_section.dart';
import 'package:flutter_ders/app/widgets/common.dart';

/// Son kontrolleri biriktirir: her yeni sonuçta son [max] sonucu yayar.
Stream<List<NetworkResult>> _history(
  Stream<NetworkResult> source, {
  int max = 6,
}) async* {
  final list = <NetworkResult>[];
  await for (final r in source) {
    list.insert(0, r);
    if (list.length > max) list.removeLast();
    yield [...list];
  }
}

/// DERS 11 — Ağ kontrolü: FutureBuilder, StreamBuilder ve sahte soket.
@RoutePage()
class NetworkView extends StatefulWidget {
  /// Sayfayı oluşturur.
  const NetworkView({super.key});

  @override
  State<NetworkView> createState() => _NetworkViewState();
}

class _NetworkViewState extends State<NetworkView> {
  final NetworkChecker _checker = getIt<NetworkChecker>();

  /// FutureBuilder'a verilen iş. build içinde DEĞİL burada oluşturulur;
  /// yoksa her yeniden çizimde yeni bir kontrol başlardı.
  late Future<NetworkResult> _future = _checker.check();

  /// StreamBuilder'a verilen akış; aynı sebeple bir kez oluşturulur.
  late final Stream<List<NetworkResult>> _stream = _history(
    _checker.watch(every: const Duration(seconds: 3)),
  );

  void _recheck() {
    // setState içindeki fonksiyon bir şey DÖNDÜRMEMELİ (=> ile atama
    // Future döndürürdü); bu yüzden süslü parantezli gövde.
    setState(() {
      _future = _checker.check();
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ağ kontrolü'),
        titleTextStyle: t.titleLarge,
      ),
      // ListView.builder gibi tembel listeler ekrandan çıkan kartı yok eder;
      // yeniden kurulan StreamBuilder aynı akışı ikinci kez dinleyemez ve
      // soket kapanır. Bu sayfa kısa, hepsi bir kez kurulsun.
      body: SingleChildScrollView(
        key: const Key('network_list'),
        padding: pagePadding(context).copyWith(top: 8, bottom: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader(
              eyebrow: 'Ders 11',
              title: 'Future tek cevap, Stream cevap akışı',
              body:
                  'İnternet kontrolü bir kez sorulup bir kez cevaplanırsa '
                  'Future; durum değiştikçe haber verilirse Stream olur. '
                  'Bağlantı koparsa her sayfanın üstünde uyarı (MaterialBanner) '
                  'çıkar.',
            ),
            const Gap(12),
            SectionCard(
              child: SwitchListTile(
                key: const Key('network_simulate'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Çevrimdışı gibi davran'),
                subtitle: const Text(
                  "Wi-Fi'yi kapatmadan banner'ı görmek için",
                ),
                value: _checker.simulateOffline,
                onChanged: (v) {
                  setState(() => _checker.simulateOffline = v);
                  _recheck();
                },
              ),
            ),
            const Gap(24),
            Text('1. FutureBuilder: bir kez sor', style: t.titleLarge),
            const Gap(8),
            const CodeBox('''
late Future<NetworkResult> _future = checker.check();

FutureBuilder(
  future: _future,
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) ...
    if (snapshot.hasError) ...
    return Text(snapshot.data!.online ? 'Var' : 'Yok');
  },
)'''),
            const Gap(10),
            SectionCard(
              child: FutureBuilder<NetworkResult>(
                key: const Key('network_future'),
                future: _future,
                builder: (context, snapshot) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ConnectionChip(
                      snapshot.connectionState,
                      key: const Key('network_futureState'),
                    ),
                    const Gap(12),
                    if (snapshot.connectionState == ConnectionState.waiting)
                      const LinearProgressIndicator()
                    else if (snapshot.hasError)
                      Text('Hata: ${snapshot.error}')
                    else if (snapshot.hasData)
                      NetworkResultRow(snapshot.data!),
                    const Gap(12),
                    FilledButton.tonalIcon(
                      key: const Key('network_recheck'),
                      onPressed:
                          snapshot.connectionState == ConnectionState.waiting
                          ? null
                          : () {
                              track(AppEvent.networkChecked);
                              _recheck();
                            },
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Tekrar kontrol et'),
                    ),
                  ],
                ),
              ),
            ),
            const Gap(24),
            Text('2. StreamBuilder: sürekli dinle', style: t.titleLarge),
            const Gap(8),
            const CodeBox('''
StreamBuilder(
  stream: checker.watch(every: 3 sn),
  builder: (context, snapshot) => ... snapshot.data ...,
)
// Her yeni değer geldiğinde builder yeniden çalışır.'''),
            const Gap(10),
            SectionCard(
              child: StreamBuilder<List<NetworkResult>>(
                key: const Key('network_stream'),
                stream: _stream,
                builder: (context, snapshot) {
                  final list = snapshot.data ?? const <NetworkResult>[];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ConnectionChip(snapshot.connectionState),
                      const Gap(6),
                      Text(
                        'Her 3 saniyede bir yeni değer gelir; son 6 kontrol:',
                        style: t.bodySmall,
                      ),
                      const Gap(10),
                      for (final r in list)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: NetworkResultRow(r),
                        ),
                    ],
                  );
                },
              ),
            ),
            const Gap(24),
            Text('3. StreamBuilder + WebSocket', style: t.titleLarge),
            const Gap(4),
            Text(
              'Telefonun içinde sahte bir WebSocket sunucusu açılır '
              '(kurulum yok, internet gerekmez). Sunucu her saniye sahte '
              'kur gönderir, yazdığınızı geri yollar.',
              style: t.bodyMedium,
            ),
            const Gap(10),
            const SocketSection(),
          ],
        ),
      ),
    );
  }
}
