import 'package:sensors_plus/sensors_plus.dart';

// ─────────────────────────────────────────────────────────────────────────
// DERS 12 — Hareket sensörleri
//
// Her sensör üç eksende (x, y, z) sayı üretir ve bunları bir STREAM olarak
// verir; saniyede onlarca kez. Eksenler telefona göredir:
//   x → ekranın sağı, y → ekranın üstü, z → ekrandan size doğru.
//
//   İvmeölçer        m/s²   yerçekimi DAHİL ivme (telefon düzken z ≈ 9,8)
//   Kullanıcı ivmesi m/s²   yerçekimi ÇIKARILMIŞ ivme (sallama için)
//   Jiroskop         rad/s  eksenler etrafında dönüş hızı
//   Manyetometre     µT     manyetik alan (pusula için)
// ─────────────────────────────────────────────────────────────────────────

/// Bir sensör ölçümü.
typedef SensorReading = ({double x, double y, double z, DateTime time});

/// Sensör kaynağı; testte sahtesi verilir.
abstract interface class SensorSource {
  /// İvmeölçer (yerçekimi dahil).
  Stream<SensorReading> accelerometer();

  /// Kullanıcı ivmesi (yerçekimi hariç).
  Stream<SensorReading> userAccelerometer();

  /// Jiroskop.
  Stream<SensorReading> gyroscope();

  /// Manyetometre.
  Stream<SensorReading> magnetometer();
}

/// Telefonun sensörlerini `sensors_plus` paketiyle kullanır.
class DeviceSensorSource implements SensorSource {
  /// Ekran için yeterli hız (≈ 60 Hz).
  static const _period = SensorInterval.uiInterval;

  @override
  Stream<SensorReading> accelerometer() =>
      accelerometerEventStream(samplingPeriod: _period)
          .map((e) => (x: e.x, y: e.y, z: e.z, time: e.timestamp));

  @override
  Stream<SensorReading> userAccelerometer() =>
      userAccelerometerEventStream(samplingPeriod: _period)
          .map((e) => (x: e.x, y: e.y, z: e.z, time: e.timestamp));

  @override
  Stream<SensorReading> gyroscope() =>
      gyroscopeEventStream(samplingPeriod: _period)
          .map((e) => (x: e.x, y: e.y, z: e.z, time: e.timestamp));

  @override
  Stream<SensorReading> magnetometer() =>
      magnetometerEventStream(samplingPeriod: _period)
          .map((e) => (x: e.x, y: e.y, z: e.z, time: e.timestamp));
}
