import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_ders/app/core/sms/bank_sms.dart';

// ─────────────────────────────────────────────────────────────────────────
// DERS 21 — SMS kanalı (Dart tarafı)
//
// Hazır paket yok: kanalı biz kurduk. Kotlin tarafı SmsChannel.kt.
//
//   Dart                               kanal                    Kotlin
//   MethodChannel.invokeMethod  ──►  "flutter_ders/sms"  ──►  onMethodCall
//        Future ◄──────────────────── result.success(...) ◄─────┘
//
//   EventChannel.receiveBroadcastStream ◄── "flutter_ders/sms/gelen" ◄──
//        Stream (her yeni SMS bir olay)        BroadcastReceiver.onReceive
//
// Kanal adları ve metot adları iki tarafta birebir aynı olmalı; yazım
// hatası derlemede değil çalışırken (MissingPluginException) çıkar.
// Ekran bu arayüzü bilir; testte kanal yerine [MemorySmsSource] verilir.
// ─────────────────────────────────────────────────────────────────────────

/// SMS izninin durumu.
enum SmsAccess {
  /// Okuma ve alma izni var.
  granted,

  /// Verilmedi; yeniden sorulabilir.
  denied,

  /// "Bir daha sorma" seçildi; yalnız ayarlardan açılır.
  permanentlyDenied,

  /// Bu platformda SMS yok (iOS, web, masaüstü).
  unsupported;

  static SmsAccess _fromChannel(Object? value) {
    final state = value is Map ? value['durum'] : null;
    return switch (state) {
      'verildi' => granted,
      'kalici' => permanentlyDenied,
      _ => denied,
    };
  }
}

/// SMS okumada hata (izin yok, sağlayıcı okunamadı).
final class SmsReadException implements Exception {
  /// Oluşturur.
  const SmsReadException(this.code);

  /// Kotlin'den gelen hata kodu (`izin_yok`, `okunamadi` ...).
  final String code;

  @override
  String toString() => 'SmsReadException($code)';
}

/// Telefonun SMS'lerine erişim.
abstract interface class SmsSource {
  /// Şu anki izin durumu (pencere açmaz).
  Future<SmsAccess> access();

  /// İzin penceresini açar.
  Future<SmsAccess> requestAccess();

  /// Gelen kutusundaki son [days] günün banka SMS'leri, yeniden eskiye.
  Future<List<RawSms>> inbox({int days = 90, int limit = 300});

  /// Dinlenirken gelen yeni banka SMS'leri.
  Stream<RawSms> incoming();

  /// Uygulamanın ayar sayfasını açar.
  Future<void> openSettings();
}

/// Kotlin'deki SmsChannel'a bağlanan gerçek kaynak.
final class ChannelSmsSource implements SmsSource {
  /// Oluşturur. [isAndroid] testte değiştirilebilsin diye dışarıdan gelir.
  ChannelSmsSource({required bool isAndroid}) : _android = isAndroid;

  final bool _android;

  static const _methods = MethodChannel('flutter_ders/sms');
  static const _events = EventChannel('flutter_ders/sms/gelen');

  @override
  Future<SmsAccess> access() async {
    if (!_android) return SmsAccess.unsupported;
    return SmsAccess._fromChannel(await _methods.invokeMethod('izinDurumu'));
  }

  @override
  Future<SmsAccess> requestAccess() async {
    if (!_android) return SmsAccess.unsupported;
    try {
      return SmsAccess._fromChannel(await _methods.invokeMethod('izinIste'));
    } on PlatformException {
      return SmsAccess.denied;
    }
  }

  @override
  Future<List<RawSms>> inbox({int days = 90, int limit = 300}) async {
    if (!_android) return const [];
    try {
      final list = await _methods.invokeListMethod<Object?>('gelenKutusu', {
        'gun': days,
        'sinir': limit,
        // Banka dışı SMS'ler Kotlin'de elenir, kanaldan hiç geçmez.
        'gonderenler': kBankSenderKeys,
      });
      return [
        for (final item in list ?? const <Object?>[]) ?RawSms.fromChannel(item),
      ];
    } on PlatformException catch (e) {
      throw SmsReadException(e.code);
    }
  }

  @override
  Stream<RawSms> incoming() {
    if (!_android) return const Stream.empty();
    return _events
        .receiveBroadcastStream({'gonderenler': kBankSenderKeys})
        .handleError(
          (Object e) =>
              throw SmsReadException(e is PlatformException ? e.code : 'akis'),
        )
        .map(RawSms.fromChannel)
        .where((s) => s != null)
        .cast<RawSms>();
  }

  @override
  Future<void> openSettings() async {
    if (_android) await _methods.invokeMethod<void>('ayarlariAc');
  }
}

/// Testler için bellekteki kaynak.
final class MemorySmsSource implements SmsSource {
  /// Oluşturur.
  MemorySmsSource({
    this.state = SmsAccess.denied,
    this.afterRequest = SmsAccess.granted,
    List<RawSms> messages = const [],
  }) : messages = [...messages];

  /// Şu anki izin.
  SmsAccess state;

  /// İzin penceresinden sonra olacak durum.
  SmsAccess afterRequest;

  /// Gelen kutusu.
  final List<RawSms> messages;

  /// Kaç kez izin istendi.
  int requests = 0;

  /// Kaç kez ayarlar açıldı.
  int settingsOpened = 0;

  final _live = StreamController<RawSms>.broadcast();

  /// Yeni bir SMS gelmiş gibi yapar (gelen kutusuna da düşer).
  void deliver(RawSms sms) {
    messages.insert(0, sms);
    _live.add(sms);
  }

  @override
  Future<SmsAccess> access() async => state;

  @override
  Future<SmsAccess> requestAccess() async {
    requests++;
    return state = afterRequest;
  }

  @override
  Future<List<RawSms>> inbox({int days = 90, int limit = 300}) async {
    if (state != SmsAccess.granted) throw const SmsReadException('izin_yok');
    return [
      for (final m in messages)
        if (bankOf(m.sender) != null) m,
    ].take(limit).toList();
  }

  @override
  Stream<RawSms> incoming() => _live.stream;

  @override
  Future<void> openSettings() async => settingsOpened++;
}
