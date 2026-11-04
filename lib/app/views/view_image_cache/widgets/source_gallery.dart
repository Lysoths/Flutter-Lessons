import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_ders/app/core/cache/app_image_cache.dart';
import 'package:flutter_ders/app/core/cache/image_source.dart';
import 'package:flutter_ders/app/helper/measure_format.dart';
import 'package:flutter_ders/app/models/image_demo_sources.dart';
import 'package:flutter_ders/app/theme/app_theme.dart';
import 'package:flutter_ders/app/views/view_image_cache/cubit/image_cache_lab_cubit.dart';
import 'package:flutter_ders/app/views/view_image_cache/cubit/image_cache_lab_state.dart';
import 'package:flutter_ders/app/views/view_network/widgets/network_cards.dart';
import 'package:flutter_ders/app/widgets/common.dart';

/// DERS 17 — Kaynak sekmeleri ve görsel ızgarası.
class SourceGallery extends StatelessWidget {
  /// Bölüm oluşturur.
  const SourceGallery({super.key});

  static const _code = {
    ImageSourceKind.base64: '''
// API cevabı: {"veri": "data:image/png;base64,iVBORw0..."}
Base64ImageSource(json['veri'], name: json['ad'])
// → base64Decode → disk önbelleği (aynı metin bir daha çözülmez)''',
    ImageSourceKind.s3: '''
// Herkese açık S3 kovası (AWS Open Data)
NetworkImageSource(
  'https://elevation-tiles-prod.s3.amazonaws.com/terrarium/2/2/1.png')
// dio (bytes) → content-length denetimi → disk''',
    ImageSourceKind.sftp: '''
// SFTP: SSH üzerinden, şifreli, tek port (22)
SSHSocket.connect('test.rebex.net', 22)
SSHClient(onVerifyHostKey: anahtar sabitlenmiş listede mi?)
client.sftp() → open('/pub/example/KeyGenerator.png') → read()''',
  };

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final state = context.watch<ImageCacheLabCubit>().state;
    final cubit = context.read<ImageCacheLabCubit>();
    final loading = state.sources.any(
      (s) => state.items[s.key]?.phase == ItemPhase.loading,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<ImageSourceKind>(
          key: const Key('cache_kind'),
          segments: [
            for (final k in ImageSourceKind.values)
              ButtonSegment(
                value: k,
                label: Text(k.label, key: Key('kind_${k.name}')),
              ),
          ],
          selected: {state.kind},
          showSelectedIcon: false,
          onSelectionChanged: (s) => cubit.showKind(s.first),
        ),
        const Gap(8),
        Text(state.kind.description, style: t.bodySmall),
        const Gap(8),
        CodeBox(_code[state.kind]!),
        const Gap(10),
        FilledButton.icon(
          key: const Key('cache_precache'),
          onPressed: loading || !state.ready ? null : cubit.precacheAll,
          style: FilledButton.styleFrom(minimumSize: const Size(0, 46)),
          icon: loading
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.download_for_offline_rounded),
          label: Text(
            'Önceden yükle (precache) · ${state.sources.length} görsel',
          ),
        ),
        if (state.message case final m?) ...[
          const Gap(8),
          Text(
            m,
            key: const Key('cache_message'),
            style: t.bodySmall?.copyWith(color: MfColors.blue700),
          ),
        ],
        const Gap(12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 180,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.82,
          ),
          itemCount: state.sources.length,
          itemBuilder: (context, i) {
            final s = state.sources[i];
            return _Tile(
              key: ValueKey('${s.key}-${state.revision}'),
              source: s,
              status: state.items[s.key],
            );
          },
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.source, required this.status, super.key});

  final CachedImageSource source;
  final ItemStatus? status;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final provider = context.read<ImageCacheLabCubit>().providerFor(source);
    final s = status;
    final origin = s?.origin;
    final took = s?.took;
    return Container(
      key: Key('tile_${source.label}'),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MfColors.slate200),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ColoredBox(
              color: MfColors.slate100,
              // Görsel önceden yüklenmeden çizilmez: precache'in farkı
              // görünsün (yüklenince beklemeden, tek karede gelir).
              child: s?.phase != ItemPhase.ready
                  ? Center(
                      child: s?.phase == ItemPhase.loading
                          ? CircularProgressIndicator(value: s?.progress)
                          : s?.phase == ItemPhase.failed
                          ? Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text(
                                s?.error ?? 'Hata',
                                textAlign: TextAlign.center,
                                style: t.bodySmall?.copyWith(
                                  color: MfColors.red600,
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.image_outlined,
                              color: MfColors.slate400,
                            ),
                    )
                  : Image(
                      image: provider,
                      fit: BoxFit.cover,
                      // Yeni görsel gelene kadar eskisi ekranda kalır (boş kare yok).
                      gaplessPlayback: true,
                      frameBuilder: (context, child, frame, sync) => sync
                          ? child
                          : AnimatedOpacity(
                              opacity: frame == null ? 0 : 1,
                              duration: const Duration(milliseconds: 250),
                              child: child,
                            ),
                      loadingBuilder: (context, child, progress) =>
                          progress == null
                          ? child
                          : Center(
                              child: CircularProgressIndicator(
                                value: progress.expectedTotalBytes == null
                                    ? null
                                    : progress.cumulativeBytesLoaded /
                                          progress.expectedTotalBytes!,
                              ),
                            ),
                      errorBuilder: (context, error, _) => Padding(
                        padding: const EdgeInsets.all(8),
                        child: Center(
                          child: Text(
                            '$error',
                            textAlign: TextAlign.center,
                            style: t.bodySmall?.copyWith(
                              color: MfColors.red600,
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          ),
          if (s?.phase == ItemPhase.loading)
            LinearProgressIndicator(value: s?.progress, minHeight: 3),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  source.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.labelMedium,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Flexible(
                      child: origin != null
                          ? Eyebrow(
                              origin.label,
                              color: _originColor(origin),
                              background: _originColor(origin)
                                  .withValues(alpha: 0.1),
                            )
                          : Text(
                              s?.phase == ItemPhase.failed
                                  ? 'Hata'
                                  : 'Bekliyor',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: t.labelSmall?.copyWith(
                                color: MfColors.slate400,
                              ),
                            ),
                    ),
                    const Spacer(),
                    if (took != null)
                      Text(formatDuration(took), style: t.labelSmall),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Color _originColor(CacheOrigin o) => switch (o) {
    CacheOrigin.memory => MfColors.emerald500,
    CacheOrigin.disk => MfColors.blue600,
    CacheOrigin.source => const Color(0xFFF59E0B),
  };
}
