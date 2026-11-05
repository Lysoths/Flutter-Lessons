import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

// ─────────────────────────────────────────────────────────────────────────
// DERS 18 — Firebase servisleri
//
// Ekranlar ve cubit'ler Firebase sınıflarını doğrudan görmez; buradaki
// arayüzleri görür. DI (injection.dart) gerçek uygulamada Firebase'li,
// testlerde yerel sürümleri kaydeder.
//
//   ConfigSource   Remote Config: varsayılan → önbellek → sunucu → canlı
//   AuthRepository Firebase Auth: Google hesabıyla giriş
//   CrashReporter  Crashlytics: yakalanmayan hatalar, kayıtlar, test çökmesi
//   AppCheckGuard  App Check: istekler bu uygulamadan mı geliyor?
// ─────────────────────────────────────────────────────────────────────────

// ── Remote Config ────────────────────────────────────────────────────────

/// Bir değerin nereden geldiği.
enum ConfigOrigin {
  /// Uygulamanın içindeki varsayılan.
  inApp('Uygulama'),

  /// Sunucudan alınıp etkinleştirilmiş.
  remote('Sunucu'),

  /// Hiçbiri (boş).
  none('—');

  const ConfigOrigin(this.label);

  /// Ekranda görünen ad.
  final String label;
}

/// Ayar kaynağı.
abstract interface class ConfigSource {
  /// Varsayılanları yükler, önbellekteki son değerleri etkinleştirir.
  Future<void> init(Map<String, String> defaults);

  /// Geçerli değerler.
  Map<String, String> get values;

  /// Her değerin kaynağı.
  Map<String, ConfigOrigin> get origins;

  /// Sunucudan çeker ve etkinleştirir; yeni değer geldiyse true.
  Future<bool> fetch();

  /// Konsolda yayınlanan değişiklikler (değişen anahtarlar), anında.
  Stream<Set<String>> get updates;

  /// Son başarılı çekme zamanı.
  DateTime? get lastFetch;

  /// Son çekmenin durumu.
  String get lastStatus;
}

/// Firebase Remote Config.
class FirebaseConfigSource implements ConfigSource {
  /// Oluşturur.
  FirebaseConfigSource([FirebaseRemoteConfig? rc])
    : _rc = rc ?? FirebaseRemoteConfig.instance;

  final FirebaseRemoteConfig _rc;

  @override
  Future<void> init(Map<String, String> defaults) async {
    await _rc.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        // Geliştirirken her çekme sunucuya gider; yayında saatte bir.
        // (Canlı güncellemeler bu sınırdan etkilenmez.)
        minimumFetchInterval: kDebugMode
            ? Duration.zero
            : const Duration(hours: 1),
      ),
    );
    await _rc.setDefaults(defaults);
    // Önceki açılışta çekilip bekleyen değerler varsa şimdi geçerli olur.
    await _rc.activate();
  }

  @override
  Map<String, String> get values => {
    for (final MapEntry(:key, :value) in _rc.getAll().entries)
      key: value.asString(),
  };

  @override
  Map<String, ConfigOrigin> get origins => {
    for (final MapEntry(:key, :value) in _rc.getAll().entries)
      key: switch (value.source) {
        ValueSource.valueRemote => ConfigOrigin.remote,
        ValueSource.valueDefault => ConfigOrigin.inApp,
        ValueSource.valueStatic => ConfigOrigin.none,
      },
  };

  @override
  Future<bool> fetch() => _rc.fetchAndActivate();

  @override
  Stream<Set<String>> get updates => _rc.onConfigUpdated.asyncMap((u) async {
    await _rc.activate();
    return u.updatedKeys;
  });

  @override
  DateTime? get lastFetch {
    final t = _rc.lastFetchTime;
    return t.millisecondsSinceEpoch == 0 ? null : t;
  }

  @override
  String get lastStatus => switch (_rc.lastFetchStatus) {
    RemoteConfigFetchStatus.success => 'Başarılı',
    RemoteConfigFetchStatus.failure => 'Başarısız',
    RemoteConfigFetchStatus.throttle => 'Sınırlandı (çok sık)',
    RemoteConfigFetchStatus.noFetchYet => 'Henüz çekilmedi',
  };
}

/// Yalnız varsayılanlarla çalışan kaynak (testler).
class LocalConfigSource implements ConfigSource {
  /// Oluşturur; [remote] sunucudan gelmiş gibi davranan değerlerdir.
  LocalConfigSource({Map<String, String> remote = const {}})
    : _remote = Map.of(remote);

  final Map<String, String> _remote;
  Map<String, String> _defaults = const {};
  final _updates = StreamController<Set<String>>.broadcast();

  @override
  Future<void> init(Map<String, String> defaults) async => _defaults = defaults;

  @override
  Map<String, String> get values => {..._defaults, ..._remote};

  @override
  Map<String, ConfigOrigin> get origins => {
    for (final k in values.keys)
      k: _remote.containsKey(k) ? ConfigOrigin.remote : ConfigOrigin.inApp,
  };

  @override
  Future<bool> fetch() async => false;

