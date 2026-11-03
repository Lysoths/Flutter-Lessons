import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_ders/app/core/bloc/navigation/navigation_cubit.dart';
import 'package:flutter_ders/app/core/bloc/navigation/navigation_state.dart';
import 'package:flutter_ders/app/models/expense.dart';
import 'package:flutter_test/flutter_test.dart';

// DERS 2 — Navigation 2.0: durum değişiklikleri.
void main() {
  test('ana sayfadan başlar', () {
    expect(NavigationCubit().state, const NavigationState());
  });

  blocTest<NavigationCubit, NavigationState>(
    'kategori açma ve ana sayfaya dönüş; tekrarlar yayılmaz',
    build: NavigationCubit.new,
    act: (c) => c
      ..openCategory(ExpenseCategory.food)
      ..openCategory(ExpenseCategory.food)
      ..openCategory(ExpenseCategory.bills)
      ..backToHome()
      ..backToHome(),
    expect: () => const [
      NavigationState(category: ExpenseCategory.food),
      NavigationState(category: ExpenseCategory.bills),
      NavigationState(),
    ],
  );

  blocTest<NavigationCubit, NavigationState>(
    'restore dışarıdan gelen durumu uygular',
    build: NavigationCubit.new,
    act: (c) => c
      ..restore(const NavigationState(category: ExpenseCategory.fun))
      ..restore(const NavigationState(category: ExpenseCategory.fun)),
    expect: () => const [NavigationState(category: ExpenseCategory.fun)],
  );
}
