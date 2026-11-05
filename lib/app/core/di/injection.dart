import 'dart:io';
import 'dart:ui' show PlatformDispatcher;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_ders/app/core/analytics/app_analytics.dart';
import 'package:flutter_ders/app/core/cache/app_image_cache.dart';
import 'package:flutter_ders/app/core/cache/image_fetchers.dart';
import 'package:flutter_ders/app/core/cache/image_memory_controller.dart';
import 'package:flutter_ders/app/core/device/device_info_source.dart';
import 'package:flutter_ders/app/core/device/location_source.dart';
import 'package:flutter_ders/app/core/device/sensor_source.dart';
import 'package:flutter_ders/app/core/firebase/app_config_cubit.dart';
import 'package:flutter_ders/app/core/firebase/finance_store.dart';
import 'package:flutter_ders/app/core/firebase/firebase_services.dart';
import 'package:flutter_ders/app/core/firebase/session_cubit.dart';
import 'package:flutter_ders/app/core/network/retrofit_client.dart';
import 'package:flutter_ders/app/core/repository/app_info_repository.dart';
import 'package:flutter_ders/app/core/repository/currency_repository.dart';
import 'package:flutter_ders/app/core/repository/expense_repository.dart';
import 'package:flutter_ders/app/core/repository/firestore_expense_repository.dart';
import 'package:flutter_ders/app/core/repository/json_sample_expense_repository.dart';
import 'package:flutter_ders/app/core/repository/live_rates_repository.dart';
import 'package:flutter_ders/app/core/repository/local_expense_repository.dart';
import 'package:flutter_ders/app/core/repository/network_info_repository.dart';
import 'package:flutter_ders/app/core/repository/news_repository.dart';
import 'package:flutter_ders/app/core/repository/note_store.dart';
import 'package:flutter_ders/app/core/repository/note_stores/hive_note_store.dart';
import 'package:flutter_ders/app/core/repository/note_stores/prefs_note_store.dart';
import 'package:flutter_ders/app/core/repository/note_stores/sqflite_note_store.dart';
import 'package:flutter_ders/app/core/repository/rates_repository.dart';
import 'package:flutter_ders/app/core/repository/sample_expense_repository.dart';
import 'package:flutter_ders/app/core/repository/tips_repository.dart';
import 'package:flutter_ders/app/helper/network_checker.dart';
import 'package:flutter_ders/app/views/view_app_network/bloc/app_info_bloc.dart';
import 'package:flutter_ders/app/views/view_app_network/bloc/network_info_bloc.dart';
import 'package:flutter_ders/app/views/view_auth/cubit/sign_in_cubit.dart';
import 'package:flutter_ders/app/views/view_bloc_demo/bloc/live_rates_bloc.dart';
import 'package:flutter_ders/app/views/view_bloc_demo/bloc/rates_bloc.dart';
import 'package:flutter_ders/app/views/view_bloc_demo/bloc/tips_bloc.dart';
import 'package:flutter_ders/app/views/view_currency/view_model/currency_view_model.dart';
import 'package:flutter_ders/app/views/view_currency/view_model/history_view_model.dart';
import 'package:flutter_ders/app/views/view_currency/view_model/news_view_model.dart';
import 'package:flutter_ders/app/views/view_currency/view_model/rates_view_model.dart';
import 'package:flutter_ders/app/views/view_device_info/bloc/device_info_bloc.dart';
import 'package:flutter_ders/app/views/view_expenses/cubit/expenses_cubit.dart';
import 'package:flutter_ders/app/views/view_firebase/cubit/firebase_lab_cubit.dart';
import 'package:flutter_ders/app/views/view_firebase/cubit/firestore_lab_cubit.dart';
import 'package:flutter_ders/app/views/view_image_cache/cubit/image_cache_lab_cubit.dart';
import 'package:flutter_ders/app/views/view_paged_list/cubit/paged_list_cubit.dart';
import 'package:flutter_ders/app/views/view_retrofit/cubit/retrofit_lab_cubit.dart';
import 'package:flutter_ders/app/views/view_storage/cubit/storage_demo_cubit.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Servis bulucu, masterfabric_core'daki `di/` (GetIt) ile aynı.
final GetIt getIt = GetIt.instance;

