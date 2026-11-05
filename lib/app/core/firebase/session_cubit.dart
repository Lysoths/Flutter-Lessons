import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_ders/app/core/analytics/app_events.dart';
import 'package:flutter_ders/app/core/firebase/firebase_services.dart';

/// DERS 18 — Oturum durumu.
class SessionState extends Equatable {
  /// Oluşturur.
  const SessionState(this.user);

  /// Oturumdaki kullanıcı (null: çıkış yapılmış).
  final AppUser? user;

  /// Giriş yapılmış mı?
  bool get signedIn => user != null;

  @override
  List<Object?> get props => [user];

  // E-posta kayıtlara yazılmaz.
  @override
  String toString() => 'SessionState(${user == null ? 'çıkış' : 'giriş'})';
}

/// DERS 18 — Uygulama genelindeki oturum. Uygulamaya giriş bunun
/// durumuna bağlıdır (AppGate).
class SessionCubit extends Cubit<SessionState> {
  /// Oluşturur.
  SessionCubit({required this._auth, required this._crash})
    : super(SessionState(_auth.current)) {
    unawaited(_crash.setUser(state.user?.uid));
    _sub = _auth.changes.listen((u) {
      if (u?.uid != state.user?.uid) unawaited(_crash.setUser(u?.uid));
      emit(SessionState(u));
    });
  }

  final AuthRepository _auth;
  final CrashReporter _crash;
  late final StreamSubscription<AppUser?> _sub;

  /// Çıkış.
  Future<void> signOut() {
    track(AppEvent.signedOut);
    return _auth.signOut();
  }

  @override
  Future<void> close() async {
    await _sub.cancel();
    return super.close();
  }
}
