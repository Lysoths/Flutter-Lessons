import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_ders/app/core/di/injection.dart';
import 'package:flutter_ders/app/core/repository/note_store.dart';
import 'package:flutter_ders/app/helper/money_format.dart';
import 'package:flutter_ders/app/theme/app_theme.dart';
import 'package:flutter_ders/app/views/view_storage/cubit/storage_demo_cubit.dart';
import 'package:flutter_ders/app/views/view_storage/cubit/storage_demo_state.dart';
import 'package:flutter_ders/app/widgets/common.dart';

/// Her yöntemin kısa anlatımı ve örnek kodu.
const _about = {
  StorageKind.sharedPreferences: (
    points: [
      'Tarayıcıdaki localStorage gibi: anahtar → basit değer.',
      'Liste saklamak için bütün liste JSON metnine çevrilip TEK anahtara yazılır.',
      'Bir kayıt değişince metnin tamamı yeniden yazılır → küçük veriler, ayarlar için.',
      'Okuma senkron (açılışta hepsi belleğe alınır), yazma async.',
    ],
    code: '''
final prefs = await SharedPreferences.getInstance();
await prefs.setString('ders10_notes', jsonEncode(liste));
final metin = prefs.getString('ders10_notes'); // sync''',
  ),
  StorageKind.hive: (
    points: [
      'NoSQL: tablo yok, kutuda anahtar → NESNE (MongoDB belgesi gibi).',
      'TypeAdapter nesneyi ikili biçime çevirir; JSON metni yok.',
      'Kutu açılınca içerik bellekte: box.get() senkron ve çok hızlı.',
      'hive_ce = topluluk sürümü; masterfabric_core da kullanır.',
    ],
    code: '''
Hive.registerAdapter(StorageNoteAdapter());
final box = await Hive.openBox<StorageNote>('ders10_notes');
await box.put(not.id, not);         // nesnenin kendisi
final StorageNote? n = box.get(id); // sync''',
  ),
  StorageKind.sqflite: (
    points: [
      'Klasik veritabanı (SQLite): tablo, sütun türleri, satırlar.',
      'Sıralama / filtre / toplam işini veritabanı yapar (ORDER BY, WHERE, SUM).',
      'Çok sayıda kayıt ve ilişkili veri için en sağlıklısı (hocanın önerisi).',
      'Her işlem diske SQL: hepsi async.',
    ],
    code: '''
final db = await openDatabase('ders10.db', version: 1,
    onCreate: (db, _) => db.execute('CREATE TABLE notes (...)'));
await db.insert('notes', not.toMap());
final satirlar = await db.query('notes', orderBy: 'created_at DESC');''',
  ),
};

/// DERS 10 — Üç depolama ekranının ortak gövdesi; [kind] hangi depoyla
/// çalışacağını seçer.
class StorageDemoScreen extends StatelessWidget {
  /// [kind] için ekranı oluşturur.
  const StorageDemoScreen({required this.kind, super.key});

  /// Depolama yöntemi.
  final StorageKind kind;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<StorageDemoCubit>(
      create: (_) => getIt<StorageDemoCubit>(param1: kind)..load(),
      child: _StorageBody(kind: kind),
    );
  }
}

class _StorageBody extends StatelessWidget {
  const _StorageBody({required this.kind});

  final StorageKind kind;

