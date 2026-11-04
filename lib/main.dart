import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_ders/app/app.dart';
import 'package:flutter_ders/app/core/bloc/app_bloc_observer.dart';
import 'package:flutter_ders/app/core/cache/app_image_cache.dart';
import 'package:flutter_ders/app/core/cache/image_memory_controller.dart';
import 'package:flutter_ders/app/core/di/injection.dart';

/// Bağımlılıkları kurar, ardından [HarcamaApp]'i çalıştırır.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Bloc.observer = const AppBlocObserver();
  await configureDependencies();
  // DERS 17 — Yeni sürümse eski görsel önbelleği silinir; bellek
  // denetleyicisi arka planda çalışmaya başlar. Açılışı bekletmezler.
  unawaited(getIt<AppImageCache>().ensureReady());
  unawaited(getIt<ImageMemoryController>().start());
  runApp(const HarcamaApp());
}
