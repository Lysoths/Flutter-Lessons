import 'package:flutter_bloc/flutter_bloc.dart';

/// Uygulamadaki her view model'in temel sınıfı.
///
/// [masterfabric_core](https://github.com/masterfabric-mobile/masterfabric_core)
/// içindeki `BaseViewModelCubit` ile aynıdır: view model'ler bundan türer ve
/// durumu yalnızca [stateChanger] ile değiştirir.
abstract class BaseViewModelCubit<S> extends Cubit<S> {
  /// View model'i [initialState] ile oluşturur.
  BaseViewModelCubit(super.initialState);

  /// Cubit kapanmamışsa [next] durumunu yayar.
  void stateChanger(S next) {
    if (isClosed) return;
    emit(next);
  }
}
