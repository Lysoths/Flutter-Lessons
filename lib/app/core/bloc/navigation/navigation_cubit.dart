import 'package:flutter_ders/app/core/base/base_view_model_cubit.dart';
import 'package:flutter_ders/app/core/bloc/navigation/navigation_state.dart';
import 'package:flutter_ders/app/models/expense.dart';

/// DERS 2 — Navigation 2.0: gezinme durumunun tek kaynağı.
///
/// Ekranlar "şu ekranı aç" demez; yalnızca durumu değiştirir. Durum
/// değişince `AppRouterDelegate` ekran yığınını yeniden kurar.
class NavigationCubit extends BaseViewModelCubit<NavigationState> {
  /// Ana sayfadan başlar.
  NavigationCubit() : super(const NavigationState());

  /// [category] ekranını açık duruma getirir.
  void openCategory(ExpenseCategory category) {
    if (state.category == category) return;
    stateChanger(NavigationState(category: category));
  }

  /// Ana sayfaya döner.
  void backToHome() {
    if (!state.isCategoryOpen) return;
    stateChanger(const NavigationState());
  }

  /// Dışarıdan gelen bir durumu uygular (Ders 3: deep link).
  void restore(NavigationState next) {
    if (next == state) return;
    stateChanger(next);
  }

  /// Ana sayfa "yeni harcama" isteğini karşıladı; bayrağı indirir.
  void newExpenseHandled() {
    if (!state.newExpenseRequested) return;
    stateChanger(NavigationState(category: state.category));
  }
}
