import 'package:flutter_bloc/flutter_bloc.dart';

/// DERS 13 — Olay (event) ile çalışan view model'lerin temel sınıfı.
///
/// [masterfabric_core](https://github.com/masterfabric-mobile/masterfabric_core)
/// içindeki `BaseViewModelBloc` ile aynı fikir. Cubit'ten farkı:
///
///   Cubit: ekran metot çağırır     → cubit.load()
///   Bloc:  ekran OLAY gönderir     → bloc.add(KurlarIstendi())
///          her olay türü için bir işleyici (`on<Olay>`) yeni durum yayar.
///
/// React'teki `useReducer` + `dispatch({type: ...})` gibi. Olaylar kayda
/// geçer (bkz. AppBlocObserver.onTransition) ve aynı olay arka arkaya
/// gelirse ne olacağı (sıraya koy / eskisini iptal et / yenisini yok say)
/// işleyicide `transformer:` ile seçilir.
abstract class BaseViewModelBloc<E, S> extends Bloc<E, S> {
  /// View model'i [initialState] ile oluşturur.
  BaseViewModelBloc(super.initialState);

  /// Şu anki durum (masterfabric_core'daki adıyla).
  S get currentState => state;
}
