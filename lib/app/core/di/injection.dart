import 'package:flutter_ders/app/core/bloc/navigation/navigation_cubit.dart';
import 'package:flutter_ders/app/core/repository/expense_repository.dart';
import 'package:flutter_ders/app/core/repository/local_expense_repository.dart';
import 'package:flutter_ders/app/views/view_expenses/cubit/expenses_cubit.dart';
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
    ..registerFactory<NavigationCubit>(NavigationCubit.new);
}
