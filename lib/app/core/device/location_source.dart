import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

// ─────────────────────────────────────────────────────────────────────────
// DERS 12 — GPS donanımından canlı konum
//
// 1. İzin (Future): konum servisi açık mı, kullanıcı izin verdi mi?
//    Bir kez sorulur, bir kez cevaplanır.
// 2. Konum akışı (Stream): GPS her yeni ölçüm yaptığında (≈ saniyede bir)
//    yeni bir konum gelir; ekranda StreamBuilder ile canlı gösterilir.
//
// Konum yalnızca ekranda gösterilir: kaydedilmez, hiçbir yere gönderilmez.
// ─────────────────────────────────────────────────────────────────────────

/// Konuma erişim durumu.
enum LocationAccess {
  /// İzin var, servis açık.
  granted('İzin verildi'),

  /// Telefonun konum servisi kapalı.
  serviceOff('Konum servisi kapalı'),

  /// Kullanıcı izin vermedi (tekrar sorulabilir).
  denied('İzin verilmedi'),

  /// Kullanıcı "bir daha sorma" dedi; yalnızca ayarlardan açılır.
  deniedForever('İzin kalıcı olarak reddedildi');

  const LocationAccess(this.label);

  /// Görünen ad.
  final String label;
}

/// GPS'ten gelen tek bir konum ölçümü.
typedef GpsFix = ({
  double latitude,
  double longitude,
  double accuracy,
  double altitude,
  double speed,
  double heading,
  DateTime time,
});

/// Konum kaynağı; testte sahtesi verilir.
abstract interface class LocationSource {
  /// Servisi ve izni kontrol eder, gerekirse izin ister (FUTURE).
  Future<LocationAccess> requestAccess();

  /// Canlı konum akışı (STREAM).
  Stream<GpsFix> positions();

  /// İzin / servis ayarlarını açar.
  Future<void> openSettings(LocationAccess access);
}

/// Telefonun GPS donanımını `geolocator` paketiyle kullanır.
class GeolocatorLocationSource implements LocationSource {
  @override
  Future<LocationAccess> requestAccess() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationAccess.serviceOff;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return switch (permission) {
      LocationPermission.always ||
      LocationPermission.whileInUse => LocationAccess.granted,
      LocationPermission.deniedForever => LocationAccess.deniedForever,
      _ => LocationAccess.denied,
    };
  }

  @override
  Stream<GpsFix> positions() {
    // Varsayılanlar: en yüksek doğruluk (LocationAccuracy.best) ve
    // distanceFilter 0 → yerinde dursanız da her ölçüm gelir.
    // Android'de ölçüm aralığını saniyede bire sabitliyoruz.
    final settings = defaultTargetPlatform == TargetPlatform.android
        ? AndroidSettings(intervalDuration: const Duration(seconds: 1))
        : const LocationSettings();
    return Geolocator.getPositionStream(locationSettings: settings).map(
      (p) => (
        latitude: p.latitude,
        longitude: p.longitude,
        accuracy: p.accuracy,
        altitude: p.altitude,
        speed: p.speed,
        heading: p.heading,
        // GPS zamanı UTC gelir; ekranda yerel saat (Türkiye UTC+3).
        time: p.timestamp.toLocal(),
      ),
    );
  }

  @override
  Future<void> openSettings(LocationAccess access) async {
    if (access == LocationAccess.serviceOff) {
      await Geolocator.openLocationSettings();
    } else {
      await Geolocator.openAppSettings();
    }
  }
}

/// İki konum arasındaki mesafe (metre), haversine formülüyle: Dünya'yı
/// küre sayıp iki nokta arasındaki yay uzunluğunu hesaplar.
double distanceMeters(double lat1, double lon1, double lat2, double lon2) {
  const earthRadius = 6371000.0;
  double rad(double deg) => deg * pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLon = rad(lon2 - lon1);
  final a =
      pow(sin(dLat / 2), 2) +
      cos(rad(lat1)) * cos(rad(lat2)) * pow(sin(dLon / 2), 2);
  return 2 * earthRadius * asin(sqrt(a));
}
