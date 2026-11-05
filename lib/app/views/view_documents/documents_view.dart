import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ders/app/core/analytics/app_events.dart';
import 'package:flutter_ders/app/core/router/app_router.dart';
import 'package:flutter_ders/app/models/document_item.dart';
import 'package:flutter_ders/app/theme/app_theme.dart';
import 'package:flutter_ders/app/widgets/common.dart';

// ─────────────────────────────────────────────────────────────────────────
// DERS 5 — Assets + auto_route
//
// Belgeler listesi '/belgeler' rotasıdır (deep link ile de açılır).
// Bir belgeye dokununca türüne göre ayrı bir görüntüleyici rotası açılır;
// belge NESNE olarak gider, bu yüzden görüntüleyiciler dışarıdan
// linkle açılamaz:
//
//   görsel → ImageViewerRoute(document: d)
//   PDF    → PdfViewerRoute(document: d)
//   ses    → AudioPlayerRoute(document: d)
// ─────────────────────────────────────────────────────────────────────────

/// Uygulamaya gömülü belgelerin listesi.
@RoutePage()
class DocumentsView extends StatelessWidget {
  /// Listeyi oluşturur.
  const DocumentsView({super.key});

  /// Belgenin türüne uygun görüntüleyici rotasını seçer.
  PageRouteInfo<void> _routeFor(DocumentItem document) =>
      switch (document.kind) {
        DocumentKind.image => ImageViewerRoute(document: document),
        DocumentKind.pdf => PdfViewerRoute(document: document),
        DocumentKind.audio => AudioPlayerRoute(document: document),
      };

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Belgeler'),
        titleTextStyle: t.titleLarge,
      ),
      body: ListView(
        padding: pagePadding(context).copyWith(top: 8, bottom: 24),
        children: [
          for (final kind in DocumentKind.values) ...[
            const Gap(12),
            Row(
              children: [
                Icon(kind.icon, size: 18, color: _accent(kind)),
                const SizedBox(width: 8),
                Text(kind.label.toUpperCase(), style: t.labelMedium),
              ],
            ),
            const Gap(8),
            for (final d in kDocuments.where((d) => d.kind == kind))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _DocumentTile(
                  document: d,
                  accent: _accent(kind),
                  onTap: () {
                    track(AppEvent.documentOpened, d.kind.name);
                    context.router.push(_routeFor(d));
                  },
                ),
              ),
          ],
          const Gap(12),
          Text(
            'Tüm dosyalar Wikimedia Commons\'tan alınmıştır ve kamu malıdır.',
            style: t.bodySmall?.copyWith(color: MfColors.slate500),
          ),
        ],
      ),
    );
  }

  static Color _accent(DocumentKind kind) => switch (kind) {
    DocumentKind.image => MfColors.emerald500,
    DocumentKind.pdf => MfColors.red600,
    DocumentKind.audio => const Color(0xFF8B5CF6),
  };
}

class _DocumentTile extends StatelessWidget {
  const _DocumentTile({
    required this.document,
    required this.accent,
    required this.onTap,
  });

  final DocumentItem document;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(16);
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: const BorderSide(color: MfColors.slate200),
      ),
      child: InkWell(
        key: Key('documentTile_${document.assetPath}'),
        borderRadius: radius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
          child: Row(
            children: [
              IconBadge(document.kind.icon, accent: accent, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(document.title, style: t.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      document.description,
                      style: t.bodyMedium?.copyWith(fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: MfColors.slate400),
            ],
          ),
        ),
      ),
    );
  }
}
