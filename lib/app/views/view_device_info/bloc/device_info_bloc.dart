import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_ders/app/core/analytics/app_events.dart';
import 'package:flutter_ders/app/core/base/base_view_model_bloc.dart';
import 'package:flutter_ders/app/core/device/device_info_source.dart';
import 'package:flutter_ders/app/views/view_device_info/bloc/device_info_event.dart';
import 'package:flutter_ders/app/views/view_device_info/bloc/device_info_state.dart';

/// DERS 14 — Cihaz bilgisi.
///
///   DeviceInfoRequested / DeviceInfoRefreshed
///        ↓
///   DeviceInfoLoading → (await source.read()) → DeviceInfoLoaded | Error
///
/// Okuma süresi Stopwatch ile ölçülür ve ekranda gösterilir.
class DeviceInfoBloc
    extends BaseViewModelBloc<DeviceInfoEvent, DeviceInfoState> {
  /// [source] üzerinden çalışan Bloc oluşturur.
  DeviceInfoBloc({required this.source}) : super(const DeviceInfoInitial()) {
    on<DeviceInfoRequested>(_read);
    on<DeviceInfoRefreshed>((e, emit) {
      track(AppEvent.deviceInfoRefreshed);
      return _read(e, emit);
    }, transformer: droppable());
  }

  /// Bilginin geldiği yer.
  final DeviceInfoSource source;

  Future<void> _read(
    DeviceInfoEvent event,
    Emitter<DeviceInfoState> emit,
  ) async {
    final previous = switch (state) {
      DeviceInfoLoaded(:final report) => report,
      _ => null,
    };
    emit(DeviceInfoLoading(previous: previous));
    final watch = Stopwatch()..start();
    try {
      final report = await source.read();
      emit(
        DeviceInfoLoaded(
          report: report,
          readAt: DateTime.now(),
          took: watch.elapsed,
        ),
      );
    } on Exception catch (e) {
      emit(DeviceInfoError('Cihaz bilgisi okunamadı: $e'));
    }
  }
}
