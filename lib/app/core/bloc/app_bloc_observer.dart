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
    // Bloc'lar aşağıdaki onTransition'da olayıyla birlikte yazılır.
    if (bloc is Bloc) return;
    // Yazılı hâli değişmeyen güncellemeler (ör. Ders 17'nin 2 sn'lik bellek
    // ölçümü) konsolu doldurmasın.
    if ('${change.currentState}' == '${change.nextState}') return;
    debugPrint('${bloc.runtimeType} $change');
  }

  /// DERS 13 — Bloc'larda her geçiş: hangi OLAY hangi durumu doğurdu.
  @override
  void onTransition(
    Bloc<Object?, Object?> bloc,
    Transition<Object?, Object?> transition,
  ) {
    super.onTransition(bloc, transition);
    debugPrint(
      '${bloc.runtimeType} ${transition.event} → ${transition.nextState}',
    );
  }
}
