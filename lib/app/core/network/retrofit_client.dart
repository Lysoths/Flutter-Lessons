import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_ders/app/core/network/echo_api.dart';
import 'package:flutter_ders/app/core/network/posts_api.dart';
import 'package:flutter_ders/app/core/network/recording_interceptor.dart';

/// DERS 16 — İki retrofit servisi, tek Dio.
///
/// Dio ayarları (zaman aşımı, interceptor) burada bir kez verilir; retrofit
/// her servise aynı Dio'yu geçirir.
class RetrofitClient {
  /// İstemci oluşturur; [dio] verilmezse varsayılan ayarlarla kurulur.
  RetrofitClient({Dio? dio, RecordingInterceptor? recorder})
    : recorder = recorder ?? RecordingInterceptor(),
      dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 15),
            ),
          ) {
    this.dio.interceptors.add(this.recorder);
    posts = PostsApi(this.dio);
    echo = EchoApi(this.dio);
  }

  /// Ortak Dio.
  final Dio dio;

  /// Ağdan geçen her isteği kaydeden interceptor.
  final RecordingInterceptor recorder;

  /// jsonplaceholder.typicode.com.
  late final PostsApi posts;

  /// httpbin.org.
  late final EchoApi echo;

  /// Kapatır.
  Future<void> close() async {
    dio.close();
    await recorder.close();
  }
}
