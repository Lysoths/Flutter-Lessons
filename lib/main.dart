import 'dart:async';
import 'dart:ui';

import 'package:bloc/bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_ders/app/app.dart';
import 'package:flutter_ders/app/core/bloc/app_bloc_observer.dart';
import 'package:flutter_ders/app/core/cache/app_image_cache.dart';
import 'package:flutter_ders/app/core/cache/image_memory_controller.dart';
import 'package:flutter_ders/app/core/di/injection.dart';
import 'package:flutter_ders/app/core/firebase/app_config_cubit.dart';
import 'package:flutter_ders/app/core/firebase/firebase_services.dart';
// Bu dosya repoda YOKTUR (.gitignore): Firebase anahtarı yalnız yerel
// derlemede durur. Kendi anahtarınızı koyunuz: `flutterfire configure` ya da
// `lib/firebase_options.example.dart` dosyasını bu adla kopyalayıp doldurun.
import 'package:flutter_ders/firebase_options.dart';

/// Bağımlılıkları kurar, ardından [HarcamaApp]'i çalıştırır.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Firebase, ayarları flutterfire configure ile üretilen dosyadan okur.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  Bloc.observer = const AppBlocObserver();
  await configureDependencies(firebase: true);

  // DERS 18 — App Check, Firebase'e ilk istekten önce başlar.
  await getIt<AppCheckGuard>().activate();
  // Crashlytics: Flutter çerçevesinin hataları ve çerçeve dışında kalanlar
  // (async, platform kanalı) yakalanıp rapor edilir.
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    unawaited(
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true),
    );
    return true;
  };
  // Remote Config: varsayılanlar + önbellekteki son değerler (ağ beklenmez;
  // sunucudan çekme arka planda sürer).
  await getIt<AppConfigCubit>().start();
  // DERS 17 — Yeni sürümse eski görsel önbelleği silinir; bellek
  // denetleyicisi arka planda çalışmaya başlar. Açılışı bekletmezler.
  unawaited(getIt<AppImageCache>().ensureReady());
  unawaited(getIt<ImageMemoryController>().start());
  runApp(const HarcamaApp());
}
