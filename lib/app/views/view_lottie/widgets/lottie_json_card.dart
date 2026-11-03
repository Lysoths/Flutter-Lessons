import 'package:flutter/material.dart';
import 'package:flutter_ders/app/models/lottie_item.dart';
import 'package:flutter_ders/app/models/lottie_json_info.dart';
import 'package:flutter_ders/app/theme/app_theme.dart';
import 'package:flutter_ders/app/widgets/common.dart';

/// DERS 9 — Seçili animasyonun JSON dosyasını açıp içini gösteren kart.
class LottieJsonCard extends StatelessWidget {
  /// [item] için kart oluşturur; [info] okunana kadar yükleniyor gösterir.
  const LottieJsonCard({required this.item, required this.info, super.key});

  /// Seçili animasyon.
  final LottieItem item;

  /// Okunmuş bilgiler (henüz yoksa `null`).
  final LottieJsonInfo? info;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final i = info;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MfColors.slate200),
      ),
      child: i == null
          ? const SizedBox(
              height: 120,
              child: Center(child: CircularProgressIndicator()),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.assetPath, style: t.labelMedium),
                const Gap(10),
                // Dosyanın ilk karakterleri: gerçekten düz bir JSON metni.
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: MfColors.terminal,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    i.preview,
                    key: const Key('lottieJson_preview'),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      height: 1.4,
                      color: Color(0xFFA5F3FC),
                    ),
                  ),
                ),
                const Gap(12),
                _Row('v', 'Bodymovin sürümü', i.version),
                _Row('fr', 'Saniyedeki kare', i.frameRate.toStringAsFixed(2)),
                _Row(
                  'ip → op',
                  'Başlangıç → bitiş karesi',
                  '${i.inPoint.round()} → ${i.outPoint.round()}',
                ),
                _Row(
                  '(op−ip)/fr',
                  'Süre',
                  '${(i.duration.inMilliseconds / 1000).toStringAsFixed(2)} sn',
                ),
                _Row('w × h', 'Tuval', '${i.width} × ${i.height}'),
                _Row(
                  'boyut',
                  'Dosya',
                  '${(i.byteSize / 1024).toStringAsFixed(1)} KB',
                ),
                _Row(
                  'layers',
                  'Katman sayısı',
                  '${i.layerNames.length}',
                  valueKey: const Key('lottieJson_layers'),
                ),
                const Gap(8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final name in i.layerNames.take(12))
                      Eyebrow(
                        name,
                        color: MfColors.slate600,
                        background: MfColors.slate100,
                      ),
                    if (i.layerNames.length > 12)
                      Eyebrow('+${i.layerNames.length - 12}'),
                  ],
                ),
              ],
            ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.jsonKey, this.label, this.value, {this.valueKey});

  final String jsonKey;
  final String label;
  final String value;
  final Key? valueKey;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Text(
              jsonKey,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: MfColors.blue700,
              ),
            ),
          ),
          Expanded(child: Text(label, style: t.bodyMedium)),
          Text(value, key: valueKey, style: t.titleSmall),
        ],
      ),
    );
  }
}
