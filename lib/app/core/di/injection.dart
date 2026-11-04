import 'package:dio/dio.dart';
import 'package:flutter_ders/app/core/device/device_info_source.dart';
import 'package:flutter_ders/app/core/device/location_source.dart';
import 'package:flutter_ders/app/core/device/sensor_source.dart';
import 'package:flutter_ders/app/core/repository/app_info_repository.dart';
import 'package:flutter_ders/app/core/repository/currency_repository.dart';
import 'package:flutter_ders/app/core/repository/expense_repository.dart';
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
import 'package:flutter_ders/app/views/view_bloc_demo/bloc/live_rates_bloc.dart';
import 'package:flutter_ders/app/views/view_bloc_demo/bloc/rates_bloc.dart';
import 'package:flutter_ders/app/views/view_bloc_demo/bloc/tips_bloc.dart';
import 'package:flutter_ders/app/views/view_currency/view_model/currency_view_model.dart';
import 'package:flutter_ders/app/views/view_currency/view_model/history_view_model.dart';
import 'package:flutter_ders/app/views/view_currency/view_model/news_view_model.dart';
import 'package:flutter_ders/app/views/view_currency/view_model/rates_view_model.dart';
import 'package:flutter_ders/app/views/view_device_info/bloc/device_info_bloc.dart';
import 'package:flutter_ders/app/views/view_expenses/cubit/expenses_cubit.dart';
import 'package:flutter_ders/app/views/view_paged_list/cubit/paged_list_cubit.dart';
import 'package:flutter_ders/app/views/view_storage/cubit/storage_demo_cubit.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Servis bulucu, masterfabric_core'daki `di/` (GetIt) ile aynı.
final GetIt getIt = GetIt.instance;

/// Helper'ları, depoları ve view model'leri kaydeder.
/// Birden çok kez çağrılabilir.
Future<void> configureDependencies() async {
  if (getIt.isRegistered<ExpenseRepository>()) return;
  final prefs = await SharedPreferences.getInstance();
  getIt
    ..registerSingleton<ExpenseRepository>(LocalExpenseRepository(prefs))
    ..registerFactory<ExpensesCubit>(
      () => ExpensesCubit(repository: getIt<ExpenseRepository>()),
    )
    // DERS 7 — 500 örnek kayıt JSON dosyasından bir kez okunur; cubit her
    // açılışta yeni.
    ..registerLazySingleton<SampleExpenseRepository>(
      JsonSampleExpenseRepository.new,
    )
    ..registerFactory<PagedListCubit>(
      () => PagedListCubit(repository: getIt<SampleExpenseRepository>()),
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