  /// Konsoldan yayınlanmış gibi değer değiştirir.
  void publish(Map<String, String> changes) {
    _remote.addAll(changes);
    _updates.add(changes.keys.toSet());
  }

  @override
  Stream<Set<String>> get updates => _updates.stream;

  @override
  DateTime? get lastFetch => null;

  @override
  String get lastStatus => 'Yerel';
}

// ── Auth ─────────────────────────────────────────────────────────────────

/// Oturumdaki kullanıcı.
class AppUser extends Equatable {
  /// Oluşturur.
  const AppUser({
    required this.uid,
    required this.email,
    this.name,
    this.createdAt,
    this.lastSignIn,
  });

  /// Firebase kullanıcı kimliği.
  final String uid;

  /// E-posta.
  final String email;

  /// Google hesabındaki ad.
  final String? name;

  /// Hesabın açıldığı an.
  final DateTime? createdAt;

  /// Son giriş.
  final DateTime? lastSignIn;

  @override
  List<Object?> get props => [uid, email, name, createdAt, lastSignIn];
}

/// Auth hatası; [key] dil metinlerindeki anahtardır (`hata.*`).
class AuthFailure implements Exception {
  /// Oluşturur.
  const AuthFailure(this.key, [this.code]);

  /// Firebase Auth hata kodundan.
  factory AuthFailure.fromFirebase(String code) => AuthFailure(switch (code) {
    'too-many-requests' => 'hata.cok_deneme',
    'network-request-failed' => 'hata.ag',
    'user-disabled' => 'hata.hesap_kapali',
    'operation-not-allowed' ||
    'admin-restricted-operation' => 'hata.yontem_kapali',
    'firebase-app-check-token-is-invalid' => 'hata.app_check',
    _ => 'hata.bilinmeyen',
  }, code);

  /// Google hesap seçimi hata kodundan.
  factory AuthFailure.fromGoogle(GoogleSignInExceptionCode code) =>
      AuthFailure(switch (code) {
        GoogleSignInExceptionCode.canceled ||
        GoogleSignInExceptionCode.interrupted => 'hata.iptal',
        GoogleSignInExceptionCode.clientConfigurationError ||
        GoogleSignInExceptionCode.providerConfigurationError =>
          'hata.yapilandirma',
        _ => 'hata.bilinmeyen',
      }, code.name);

  /// Metin anahtarı.
  final String key;

  /// Kaynak kod (kayıt için).
  final String? code;

  /// Kullanıcı kendisi vazgeçti mi? (Hata sayılmaz, raporlanmaz.)
  bool get cancelled => key == 'hata.iptal';

  @override
  String toString() => 'AuthFailure($key, $code)';
}

/// Google hesabıyla oturum.
abstract interface class AuthRepository {
  /// Şimdiki kullanıcı.
  AppUser? get current;

  /// Oturum değişiklikleri.
  Stream<AppUser?> get changes;

  /// Google hesabı seçtirir ve Firebase'e o hesapla girer.
  Future<void> signInWithGoogle();

  /// Çıkış (bir sonraki girişte hesap yeniden sorulur).
  Future<void> signOut();
}

/// Firebase Auth + Google ile giriş.
///
///   1. GoogleSignIn.authenticate  → Android'in hesap seçicisi (Credential
///      Manager); sonuç bir idToken.
///   2. GoogleAuthProvider.credential(idToken) → Firebase'e giriş.
///
/// idToken'ın Firebase için geçerli olması "Web client ID"ye bağlıdır;
/// google-services eklentisi onu google-services.json'dan okuyup
/// `default_web_client_id` olarak uygulamaya koyar.
class FirebaseAuthRepository implements AuthRepository {
  /// Oluşturur.
  FirebaseAuthRepository([FirebaseAuth? auth, GoogleSignIn? google])
    : _auth = auth ?? FirebaseAuth.instance,
      _google = google ?? GoogleSignIn.instance;

  final FirebaseAuth _auth;
  final GoogleSignIn _google;
  Future<void>? _init;

  static AppUser? _map(User? u) => u == null
      ? null
      : AppUser(
          uid: u.uid,
          email: u.email ?? '',
          name: u.displayName,
          createdAt: u.metadata.creationTime,
          lastSignIn: u.metadata.lastSignInTime,
        );

  @override
  AppUser? get current => _map(_auth.currentUser);

  @override
  Stream<AppUser?> get changes => _auth.userChanges().map(_map);

  @override
  Future<void> signInWithGoogle() async {
    try {
      await (_init ??= _google.initialize());
      final account = await _google.authenticate();
      final idToken = account.authentication.idToken;
      await _auth.signInWithCredential(
        GoogleAuthProvider.credential(idToken: idToken),
      );
    } on GoogleSignInException catch (e) {
      throw AuthFailure.fromGoogle(e.code);
    } on FirebaseAuthException catch (e) {
      throw AuthFailure.fromFirebase(e.code);
    }
  }

  @override
  Future<void> signOut() async {
    await (_init ??= _google.initialize());
    await _google.signOut();
    await _auth.signOut();
  }
}