/// Helper'ları, depoları ve view model'leri kaydeder.
/// Birden çok kez çağrılabilir.
///
/// [firebase]: Firebase başlatıldıysa (main.dart) gerçek servisler, değilse
/// (testler) yerel sürümler kaydedilir.
Future<void> configureDependencies({bool firebase = false}) async {
  if (getIt.isRegistered<ExpenseRepository>()) return;
  final prefs = await SharedPreferences.getInstance();
  getIt
    // DERS 18 — Firebase servisleri ve uygulama genelindeki iki cubit.
    ..registerSingleton<AppAnalytics>(
      firebase ? const FirebaseAppAnalytics() : const NoopAnalytics(),
    )
    ..registerLazySingleton<ConfigSource>(
      firebase ? FirebaseConfigSource.new : LocalConfigSource.new,
    )
    ..registerLazySingleton<AuthRepository>(
      firebase ? FirebaseAuthRepository.new : LocalAuthRepository.new,
    )
    ..registerLazySingleton<CrashReporter>(
      firebase ? FirebaseCrashReporter.new : MemoryCrashReporter.new,
    )
    ..registerLazySingleton<AppCheckGuard>(
      firebase ? FirebaseAppCheckGuard.new : LocalAppCheckGuard.new,
    )
    ..registerLazySingleton<AppConfigCubit>(
      () => AppConfigCubit(
        source: getIt<ConfigSource>(),
        template: () => rootBundle.loadString('remoteconfig.template.json'),
        appVersion: () async => (await PackageInfo.fromPlatform()).version,
        prefs: SharedPreferences.getInstance,
        deviceLanguage: PlatformDispatcher.instance.locale.languageCode,
      ),
    )
    ..registerLazySingleton<SessionCubit>(
      () => SessionCubit(
        auth: getIt<AuthRepository>(),
        crash: getIt<CrashReporter>(),
      ),
    )
    ..registerFactory<SignInCubit>(
      () => SignInCubit(
        auth: getIt<AuthRepository>(),
        crash: getIt<CrashReporter>(),
      ),
    )
    ..registerLazySingleton<FinanceStore>(
      firebase ? FirestoreFinanceStore.new : MemoryFinanceStore.new,
    )
    ..registerFactory<FirestoreLabCubit>(
      () => FirestoreLabCubit(
        store: getIt<FinanceStore>(),
        seedSource: () =>
            rootBundle.loadString('assets/data/firestore_seed.json'),
        uid: () => getIt<SessionCubit>().state.user?.uid,
      ),
    )
    ..registerFactory<FirebaseLabCubit>(
      () => FirebaseLabCubit(
        appCheck: getIt<AppCheckGuard>(),
        crash: getIt<CrashReporter>(),
      ),
    )
    // DERS 18 — Firebase varken harcamalar giriş yapan kullanıcının
    // Firestore verisinden gelir; yoksa (testler) telefon hafızasından.
    ..registerSingleton<ExpenseRepository>(
      firebase
          ? FirestoreExpenseRepository(
              uid: () => getIt<SessionCubit>().state.user?.uid,
            )
          : LocalExpenseRepository(prefs),
    )
    ..registerFactory<ExpensesCubit>(
      () => ExpensesCubit(
        repository: getIt<ExpenseRepository>(),
        analytics: getIt<AppAnalytics>(),
      ),
    )
    // DERS 7 — 500 örnek kayıt JSON dosyasından bir kez okunur; cubit her
    // açılışta yeni.
    ..registerLazySingleton<SampleExpenseRepository>(
      JsonSampleExpenseRepository.new,
    )
    ..registerFactory<PagedListCubit>(
      () => PagedListCubit(repository: getIt<SampleExpenseRepository>()),
    )
    // DERS 17 — Sürüme bağlı görsel önbelleği ve bellek denetleyicisi.
    // İkisi de tek; main.dart açılışta başlatır.
    ..registerLazySingleton<AppImageCache>(
      () => AppImageCache(
        rootDirectory: getApplicationSupportDirectory,
        appVersion: () async {
          final p = await PackageInfo.fromPlatform();
          return '${p.version}+${p.buildNumber}';
        },
        fetcher: DefaultImageFetcher(
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 20),
            ),
          ),
        ),
        prefs: SharedPreferences.getInstance,
      ),
    )
    ..registerLazySingleton<ImageMemoryController>(
      () => ImageMemoryController(
        totalRamMb: () async => Platform.isAndroid
            ? (await DeviceInfoPlugin().androidInfo).physicalRamSize
            : Platform.isIOS
            ? (await DeviceInfoPlugin().iosInfo).physicalRamSize
            : null,
      ),
    )
    ..registerFactory<ImageCacheLabCubit>(
      () => ImageCacheLabCubit(
        cache: getIt<AppImageCache>(),
        memory: getIt<ImageMemoryController>(),
      ),
    )
    // DERS 16 — retrofit: tek istemci (iki servis, tek Dio), cubit her
    // açılışta yeni.
    ..registerLazySingleton<RetrofitClient>(RetrofitClient.new)
    ..registerFactory<RetrofitLabCubit>(
      () => RetrofitLabCubit(api: getIt<RetrofitClient>()),
    )
    // DERS 15 — MVVM (ChangeNotifier): depolar tek, ViewModel'ler her
    // açılışta yeni. Üst ViewModel alt ViewModel'leri birlikte alır.
    ..registerLazySingleton<CurrencyRepository>(
      () => CurrencyApiRepository(getIt<Dio>()),
    )
    ..registerLazySingleton<NewsRepository>(
      () => RssNewsRepository(getIt<Dio>()),
    )
    ..registerFactory<CurrencyViewModel>(
      () => CurrencyViewModel(
        rates: RatesViewModel(repository: getIt<CurrencyRepository>()),
        history: HistoryViewModel(repository: getIt<CurrencyRepository>()),
        news: NewsViewModel(repository: getIt<NewsRepository>()),
      ),
    )
    // DERS 14 — Cihaz, uygulama ve ağ bilgisi (Bloc).
    ..registerLazySingleton<DeviceInfoSource>(PlusDeviceInfoSource.new)
    ..registerLazySingleton<AppInfoRepository>(PlatformAppInfoRepository.new)
    ..registerLazySingleton<LocalNetworkSource>(DeviceLocalNetworkSource.new)
    ..registerLazySingleton<TraceRepository>(
      () => CloudflareTraceRepository(getIt<Dio>()),
    )
    ..registerFactory<DeviceInfoBloc>(
      () => DeviceInfoBloc(source: getIt<DeviceInfoSource>()),
    )
    ..registerFactory<AppInfoBloc>(
      () => AppInfoBloc(repository: getIt<AppInfoRepository>()),
    )
    ..registerFactory<NetworkInfoBloc>(
      () => NetworkInfoBloc(
        local: getIt<LocalNetworkSource>(),
        trace: getIt<TraceRepository>(),
        location: getIt<LocationSource>(),
      ),
    )
    // DERS 13 — Bloc: servis (dio), canlı akış ve asset depoları.
    ..registerLazySingleton<Dio>(createDio)
    ..registerLazySingleton<RatesRepository>(
      () => FrankfurterRatesRepository(getIt<Dio>()),
    )
    ..registerFactory<LiveRatesRepository>(MockLiveRatesRepository.new)
    ..registerLazySingleton<TipsRepository>(AssetTipsRepository.new)
    ..registerFactory<RatesBloc>(
      () => RatesBloc(repository: getIt<RatesRepository>()),
    )
    ..registerFactory<LiveRatesBloc>(
      () => LiveRatesBloc(repository: getIt<LiveRatesRepository>()),
    )
    ..registerFactory<TipsBloc>(
      () => TipsBloc(repository: getIt<TipsRepository>()),
    )
    // DERS 12 — Donanım: GPS ve sensörler (testte sahteleri verilir).
    ..registerLazySingleton<LocationSource>(GeolocatorLocationSource.new)
    ..registerLazySingleton<SensorSource>(DeviceSensorSource.new)
    // DERS 11 — Ağ kontrolü: tek helper, banner ve sayfa ortak kullanır.
    ..registerLazySingleton<NetworkChecker>(NetworkChecker.new)
    // DERS 10 — Üç depolama yöntemi; adlarıyla (instanceName) ayrılır.
    // Depolar ilk kullanıldıklarında açılır (lazy).
    ..registerLazySingleton<NoteStore>(
      () => PrefsNoteStore(prefs),
      instanceName: StorageKind.sharedPreferences.name,
    )
    ..registerLazySingleton<NoteStore>(
      () => HiveNoteStore(init: Hive.initFlutter),
      instanceName: StorageKind.hive.name,
    )
    ..registerLazySingleton<NoteStore>(
      SqfliteNoteStore.new,
      instanceName: StorageKind.sqflite.name,
    )
    ..registerFactoryParam<StorageDemoCubit, StorageKind, void>(
      (kind, _) =>
          StorageDemoCubit(store: getIt<NoteStore>(instanceName: kind.name)),
    );
}
