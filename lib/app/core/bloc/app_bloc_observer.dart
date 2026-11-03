import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';

/// Tüm Bloc/Cubit durum değişikliklerini konsola yazar
/// (bloclibrary.dev sayaç eğitimindeki `CounterObserver`).
class AppBlocObserver extends BlocObserver {
  /// Gözlemciyi oluşturur.
  const AppBlocObserver();

  @override
  void onChange(BlocBase<Object?> bloc, Change<Object?> change) {
    super.onChange(bloc, change);
    debugPrint('${bloc.runtimeType} $change');
  }
}
