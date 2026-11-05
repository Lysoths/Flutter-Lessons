import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_ders/app/core/analytics/app_events.dart';
import 'package:flutter_ders/app/core/firebase/firebase_services.dart';
import 'package:flutter_ders/app/core/firebase/remote_app_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// DERS 18 — Uygulama genelindeki ayarların durumu.
class AppConfigState extends Equatable {
  /// Oluşturur.
  const AppConfigState({
    this.ready = false,
    this.config = const RemoteAppConfig(
      design: DesignTokens(),
      texts: {},
      defaultLanguage: 'cihaz',
      policy: VersionPolicy(min: null, latest: null, updateUrl: null),
    ),
    this.origins = const {},
    this.languageOverride,
    this.deviceLanguage,
    this.installedVersion,
    this.lastFetch,
    this.lastStatus = '—',
    this.fetching = false,
    this.lastUpdatedKeys = const {},
    this.optionalDismissed = false,
  });

  /// İlk yükleme bitti mi?
  final bool ready;

  /// Çözülmüş ayarlar.
  final RemoteAppConfig config;

  /// Her parametrenin kaynağı.
  final Map<String, ConfigOrigin> origins;

  /// Kullanıcının seçtiği dil (null: Remote Config / cihaz).
  final String? languageOverride;

  /// Cihaz dili.
  final String? deviceLanguage;

  /// Yüklü sürüm (`1.0.0`).
  final String? installedVersion;

  /// Son başarılı çekme.
  final DateTime? lastFetch;

  /// Son çekmenin durumu.
  final String lastStatus;

  /// Çekiliyor mu?
  final bool fetching;

  /// Son canlı güncellemede değişen anahtarlar.
  final Set<String> lastUpdatedKeys;

  /// İsteğe bağlı güncelleme uyarısı bu oturumda kapatıldı mı?
  final bool optionalDismissed;

  /// Geçerli dil.
  String get language => config.resolveLanguage(
    override: languageOverride,
    deviceLanguage: deviceLanguage,
  );

  /// Geçerli dilde metin.
  String t(String key) => config.text(language, key);

  /// Sürüm durumu.
  UpdateStatus get updateStatus =>
      config.policy.statusFor(SemVer.tryParse(installedVersion));

  /// Değiştirilmiş kopya.
  AppConfigState copyWith({
    bool? ready,
    RemoteAppConfig? config,
    Map<String, ConfigOrigin>? origins,
    String? Function()? languageOverride,
    String? installedVersion,
    DateTime? Function()? lastFetch,
    String? lastStatus,
    bool? fetching,
    Set<String>? lastUpdatedKeys,
    bool? optionalDismissed,
  }) => AppConfigState(
    ready: ready ?? this.ready,
    config: config ?? this.config,
    origins: origins ?? this.origins,
    languageOverride: languageOverride != null
        ? languageOverride()
        : this.languageOverride,
    deviceLanguage: deviceLanguage,
    installedVersion: installedVersion ?? this.installedVersion,
    lastFetch: lastFetch != null ? lastFetch() : this.lastFetch,
    lastStatus: lastStatus ?? this.lastStatus,
    fetching: fetching ?? this.fetching,
    lastUpdatedKeys: lastUpdatedKeys ?? this.lastUpdatedKeys,
    optionalDismissed: optionalDismissed ?? this.optionalDismissed,
  );

  @override
  List<Object?> get props => [
    ready,
    config,
    origins,
    languageOverride,
    deviceLanguage,
    installedVersion,
    lastFetch,
    lastStatus,
    fetching,
    lastUpdatedKeys,
    optionalDismissed,
  ];

  @override
  String toString() =>
      'AppConfigState(ready: $ready, dil: $language, sürüm: '
      '$installedVersion → ${updateStatus.name}, çekme: $lastStatus, '
      'değişen: $lastUpdatedKeys)';
}

/// DERS 18 — Remote Config'i okur, tema/dil/sürüm durumunu yayar.
///
/// Açılış: uygulama içi varsayılan → önbellekteki son değer (anında) →
/// arka planda sunucu → konsolda yayınlanınca canlı güncelleme.
class AppConfigCubit extends Cubit<AppConfigState> {
  /// Oluşturur.
  AppConfigCubit({
    required this._source,
    required this._template,
    required this._appVersion,
    required this._prefs,
    String? deviceLanguage,
  }) : super(AppConfigState(deviceLanguage: deviceLanguage));

  final ConfigSource _source;
  final Future<String> Function() _template;
  final Future<String> Function() _appVersion;
  final Future<SharedPreferences> Function() _prefs;

  static const _languageKey = 'ders18_dil';

  Map<String, String> _defaults = const {};
  StreamSubscription<Set<String>>? _updates;
  Future<void>? _starting;

  /// Bir kez çalışır; sonraki çağrılar aynı işi bekler.
  Future<void> start() => _starting ??= _start();

  Future<void> _start() async {
    _defaults = defaultsFromTemplate(await _template());
    await _source.init(_defaults);
    final prefs = await _prefs();
    String? version;
    try {
      version = await _appVersion();
    } on Object {
      // Sürüm okunamazsa denetim yapılmaz (kilit açılmaz, kapanmaz).
    }
    emit(
      _read(
        state.copyWith(
          ready: true,
          installedVersion: version,
          languageOverride: () => prefs.getString(_languageKey),
        ),
      ),
    );
    _updates = _source.updates.listen(
      (keys) => emit(_read(state.copyWith(lastUpdatedKeys: keys))),
      onError: (Object _) {},
    );
    unawaited(refresh());
  }

  AppConfigState _read(AppConfigState s) => s.copyWith(
    config: RemoteAppConfig.parse(_source.values, fallback: _defaults),
    origins: _source.origins,
    lastFetch: () => _source.lastFetch,
    lastStatus: _source.lastStatus,
  );

  /// Sunucudan çeker.
  Future<void> refresh() async {
    if (state.fetching) return;
    emit(state.copyWith(fetching: true));
    try {
      await _source.fetch();
    } on Object {
      // Ağ yoksa önceki değerler geçerli kalır; durum metni hatayı söyler.
    }
    if (isClosed) return;
    emit(_read(state.copyWith(fetching: false)));
  }

  /// Dili seçer (null: Remote Config / cihaz dili).
  Future<void> setLanguage(String? code) async {
    track(AppEvent.languageSelected, code ?? 'cihaz');
    final prefs = await _prefs();
    code == null
        ? await prefs.remove(_languageKey)
        : await prefs.setString(_languageKey, code);
    emit(state.copyWith(languageOverride: () => code));
  }

  /// İsteğe bağlı güncelleme uyarısını bu oturumluk kapatır.
  void dismissOptionalUpdate() {
    track(AppEvent.updatePostponed);
    emit(state.copyWith(optionalDismissed: true));
  }

  @override
  Future<void> close() async {
    await _updates?.cancel();
    return super.close();
  }
}
