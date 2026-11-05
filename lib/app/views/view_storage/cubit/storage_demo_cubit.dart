import 'dart:math';

import 'package:flutter_ders/app/core/analytics/app_events.dart';
import 'package:flutter_ders/app/core/base/base_view_model_cubit.dart';
import 'package:flutter_ders/app/core/repository/note_store.dart';
import 'package:flutter_ders/app/models/storage_note.dart';
import 'package:flutter_ders/app/views/view_storage/cubit/storage_demo_state.dart';
import 'package:uuid/uuid.dart';

/// DERS 10 — Üç depolama ekranının ortak view model'i.
///
/// Hangi depoyla çalıştığını bilmez; yalnızca [NoteStore] arayüzünü
/// kullanır. Böylece SharedPreferences, Hive ve sqflite ekranları aynı
/// kodla çalışır, fark yalnızca depodadır.
class StorageDemoCubit extends BaseViewModelCubit<StorageDemoState> {
  /// [store] üzerinde çalışan cubit oluşturur.
  StorageDemoCubit({required this.store, Random? random})
    : _random = random ?? Random(),
      super(const StorageDemoState());

  /// Kayıtların saklandığı yer.
  final NoteStore store;

  final Random _random;
  static const _uuid = Uuid();
  static const _titles = [
    'Market',
    'Kahve',
    'Taksi',
    'Fatura',
    'Sinema',
    'Kitap',
    'Eczane',
  ];

  /// Depoyu açar ve kayıtları okur.
  Future<void> load() => _guard(() async {
    await store.open();
    await _refresh();
  });

  /// Rastgele bir kayıt ekler.
  Future<void> addSample() => _guard(() async {
    track(AppEvent.storageAdded, store.kind.name);
    await store.add(_sample(DateTime.now()));
    await _refresh();
  });

  /// [id] kimlikli kaydı siler.
  Future<void> delete(String id) => _guard(() async {
    track(AppEvent.storageDeleted, store.kind.name);
    await store.delete(id);
    await _refresh();
  });

  /// Bu dersin bütün kayıtlarını siler.
  Future<void> clear() => _guard(() async {
    track(AppEvent.storageCleared, store.kind.name);
    await store.clear();
    await _refresh();
  });

  /// Ölçümde kullanılacak kayıt sayısını seçer.
  void setBenchmarkSize(int size) =>
      stateChanger(state.copyWith(benchmarkSize: size));

  /// Depoyu boşaltıp [count] (verilmezse seçili sayı) kaydı tek seferde
  /// yazar ve okur; her adımın süresini ayrı ölçer.
  Future<void> benchmark([int? count]) => _guard(() async {
    track(AppEvent.storageBenchmark, store.kind.name);
    final n = count ?? state.benchmarkSize;
    stateChanger(state.copyWith(status: StorageDemoStatus.benchmarking));
    await store.clear();
    final now = DateTime.now();
    final notes = [
      for (var i = 0; i < n; i++) _sample(now.subtract(Duration(minutes: i))),
    ];
    final result = await store.benchmark(notes);
    stateChanger(
      state.copyWith(
        benchmark: (count: n, steps: result.steps, bytes: result.bytes),
      ),
    );
    await _refresh();
  });

  StorageNote _sample(DateTime at) => StorageNote(
    id: _uuid.v4(),
    title: _titles[_random.nextInt(_titles.length)],
    amount: (_random.nextInt(50000) + 500) / 100,
    createdAt: at,
  );

  Future<void> _refresh() async {
    final notes = await store.getAll();
    final raw = await store.rawView();
    stateChanger(
      state.copyWith(status: StorageDemoStatus.ready, notes: notes, raw: raw),
    );
  }

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } on Object catch (e) {
      stateChanger(
        state.copyWith(status: StorageDemoStatus.failure, error: '$e'),
      );
    }
  }
}
