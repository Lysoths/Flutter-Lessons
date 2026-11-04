import 'package:equatable/equatable.dart';
import 'package:flutter_ders/app/core/base/base_view_model_bloc.dart';
import 'package:flutter_ders/app/core/repository/app_info_repository.dart';
import 'package:flutter_ders/app/models/info_section.dart';

/// DERS 14 — Uygulama bilgisi olayı: bir kez okunur.
final class AppInfoRequested extends Equatable {
  /// Olayı oluşturur.
  const AppInfoRequested();

  @override
  List<Object?> get props => [];
}

/// Uygulama bilgisi durumu.
sealed class AppInfoState extends Equatable {
  const AppInfoState();

  @override
  List<Object?> get props => [];
}

/// Okunuyor.
final class AppInfoLoading extends AppInfoState {
  /// Durumu oluşturur.
  const AppInfoLoading();
}

/// Okundu.
final class AppInfoLoaded extends AppInfoState {
  /// Durumu oluşturur.
  const AppInfoLoaded(this.sections);

  /// Bölümler.
  final List<InfoSection> sections;

  @override
  List<Object?> get props => [sections];

  @override
  String toString() => 'AppInfoLoaded(${sections.length} bölüm)';
}

/// Okunamadı.
final class AppInfoError extends AppInfoState {
  /// Durumu oluşturur.
  const AppInfoError(this.message);

  /// Açıklama.
  final String message;

  @override
  List<Object?> get props => [message];
}

/// Uygulama bilgisini okuyan Bloc.
class AppInfoBloc extends BaseViewModelBloc<AppInfoRequested, AppInfoState> {
  /// [repository] üzerinden çalışan Bloc oluşturur.
  AppInfoBloc({required this.repository}) : super(const AppInfoLoading()) {
    on<AppInfoRequested>((event, emit) async {
      emit(const AppInfoLoading());
      try {
        emit(AppInfoLoaded(await repository.read()));
      } on Exception catch (e) {
        emit(AppInfoError('Uygulama bilgisi okunamadı: $e'));
      }
    });
  }

  /// Bilginin geldiği yer.
  final AppInfoRepository repository;
}
