import 'package:flutter_ders/app/core/repository/expense_repository.dart';
import 'package:flutter_ders/app/core/repository/json_sample_expense_repository.dart';
import 'package:flutter_ders/app/core/repository/local_expense_repository.dart';
import 'package:flutter_ders/app/core/repository/note_store.dart';
import 'package:flutter_ders/app/core/repository/note_stores/hive_note_store.dart';
import 'package:flutter_ders/app/core/repository/note_stores/prefs_note_store.dart';
import 'package:flutter_ders/app/core/repository/note_stores/sqflite_note_store.dart';
import 'package:flutter_ders/app/core/repository/sample_expense_repository.dart';
import 'package:flutter_ders/app/views/view_expenses/cubit/expenses_cubit.dart';
import 'package:flutter_ders/app/views/view_paged_list/cubit/paged_list_cubit.dart';
import 'package:flutter_ders/app/views/view_storage/cubit/storage_demo_cubit.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Servis bulucu, masterfabric_core'daki `di/` (GetIt) ile aynı.
final GetIt getIt = GetIt.instance;

/// Helper'ları, depoları ve view model'leri kaydeder.
/// Birden çok kez çağrılabilir.
Future<void> configureDependencies() async {
  if (getIt.isRegistered<ExpenseRepository>()) return;
  final prefs = await SharedPreferences.getInstance();
  getIt
    ..registerSingleton<ExpenseRepository>(LocalExpenseRepository(prefs))
    ..registerFactory<ExpensesCubit>(
      () => ExpensesCubit(repository: getIt<ExpenseRepository>()),
    )
    // DERS 7 — 500 örnek kayıt JSON dosyasından bir kez okunur; cubit her
    // açılışta yeni.
    ..registerLazySingleton<SampleExpenseRepository>(
      JsonSampleExpenseRepository.new,
    )
    ..registerFactory<PagedListCubit>(
      () => PagedListCubit(repository: getIt<SampleExpenseRepository>()),
    )
    // DERS 10 — Üç depolama yöntemi; adlarıyla (instanceName) ayrılır.
    // Depolar ilk kullanıldıklarında açılır (lazy).
    ..registerLazySingleton<NoteStore>(
      () => PrefsNoteStore(prefs),
      instanceName: StorageKind.sharedPreferences.name,
    )
    ..registerLazySingleton<NoteStore>(
      () => HiveNoteStore(init: Hive.initFlutter),
      instanceName: StorageKind.hive.name,
    )
    ..registerLazySingleton<NoteStore>(
      SqfliteNoteStore.new,
      instanceName: StorageKind.sqflite.name,
    )
    ..registerFactoryParam<StorageDemoCubit, StorageKind, void>(
      (kind, _) =>
          StorageDemoCubit(store: getIt<NoteStore>(instanceName: kind.name)),
    );
}
