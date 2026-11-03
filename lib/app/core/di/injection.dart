import 'package:flutter_ders/app/core/repository/expense_repository.dart';
import 'package:flutter_ders/app/core/repository/json_sample_expense_repository.dart';
import 'package:flutter_ders/app/core/repository/local_expense_repository.dart';
import 'package:flutter_ders/app/core/repository/sample_expense_repository.dart';
import 'package:flutter_ders/app/views/view_expenses/cubit/expenses_cubit.dart';
import 'package:flutter_ders/app/views/view_paged_list/cubit/paged_list_cubit.dart';
import 'package:get_it/get_it.dart';
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
    );
}
