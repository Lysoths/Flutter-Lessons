import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ders/app/core/analytics/app_events.dart';
import 'package:flutter_ders/app/models/lottie_item.dart';
import 'package:flutter_ders/app/models/lottie_json_info.dart';
import 'package:flutter_ders/app/theme/app_theme.dart';
import 'package:flutter_ders/app/views/view_lottie/widgets/lottie_json_card.dart';
import 'package:flutter_ders/app/views/view_lottie/widgets/lottie_player_card.dart';
import 'package:flutter_ders/app/widgets/common.dart';
import 'package:lottie/lottie.dart';

// ─────────────────────────────────────────────────────────────────────────
// DERS 9 — Lottie: JSON'dan animasyon
//
// 1. Tasarımcı animasyonu After Effects'te vektörlerle çizer.
// 2. Bodymovin eklentisi onu bir JSON dosyasına aktarır: katmanlar,
//    şekiller ve "şu karede şu değer" listeleri (keyframe).
// 3. Uygulama JSON'u okur (Lottie.asset), her karede o anki değerleri
//    hesaplayıp şekilleri Canvas'a çizer. Video değil, VERİDİR:
//    küçük, her boyutta net, rengi çalışırken değiştirilebilir.
//
// Dosyalar: assets/lottie/*.json (LottieFiles, Lottie Simple License).
// ─────────────────────────────────────────────────────────────────────────

/// Lottie animasyonlarını JSON'dan oynatan ve mantığını anlatan sayfa.
@RoutePage()
class LottieView extends StatefulWidget {
  /// Sayfayı oluşturur.
  const LottieView({super.key});

  @override
  State<LottieView> createState() => _LottieViewState();
}

class _LottieViewState extends State<LottieView> {
  LottieItem _selected = kLottieAnimations.first;

  /// Okunmuş JSON bilgileri; her dosya bir kez okunur.
  final Map<String, LottieJsonInfo> _infos = {};

  @override
  void initState() {
    super.initState();
    _loadInfo(_selected);
  }

  Future<void> _loadInfo(LottieItem item) async {
    if (_infos.containsKey(item.id)) return;
    final info = await LottieJsonInfo.load(item.assetPath);
    if (!mounted) return;
    setState(() => _infos[item.id] = info);
  }

  void _select(LottieItem item) {
    setState(() => _selected = item);
    _loadInfo(item);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lottie animasyonları'),
        titleTextStyle: t.titleLarge,
      ),
      body: ListView(
        key: const Key('lottie_list'),
        padding: pagePadding(context).copyWith(top: 8, bottom: 32),
        children: [
          const SectionHeader(
            eyebrow: 'Ders 9',
            title: 'Animasyon = JSON',
            body:
                'Lottie animasyonu bir video değil, bir JSON dosyasıdır. '
                'Uygulama dosyayı okur ve her karede şekilleri yeniden çizer.',
          ),
          const Gap(16),
          const _Flow(),
          const Gap(16),
          const _Compare(),
          const Gap(28),
          Text('1. Animasyonu seç', style: t.titleLarge),
          const Gap(10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final a in kLottieAnimations)
                ChoiceChip(
                  key: Key('lottieChip_${a.id}'),
                  label: Text(a.title),
                  selected: a == _selected,
                  onSelected: (_) {
                    track(AppEvent.lottieSelected, a.id);
                    _select(a);
                  },
                ),
            ],
          ),
          const Gap(6),
          Text(_selected.useCase, style: t.bodyMedium),
          const Gap(20),
          Text('2. JSON\'dan çiz ve kontrol et', style: t.titleLarge),
          const Gap(4),
          Text(
            'Lottie.asset(dosya, controller: ...) — Ders 8\'deki '
            'AnimationController burada da saattir.',
            style: t.bodyMedium,
          ),
          const Gap(10),
          LottiePlayerCard(key: ValueKey(_selected.id), item: _selected),
          const Gap(20),
          Text('3. Dosyanın içi', style: t.titleLarge),
          const Gap(4),
          Text(
            'rootBundle.loadString → jsonDecode: Ders 7\'deki örnek '
            'harcamalarla aynı okuma.',
            style: t.bodyMedium,
          ),
          const Gap(10),
          LottieJsonCard(item: _selected, info: _infos[_selected.id]),
          const Gap(28),
          Text('Hepsi birlikte', style: t.titleLarge),
          const Gap(4),
          Text(
            'controller verilmezse Lottie kendi saatini kurar ve sürekli '
            'tekrar eder (repeat: true).',
            style: t.bodyMedium,
          ),
          const Gap(10),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: [
              for (final a in kLottieAnimations)
                Container(
                  key: Key('lottieGallery_${a.id}'),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: MfColors.slate200),
                  ),
                  child: Lottie.asset(a.assetPath, fit: BoxFit.contain),
                ),
            ],
          ),
          const Gap(20),
          Text(
            'Kaynak: lottiefiles.com/free-animations · Lottie Simple License',
            style: t.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// Tasarımcıdan ekrana üç adım.
class _Flow extends StatelessWidget {
  const _Flow();

  @override
  Widget build(BuildContext context) {
    const steps = [
      (Icons.brush_rounded, 'After Effects', 'Tasarımcı vektörle çizer'),
      (Icons.data_object_rounded, 'Bodymovin → JSON', 'Katmanlar ve kareler'),
      (Icons.phone_android_rounded, 'Lottie.asset', 'Her karede yeniden çizer'),
    ];
    final t = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, s) in steps.indexed) ...[
          if (i > 0)
            const Padding(
              padding: EdgeInsets.only(top: 14),
              child: Icon(
                Icons.arrow_forward_rounded,
                color: MfColors.slate400,
              ),
            ),
          Expanded(
            child: Column(
              children: [
                IconBadge(s.$1, size: 44),
                const Gap(8),
                Text(s.$2, textAlign: TextAlign.center, style: t.titleSmall),
                const SizedBox(height: 2),
                Text(s.$3, textAlign: TextAlign.center, style: t.bodySmall),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// GIF/video ile Lottie karşılaştırması.
class _Compare extends StatelessWidget {
  const _Compare();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    const rows = [
      ('Ne saklanır', 'Her karenin pikselleri', 'Şekiller + değerler (JSON)'),
      ('Boyut', 'Yüzlerce KB – MB', 'Birkaç KB'),
      ('Büyütünce', 'Bulanıklaşır', 'Hep net (vektör)'),
      ('Kontrol', 'Oynat / durdur', 'İstenen kare, hız, renk'),
    ];
    Widget cell(String s, {bool head = false, Color? color}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Text(
        s,
        style: (head ? t.titleSmall : t.bodyMedium)?.copyWith(color: color),
      ),
    );
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MfColors.slate50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MfColors.slate200),
      ),
      child: Table(
        columnWidths: const {0: FlexColumnWidth(0.9)},
        children: [
          TableRow(
            children: [
              cell('', head: true),
              cell('GIF / video', head: true),
              cell('Lottie', head: true, color: MfColors.blue700),
            ],
          ),
          for (final r in rows)
            TableRow(
              children: [
                cell(r.$1, head: true),
                cell(r.$2),
                cell(r.$3, color: MfColors.slate900),
              ],
            ),
        ],
      ),
    );
  }
}
