import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_ders/app/core/di/injection.dart';
import 'package:flutter_ders/app/views/view_image_cache/cubit/image_cache_lab_cubit.dart';
import 'package:flutter_ders/app/views/view_image_cache/widgets/cache_panels.dart';
import 'package:flutter_ders/app/views/view_image_cache/widgets/source_gallery.dart';
import 'package:flutter_ders/app/widgets/common.dart';

// ─────────────────────────────────────────────────────────────────────────
// DERS 17 — Görsel önbelleği
//
//   Açılış (main.dart)  AppImageCache.ensureReady  → sürüm değiştiyse temizle
//                       ImageMemoryController.start → RAM'e göre bütçe, izleme
//   Ekran               CachedSourceImage (ImageProvider) → AppImageCache
//                       → disk → yoksa kaynak (base64 / S3 / SFTP)
// ─────────────────────────────────────────────────────────────────────────

/// Görsel önbelleği dersinin sayfası.
@RoutePage()
class ImageCacheView extends StatelessWidget {
  /// Sayfayı oluşturur.
  const ImageCacheView({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return BlocProvider(
      create: (_) => getIt<ImageCacheLabCubit>()..init(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Görsel önbelleği'),
          titleTextStyle: t.titleLarge,
        ),
        body: SingleChildScrollView(
          key: const Key('cache_scroll'),
          padding: pagePadding(context).copyWith(top: 16, bottom: 32),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SourceGallery(),
              Gap(20),
              VersionPanel(),
              MemoryPanel(),
              DiskPanel(),
            ],
          ),
        ),
      ),
    );
  }
}
