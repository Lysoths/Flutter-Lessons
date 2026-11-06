import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_ders/app/core/hardware/hardware_profile.dart';

// ─────────────────────────────────────────────────────────────────────────
// DERS 22 — Donanım kanalı (Dart tarafı). Kotlin ucu HardwareChannel.kt.
//
//   profil()  ── MethodChannel ──►  tek seferlik büyük harita → DeviceProfile
//   imei()    ── MethodChannel ──►  PlatformException("sistem_izni")
//                                    → ImeiBlocked (hata da bir cevaptır)
//   canli()   ◄── EventChannel ───  saniyede bir LiveReading
//
// Ekran yalnız bu arayüzü bilir; testlerde [MemoryHardwareSource] verilir.
// ─────────────────────────────────────────────────────────────────────────

/// Bu platformda donanım kanalı yok (iOS, web, masaüstü).
final class HardwareUnsupported implements Exception {
  /// Oluşturur.
  const HardwareUnsupported();
}

/// Profil okunamadı.
final class HardwareReadException implements Exception {
  /// Oluşturur.
  const HardwareReadException(this.code);

  /// Kanal hata kodu.
  final String code;

  @override
  String toString() => 'HardwareReadException($code)';
}

/// Telefonun donanım bilgisine erişim.
abstract interface class HardwareSource {
  /// Bütün profil.
  Future<DeviceProfile> profile();

  /// IMEI'yi dener.
  Future<ImeiResult> imei();

  /// READ_PHONE_STATE var mı?
  Future<bool> phoneAccess();

  /// READ_PHONE_STATE ister.
  Future<bool> requestPhoneAccess();

  /// Dinlenirken saniyede bir ölçüm.
  Stream<LiveReading> live();
}

/// Kotlin'deki HardwareChannel'a bağlanan kaynak.
final class ChannelHardwareSource implements HardwareSource {
  /// Oluşturur.
  ChannelHardwareSource({required bool isAndroid}) : _android = isAndroid;

  final bool _android;

  static const _methods = MethodChannel('flutter_ders/donanim');
  static const _events = EventChannel('flutter_ders/donanim/canli');

  @override
  Future<DeviceProfile> profile() async {
    if (!_android) throw const HardwareUnsupported();
    try {
      return DeviceProfile.fromChannel(await _methods.invokeMethod('profil'));
    } on PlatformException catch (e) {
      throw HardwareReadException(e.code);
    }
  }

  @override
  Future<ImeiResult> imei() async {
    if (!_android) return const ImeiBlocked(code: 'platform');
    try {
      final value = await _methods.invokeMethod<String>('imei');
      return value == null || value.isEmpty
          ? const ImeiBlocked(code: 'bos')
          : ImeiRead(value);
    } on PlatformException catch (e) {
      return ImeiBlocked(
        code: e.code,
        message: e.message,
        sdk: e.details is int ? e.details as int : null,
      );
    }
  }

  @override
  Future<bool> phoneAccess() async =>
      _android && (await _methods.invokeMethod<bool>('telefonIzni') ?? false);

  @override
  Future<bool> requestPhoneAccess() async {
    if (!_android) return false;
    try {
      return await _methods.invokeMethod<bool>('telefonIzniIste') ?? false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Stream<LiveReading> live() {
    if (!_android) return const Stream.empty();
    return _events
        .receiveBroadcastStream()
        .map(LiveReading.fromChannel)
        .where((r) => r != null)
        .cast<LiveReading>();
  }
}

/// Testler için: Kotlin'in döndürdüğü biçimdeki haritayla çalışır.
final class MemoryHardwareSource implements HardwareSource {
  /// Oluşturur.
  MemoryHardwareSource({
    required this.profileMap,
    this.imeiResult = const ImeiBlocked(code: 'sistem_izni', sdk: 36),
    this.granted = false,
    this.grantOnRequest = true,
  });

  /// Kanal biçiminde profil; izin verilince telefon bölümü güncellenir.
  Map<String, Object?> profileMap;

  /// IMEI denemesinin sonucu.
  ImeiResult imeiResult;

  /// Telefon izni.
  bool granted;

  /// İstenince izin verilsin mi?
  bool grantOnRequest;

  /// Kaç kez profil okundu.
  int reads = 0;

  final _live = StreamController<LiveReading>.broadcast();

  /// Canlı ölçüm gönderir.
  void emit(LiveReading r) => _live.add(r);

  /// Dinleyen var mı?
  bool get listening => _live.hasListener;

  @override
  Future<DeviceProfile> profile() async {
    reads++;
    final phone = {...?(profileMap['telefon'] as Map<String, Object?>?)};
    phone['izin'] = granted;
    // Kotlin gibi: izin yokken izinli alanlar hiç sorulmaz.
    if (!granted) {
      phone
        ..['ag'] = null
        ..['aktifSim'] = null;
    }
    return DeviceProfile.fromChannel({...profileMap, 'telefon': phone});
  }

  @override
  Future<ImeiResult> imei() async => imeiResult;

  @override
  Future<bool> phoneAccess() async => granted;

  @override
  Future<bool> requestPhoneAccess() async => granted = grantOnRequest;

  @override
  Stream<LiveReading> live() => _live.stream;
}
