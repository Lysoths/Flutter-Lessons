import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_ders/app/core/di/injection.dart';
import 'package:flutter_ders/app/core/repository/note_store.dart';
import 'package:flutter_ders/app/helper/measure_format.dart';
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
              Row(
                children: [
                  Text('Ölçüm boyutu', style: t.titleSmall),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SegmentedButton<int>(
                      key: const Key('storage_benchmarkSize'),
                      segments: const [
                        ButtonSegment(value: 1000, label: Text('1.000')),
                        ButtonSegment(value: 5000, label: Text('5.000')),
                      ],
                      selected: {state.benchmarkSize},
                      onSelectionChanged: busy
                          ? null
                          : (s) => cubit.setBenchmarkSize(s.first),
                    ),
                  ),
                ],
              ),
              const Gap(10),
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
                    label: Text('${state.benchmarkSize} kayıt yaz / oku'),
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
              if (b != null) _BenchmarkCard(b),
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

/// DERS 10 — Ölçümün adım adım ayrıntısı.
///
/// Toplam süre tek başına yanıltır: SharedPreferences ve Hive'da okuma
/// bellekten yapılır, 1 ms'nin altında kalır. Diske gerçekten gidildiğinde
/// ne kadar sürdüğü ayrı satırda görünür.
class _BenchmarkCard extends StatelessWidget {
  const _BenchmarkCard(this.result);

  final StorageBenchmark result;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final r = result;
    Duration total(bool write) => r.steps
        .where((s) => s.isWrite == write)
        .fold(Duration.zero, (sum, s) => sum + s.time);
    final writeTotal = total(true);
    final readTotal = total(false);

    Widget section(String title, bool write, Duration sum) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(title, style: t.titleSmall)),
            Text(formatDuration(sum), style: t.titleSmall),
          ],
        ),
        const SizedBox(height: 6),
        for (final s in r.steps.where((s) => s.isWrite == write))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.label,
                        style: t.bodyMedium?.copyWith(
                          color: MfColors.slate900,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(s.detail, style: t.bodySmall),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatDuration(s.time),
                      key: Key('storage_step_${s.label}'),
                      style: t.titleSmall?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    Text(formatPerItem(s.time, r.count), style: t.bodySmall),
                  ],
                ),
              ],
            ),
          ),
      ],
    );

    return Container(
      key: const Key('storage_benchmarkCard'),
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MfColors.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              Eyebrow(
                '${r.count} kayıt',
                key: const Key('storage_benchmarkCount'),
              ),
              if (r.bytes != null)
                Eyebrow(
                  'diskte ${formatBytes(r.bytes!)}',
                  color: MfColors.slate600,
                  background: MfColors.slate100,
                ),
              Eyebrow(
                'yazma ${formatRate(writeTotal, r.count)}',
                color: MfColors.slate600,
                background: MfColors.slate100,
              ),
            ],
          ),
          const Gap(14),
          section('Yazma', true, writeTotal),
          const Divider(height: 20),
          section('Okuma', false, readTotal),
          const Gap(4),
          Text(
            'Süreler Stopwatch ile mikrosaniye (µs) hassasiyetinde ölçülür; '
            '1 ms = 1.000 µs. "Bellekten" satırları diske gitmediği için '
            'çok kısadır; gerçek disk maliyeti "diskten" satırlarındadır. '
            'Her ölçüm biraz farklı çıkar, birkaç kez deneyin.',
            style: t.bodySmall,
          ),
        ],
      ),
    );
  }
}
