import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ders/app/core/repository/note_store.dart';
import 'package:flutter_ders/app/core/router/app_router.dart';
import 'package:flutter_ders/app/theme/app_theme.dart';
import 'package:flutter_ders/app/views/view_storage/widgets/storage_demo_screen.dart';
import 'package:flutter_ders/app/widgets/common.dart';

// ─────────────────────────────────────────────────────────────────────────
// DERS 10 — Yerel depolama
//
// Aynı kaydı (StorageNote) üç yolla saklıyoruz; her yol ayrı ekranda:
//   1. SharedPreferencesView → anahtar-değer (localStorage gibi)
//   2. HiveStorageView       → NoSQL, nesne temelli kutular (hive_ce)
//   3. SqfliteStorageView    → SQL tablo (SQLite)
// Üç ekran da StorageDemoScreen'i ve StorageDemoCubit'i paylaşır; fark
// yalnızca depodadır (NoteStore).
// ─────────────────────────────────────────────────────────────────────────

/// Üç yöntemi karşılaştıran ve ekranlarına götüren merkez sayfa.
@RoutePage()
class StorageHubView extends StatelessWidget {
  /// Sayfayı oluşturur.
  const StorageHubView({super.key});

  PageRouteInfo<void> _route(StorageKind kind) => switch (kind) {
    StorageKind.sharedPreferences => const SharedPreferencesRoute(),
    StorageKind.hive => const HiveStorageRoute(),
    StorageKind.sqflite => const SqfliteStorageRoute(),
  };

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Yerel depolama'),
        titleTextStyle: t.titleLarge,
      ),
      body: ListView(
        key: const Key('storageHub_list'),
        padding: pagePadding(context).copyWith(top: 8, bottom: 32),
        children: [
          const SectionHeader(
            eyebrow: 'Ders 10',
            title: 'Veriyi telefonda nerede saklayalım?',
            body:
                'Aynı kaydı üç farklı yolla saklayıp karşılaştırıyoruz. '
                'Her ekranda kayıt ekleyin, 1000 kayıtla hız ölçün ve verinin '
                'diskte nasıl durduğuna bakın.',
          ),
          const Gap(20),
          for (final (i, k) in StorageKind.values.indexed) ...[
            _KindCard(
              number: i + 1,
              kind: k,
              onTap: () => context.router.push(_route(k)),
            ),
            const Gap(10),
          ],
          const Gap(16),
          Text('Hangisi daha sağlıklı?', style: t.titleLarge),
          const Gap(10),
          const _Verdict(
            kind: StorageKind.sharedPreferences,
            when: 'Ayarlar, tercihler, "giriş yaptı mı?" gibi birkaç değer.',
            not:
                'Yüzlerce kayıtlık liste: her değişiklikte tüm metin '
                'yeniden yazılır.',
          ),
          const _Verdict(
            kind: StorageKind.hive,
            when:
                'Nesneleri hızlıca saklamak / okumak, çevrimdışı önbellek. '
                'Okuma senkron ve çok hızlı.',
            not:
                'Karmaşık sorgular (filtre, toplam, ilişki) kodda elle '
                'yapılır.',
          ),
          const _Verdict(
            kind: StorageKind.sqflite,
            when:
                'Çok sayıda kayıt; sıralama, filtre, toplam, ilişkili '
                'tablolar. Hocanın önerisi: kalıcı uygulama verisi için.',
            not:
                'Tek bir ayar için fazla: tablo, şema ve sürüm yönetimi '
                'gerekir.',
          ),
          const Gap(12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: MfColors.blue50,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              'Bu uygulamada: gerçek harcamalarınız şimdilik '
              'SharedPreferences\'ta JSON metni olarak duruyor (Ders 1). '
              'Kayıt sayısı büyüdükçe ve aylık toplam / kategori filtresi '
              'gerektikçe sqflite\'a geçmek daha sağlıklı olur; depo '
              'arayüzü sayesinde yalnızca depo sınıfı değişir.',
              style: t.bodyMedium?.copyWith(color: MfColors.blue700),
            ),
          ),
        ],
      ),
    );
  }
}

class _KindCard extends StatelessWidget {
  const _KindCard({
    required this.number,
    required this.kind,
    required this.onTap,
  });

  final int number;
  final StorageKind kind;
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
        key: Key('storageHub_${kind.name}'),
        borderRadius: radius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              IconBadge(kind.icon, accent: kind.color, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$number. ${kind.label}', style: t.titleMedium),
                    Text(kind.model, style: t.bodyMedium),
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

class _Verdict extends StatelessWidget {
  const _Verdict({required this.kind, required this.when, required this.not});

  final StorageKind kind;
  final String when;
  final String not;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(kind.icon, size: 18, color: kind.color),
              const SizedBox(width: 6),
              Text(kind.label, style: t.titleSmall),
            ],
          ),
          const SizedBox(height: 4),
          Text('✓ $when', style: t.bodyMedium),
          Text('✗ $not', style: t.bodyMedium),
        ],
      ),
    );
  }
}

/// 1. ekran: SharedPreferences.
@RoutePage()
class SharedPreferencesView extends StatelessWidget {
  /// Ekranı oluşturur.
  const SharedPreferencesView({super.key});

  @override
  Widget build(BuildContext context) =>
      const StorageDemoScreen(kind: StorageKind.sharedPreferences);
}

/// 2. ekran: Hive (hive_ce).
@RoutePage()
class HiveStorageView extends StatelessWidget {
  /// Ekranı oluşturur.
  const HiveStorageView({super.key});

  @override
  Widget build(BuildContext context) =>
      const StorageDemoScreen(kind: StorageKind.hive);
}

/// 3. ekran: sqflite.
@RoutePage()
class SqfliteStorageView extends StatelessWidget {
  /// Ekranı oluşturur.
  const SqfliteStorageView({super.key});

  @override
  Widget build(BuildContext context) =>
      const StorageDemoScreen(kind: StorageKind.sqflite);
}
