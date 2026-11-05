import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_ders/app/core/analytics/app_events.dart';
import 'package:flutter_ders/app/core/firebase/firebase_services.dart';

/// DERS 18 — Giriş ekranının durumu. Hata metni bir dil anahtarıdır;
/// ekran geçerli dilde gösterir.
class SignInState extends Equatable {
  /// Oluşturur.
  const SignInState({this.busy = false, this.errorKey});

  /// Hesap seçici açık / Firebase'e giriliyor mu?
  final bool busy;

  /// Hata metni anahtarı.
  final String? errorKey;

  @override
  List<Object?> get props => [busy, errorKey];
}

/// DERS 18 — Google ile giriş.
class SignInCubit extends Cubit<SignInState> {
  /// Oluşturur.
  SignInCubit({required this._auth, required this._crash})
    : super(const SignInState());

  final AuthRepository _auth;
  final CrashReporter _crash;

  /// Google hesabıyla girer. Başarılı olunca oturum değişir, AppGate
  /// uygulamayı açar; bu cubit ayrıca bir şey yapmaz.
  Future<void> signIn() async {
    if (state.busy) return;
    emit(const SignInState(busy: true));
    try {
      await _auth.signInWithGoogle();
      track(AppEvent.signInSucceeded);
      if (!isClosed) emit(const SignInState());
    } on AuthFailure catch (e, st) {
      // Beklenmeyen hatalar Crashlytics'e gider; vazgeçmek hata değildir.
      if (e.key == 'hata.bilinmeyen' || e.key == 'hata.yapilandirma') {
        await _crash.recordError(e, st, reason: 'google giriş');
      }
      track(AppEvent.signInFailed, e.key);
      if (!isClosed) emit(SignInState(errorKey: e.key));
    }
  }
}
