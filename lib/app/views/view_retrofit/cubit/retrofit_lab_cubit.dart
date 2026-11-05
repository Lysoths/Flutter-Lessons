import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_ders/app/core/analytics/app_events.dart';
import 'package:flutter_ders/app/core/base/base_view_model_cubit.dart';
import 'package:flutter_ders/app/core/network/api_result.dart';
import 'package:flutter_ders/app/core/network/recording_interceptor.dart';
import 'package:flutter_ders/app/core/network/retrofit_client.dart';
import 'package:flutter_ders/app/views/view_retrofit/cubit/retrofit_demos.dart';
import 'package:flutter_ders/app/views/view_retrofit/cubit/retrofit_lab_state.dart';

/// DERS 16 — Retrofit denemelerini çalıştıran view model.
///
///   Ekran ──run(deneme, girdiler)──▶ Cubit ──▶ retrofit metodu ──▶ Dio
///                                       ▲                          │
///                                       └── RecordingInterceptor ◀─┘
///
/// Retrofit'in döndürdüğü Dart nesnesi ve ağdan geçen ham istek/cevap yan
/// yana gösterilir: "ne yazdım" ile "ne gitti" aynı ekranda.
class RetrofitLabCubit extends BaseViewModelCubit<RetrofitLabState> {
  /// [api] ile çalışan cubit oluşturur.
  RetrofitLabCubit({required this.api}) : super(const RetrofitLabState()) {
    _log = api.recorder.exchanges.listen(_onExchange);
  }

  /// Retrofit servisleri.
  final RetrofitClient api;

  late final StreamSubscription<NetworkExchange> _log;
  final _cancelTokens = <String, CancelToken>{};

  /// Grubu süzer (null: hepsi).
  void showGroup(DemoGroup? group) =>
      stateChanger(state.copyWith(group: () => group));

  /// [demo]'yu [input] değerleriyle çalıştırır.
  Future<void> run(RetrofitDemo demo, Map<String, String> input) async {
    track(AppEvent.retrofitRun, demo.id);
    if (state.runs[demo.id]?.status == RunStatus.running) return;
    final token = _cancelTokens[demo.id] = CancelToken();
    _setRun(demo.id, const DemoRun(status: RunStatus.running));
    final watch = Stopwatch()..start();
    void progress(int done, int total) {
      if (total <= 0) return;
      final run = state.runs[demo.id];
      if (run == null || run.status != RunStatus.running) return;
      _setRun(demo.id, run.copyWith(progress: done / total));
    }

    DemoRun result;
    try {
      // Zone etiketi: bu çağrının attığı istekler bu denemeye yazılır.
      final value = await runZoned(
        () => demo.run(api, input, (
          onSendProgress: progress,
          onReceiveProgress: progress,
          cancelToken: token,
        )),
        zoneValues: {RecordingInterceptor.zoneKey: demo.id},
      );
      final shown = describeResult(value);
      result = DemoRun(
        status: value is ApiFailure ? RunStatus.failure : RunStatus.success,
        resultType: shown.type,
        resultText: shown.text,
        progress: demo.showsProgress ? 1 : null,
        took: watch.elapsed,
      );
    } on DioException catch (e) {
      result = DemoRun(
        status: e.type == DioExceptionType.cancel
            ? RunStatus.cancelled
            : RunStatus.failure,
        resultType: 'DioException(${e.type.name})',
        error: describeDioError(e),
        took: watch.elapsed,
      );
    } on Object catch (e) {
      result = DemoRun(
        status: RunStatus.failure,
        resultType: e.runtimeType.toString(),
        error: '$e',
        took: watch.elapsed,
      );
    }
    _cancelTokens.remove(demo.id);
    _setRun(
      demo.id,
      DemoRun(
        status: result.status,
        progress: result.progress,
        resultType: result.resultType,
        resultText: result.resultText,
        error: result.error,
        took: result.took,
        exchanges: state.runs[demo.id]?.exchanges ?? const [],
      ),
    );
  }

  /// Çalışan [demo]'yu iptal eder (`CancelToken.cancel`).
  void cancel(RetrofitDemo demo) {
    track(AppEvent.retrofitCancelled, demo.id);
    _cancelTokens[demo.id]?.cancel('Kullanıcı iptal etti');
  }

  /// Ağ kaydını temizler.
  void clearLog() => stateChanger(state.copyWith(log: const []));

  void _setRun(String id, DemoRun run) =>
      stateChanger(state.copyWith(runs: {...state.runs, id: run}));

  void _onExchange(NetworkExchange e) {
    final runs = {...state.runs};
    if (e.demoId case final id? when runs[id] != null) {
      runs[id] = runs[id]!.copyWith(exchanges: [...runs[id]!.exchanges, e]);
    }
    stateChanger(state.copyWith(runs: runs, log: [e, ...state.log.take(49)]));
  }

  @override
  Future<void> close() async {
    await _log.cancel();
    for (final t in _cancelTokens.values) {
      t.cancel();
    }
    return super.close();
  }
}