  /// Listede en fazla kaç kayıt gösterilir.
  static const _shown = 30;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final about = _about[kind]!;
    return Scaffold(
      appBar: AppBar(title: Text(kind.label), titleTextStyle: t.titleLarge),
      body: BlocBuilder<StorageDemoCubit, StorageDemoState>(
        builder: (context, state) {
          final cubit = context.read<StorageDemoCubit>();
          final busy =
              state.status == StorageDemoStatus.loading ||
              state.status == StorageDemoStatus.benchmarking;
          final b = state.benchmark;
          return ListView(
            key: Key('storage_list_${kind.name}'),
            padding: pagePadding(context).copyWith(top: 8, bottom: 32),
            children: [
              Row(
                children: [
                  IconBadge(kind.icon, accent: kind.color, size: 48),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(kind.label, style: t.titleLarge),
                        Text(kind.model, style: t.bodyMedium),
                      ],
                    ),
                  ),
                ],
              ),
              const Gap(14),
              for (final p in about.points)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 7, right: 8),
                        child: Icon(Icons.circle, size: 6, color: kind.color),
                      ),
                      Expanded(child: Text(p, style: t.bodyMedium)),
                    ],
                  ),
                ),
              const Gap(8),
              _CodeBox(about.code),
              const Gap(20),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    key: const Key('storage_add'),
                    onPressed: busy ? null : cubit.addSample,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 44),
                    ),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Kayıt ekle'),
                  ),
                  OutlinedButton.icon(
                    key: const Key('storage_benchmark'),
                    onPressed: busy ? null : cubit.benchmark,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                    ),
                    icon: const Icon(Icons.speed_rounded),
                    label: const Text('1000 kayıt yaz / oku'),
                  ),
                  TextButton.icon(
                    key: const Key('storage_clear'),
                    onPressed: busy ? null : cubit.clear,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      foregroundColor: MfColors.red600,
                    ),
                    icon: const Icon(Icons.delete_sweep_rounded),
                    label: const Text('Hepsini sil'),
                  ),
                ],
              ),
              const Gap(10),
              if (state.status == StorageDemoStatus.benchmarking)
                const LinearProgressIndicator(),
              if (b != null)
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    Eyebrow(
                      '${b.count} kayıt',
                      key: const Key('storage_benchmarkCount'),
                    ),
                    Eyebrow(
                      'yazma ${b.write.inMilliseconds} ms',
                      color: MfColors.slate600,
                      background: MfColors.slate100,
                    ),
                    Eyebrow(
                      'okuma ${b.read.inMilliseconds} ms',
                      color: MfColors.slate600,
                      background: MfColors.slate100,
                    ),
                  ],
                ),
              if (state.error != null) ...[
                const Gap(8),
                Text(
                  state.error!,
                  style: t.bodyMedium?.copyWith(color: MfColors.red600),
                ),
              ],
              const Gap(20),
              Text('Ham veri: diskte nasıl duruyor?', style: t.titleMedium),
              const Gap(8),
              _CodeBox(
                state.raw.isEmpty ? '…' : state.raw,
                key: const Key('storage_raw'),
              ),
              const Gap(20),
              Text(
                'Kayıtlar (${state.notes.length})',
                key: const Key('storage_count'),
                style: t.titleMedium,
              ),
              const Gap(8),
              if (state.notes.isEmpty && !busy)
                Text(
                  'Henüz kayıt yok. "Kayıt ekle"ye dokunun.',
                  style: t.bodyMedium,
                ),
              for (final n in state.notes.take(_shown))
                Card(
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    dense: true,
                    title: Text(n.title),
                    subtitle: Text(
                      '${formatDate(n.createdAt)} '
                      '${n.createdAt.hour.toString().padLeft(2, '0')}:'
                      '${n.createdAt.minute.toString().padLeft(2, '0')}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(formatMoney(n.amount), style: t.titleSmall),
                        IconButton(
                          tooltip: 'Sil',
                          onPressed: busy ? null : () => cubit.delete(n.id),
                          icon: const Icon(Icons.close_rounded, size: 18),
                        ),
                      ],
                    ),
                  ),
                ),
              if (state.notes.length > _shown)
                Text(
                  '+${state.notes.length - _shown} kayıt daha',
                  style: t.bodyMedium,
                ),
            ],
          );
        },
      ),
    );
  }
}

class _CodeBox extends StatelessWidget {
  const _CodeBox(this.code, {super.key});

  final String code;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MfColors.terminal,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        code,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 11.5,
          height: 1.45,
          color: Color(0xFFA5F3FC),
        ),
      ),
    );
  }
}
