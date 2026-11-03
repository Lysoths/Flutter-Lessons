import 'package:bloc/bloc.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_ders/app/app.dart';
import 'package:flutter_ders/app/core/bloc/app_bloc_observer.dart';
import 'package:flutter_ders/app/core/di/injection.dart';

/// Bağımlılıkları kurar, ardından [HarcamaApp]'i çalıştırır.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Bloc.observer = const AppBlocObserver();
  await configureDependencies();
  runApp(const HarcamaApp());
}
