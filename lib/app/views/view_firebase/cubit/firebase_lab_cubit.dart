import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_ders/app/core/analytics/app_events.dart';
import 'package:flutter_ders/app/core/firebase/firebase_services.dart';

/// DERS 18 — Firebase ders ekranının durumu.
class FirebaseLabState extends Equatable {
  /// Oluşturur.
  const FirebaseLabState({this.appCheck, this.checking = false, this.message});

  /// Son App Check denetimi.
  final AppCheckResult? appCheck;

  /// Denetleniyor mu?
  final bool checking;

  /// Son işlemin sonucu.
  final String? message;

  @override
  List<Object?> get props => [appCheck, checking, message];
}

/// DERS 18 — App Check denetimi ve Crashlytics denemeleri.
class FirebaseLabCubit extends Cubit<FirebaseLabState> {
  /// Oluşturur.
  FirebaseLabCubit({required this._appCheck, required this._crash})
    : super(const FirebaseLabState());

  final AppCheckGuard _appCheck;
  final CrashReporter _crash;
  int _logs = 0;

  /// Yeni App Check belirteci ister.
  Future<void> checkAppCheck() async {
    emit(FirebaseLabState(appCheck: state.appCheck, checking: true));
    final r = await _appCheck.check();
    track(AppEvent.appCheckRequested, r.ok ? 'alindi' : 'alinamadi');
    if (!isClosed) emit(FirebaseLabState(appCheck: r));
  }

  /// Crashlytics'e iz bırakır (sonraki rapora eklenir).
  Future<void> addLog() async {
    _logs++;
    track(AppEvent.crashLogAdded);
    await _crash.log('Ders 18 deneme kaydı #$_logs');
    emit(
      FirebaseLabState(
        appCheck: state.appCheck,
        message: 'Kayıt #$_logs eklendi; bir sonraki raporda görünür.',
      ),
    );
  }

  /// Yakalanan (non-fatal) hata gönderir.
  Future<void> recordNonFatal() async {
    track(AppEvent.nonFatalSent);
    try {
      throw StateError('Ders 18: yakalanan deneme hatası');
    } on StateError catch (e, st) {
      await _crash.recordError(e, st, reason: 'Ders 18 deneme düğmesi');
    }
    emit(
      FirebaseLabState(
        appCheck: state.appCheck,
        message:
            'Yakalanan hata gönderildi. Konsolda Crashlytics → "Non-fatals" '
            'altında birkaç dakika içinde görünür.',
      ),
    );
  }

  /// Uygulamayı çökertir; rapor bir sonraki açılışta gönderilir.
  void crash() {
    track(AppEvent.testCrash);
    _crash.crash();
  }
}