/// Bellekte çalışan oturum (testler). Varsayılan: giriş yapılmış.
class LocalAuthRepository implements AuthRepository {
  /// Oluşturur; [failure] verilirse giriş o hatayla biter.
  LocalAuthRepository({this._user = kDemoUser, this.failure});

  /// Testlerdeki hazır kullanıcı.
  static const kDemoUser = AppUser(
    uid: 'yerel',
    email: 'deneme@ornek.com',
    name: 'Deneme Kullanıcı',
  );

  /// Girişte fırlatılacak hata.
  AuthFailure? failure;

  AppUser? _user;
  final _changes = StreamController<AppUser?>.broadcast();

  void _set(AppUser? u) => _changes.add(_user = u);

  @override
  AppUser? get current => _user;

  @override
  Stream<AppUser?> get changes => _changes.stream;

  @override
  Future<void> signInWithGoogle() async {
    if (failure case final f?) throw f;
    _set(kDemoUser);
  }

  @override
  Future<void> signOut() async => _set(null);
}

// ── Crashlytics ──────────────────────────────────────────────────────────

/// Hata raporlama.
abstract interface class CrashReporter {
  /// Raporlar kullanıcıya bağlansın (yalnız uid; e-posta gönderilmez).
  Future<void> setUser(String? uid);

  /// Bir sonraki rapora eklenecek iz.
  Future<void> log(String message);

  /// Yakalanan hata (uygulama çalışmaya devam eder).
  Future<void> recordError(Object error, StackTrace? stack, {String? reason});

  /// Uygulamayı gerçekten çökertir (test).
  void crash();
}

/// Firebase Crashlytics.
class FirebaseCrashReporter implements CrashReporter {
  /// Oluşturur.
  FirebaseCrashReporter([FirebaseCrashlytics? c])
    : _c = c ?? FirebaseCrashlytics.instance;

  final FirebaseCrashlytics _c;

  @override
  Future<void> setUser(String? uid) => _c.setUserIdentifier(uid ?? '');

  @override
  Future<void> log(String message) => _c.log(message);

  @override
  Future<void> recordError(Object error, StackTrace? stack, {String? reason}) =>
      _c.recordError(error, stack, reason: reason);

  @override
  void crash() => _c.crash();
}

/// Hiçbir yere göndermeyen raporlayıcı (testler); kayıtları tutar.
class MemoryCrashReporter implements CrashReporter {
  /// Kayıtlar.
  final records = <String>[];

  @override
  Future<void> setUser(String? uid) async => records.add('user:$uid');

  @override
  Future<void> log(String message) async => records.add('log:$message');

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    String? reason,
  }) async => records.add('error:$error');

  @override
  void crash() => records.add('crash');
}

// ── App Check ────────────────────────────────────────────────────────────

/// App Check denetiminin sonucu.
class AppCheckResult extends Equatable {
  /// Oluşturur.
  const AppCheckResult({required this.provider, this.tokenLength, this.error});

  /// Kullanılan sağlayıcı.
  final String provider;

  /// Alınan belirtecin uzunluğu (belirtecin kendisi gösterilmez).
  final int? tokenLength;

  /// Hata.
  final String? error;

  /// Belirteç alındı mı?
  bool get ok => tokenLength != null;

  @override
  List<Object?> get props => [provider, tokenLength, error];
}

/// App Check.
abstract interface class AppCheckGuard {
  /// Sağlayıcıyı başlatır.
  Future<void> activate();

  /// Yeni belirteç ister.
  Future<AppCheckResult> check();
}

/// Firebase App Check: geliştirmede debug, yayında Play Integrity.
class FirebaseAppCheckGuard implements AppCheckGuard {
  /// Oluşturur.
  FirebaseAppCheckGuard([FirebaseAppCheck? c])
    : _c = c ?? FirebaseAppCheck.instance;

  final FirebaseAppCheck _c;

  static const _provider = kDebugMode ? 'Debug' : 'Play Integrity';

  @override
  Future<void> activate() => _c.activate(
    // Debug sağlayıcı, logcat'e bir belirteç yazar ("DebugAppCheckProvider");
    // o belirteç konsolda App Check → Uygulamalar → Debug belirteçleri'ne
    // eklenir. Yayın sürümü Play Integrity kullanır.
    providerAndroid: kDebugMode
        ? const AndroidDebugProvider()
        : const AndroidPlayIntegrityProvider(),
  );

  @override
  Future<AppCheckResult> check() async {
    try {
      final t = await _c.getToken(true);
      return AppCheckResult(provider: _provider, tokenLength: t?.length);
    } on Object catch (e) {
      final s = '$e';
      return AppCheckResult(
        provider: _provider,
        error: s.length > 160 ? '${s.substring(0, 160)}…' : s,
      );
    }
  }
}

/// Hiçbir şey yapmayan App Check (testler).
class LocalAppCheckGuard implements AppCheckGuard {
  @override
  Future<void> activate() async {}

  @override
  Future<AppCheckResult> check() async =>
      const AppCheckResult(provider: 'Yerel', tokenLength: 0);
}
