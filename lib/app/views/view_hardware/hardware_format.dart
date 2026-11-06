import 'package:flutter_ders/app/core/hardware/hardware_profile.dart';

// Donanım ekranının saf biçimlendiricileri; widget bilmez, testte denenir.

String _dec(double v, [int digits = 1]) =>
    v.toStringAsFixed(digits).replaceAll('.', ',');

/// kHz → `3,53 GHz` ya da `960 MHz`.
String formatKhz(int khz) =>
    khz >= 1000000 ? '${_dec(khz / 1000000, 2)} GHz' : '${khz ~/ 1000} MHz';

/// Açık kalma süresi: `2 gün 4 sa`, `3 sa 12 dk`, `8 dk`.
String formatUptime(Duration d) {
  if (d.inDays > 0) return '${d.inDays} gün ${d.inHours % 24} sa';
  if (d.inHours > 0) return '${d.inHours} sa ${d.inMinutes % 60} dk';
  return '${d.inMinutes} dk';
}

/// µA → `-412 mA`.
String formatCurrent(int ua) => '${(ua / 1000).round()} mA';

/// Ondalık bir değer: `6,8"`, `120 Hz`.
String formatDecimal(double v, [int digits = 1]) {
  final rounded = v.roundToDouble();
  return (v - rounded).abs() < 0.05 ? '${rounded.toInt()}' : _dec(v, digits);
}

/// Çekirdek kümeleri: `2 × 4,47 GHz + 6 × 3,53 GHz`.
String formatClusters(CpuInfo cpu) {
  final c = cpu.clusters;
  if (c.isEmpty) return 'Okunamadı';
  return c.map((e) => '${e.count} × ${formatKhz(e.khz)}').join(' + ');
}

/// Android ID'yi gizler: `a1b2••••••••9f0e`.
String maskId(String id) => id.length <= 8
    ? '••••'
    : '${id.substring(0, 4)}••••••••${id.substring(id.length - 4)}';

/// Pil durumu.
String batteryStatusLabel(String s) => switch (s) {
  'sarj_oluyor' => 'Şarj oluyor',
  'dolu' => 'Dolu',
  'desarj' => 'Kullanılıyor',
  _ => 'Bilinmiyor',
};

/// Pil sağlığı.
String batteryHealthLabel(String s) => switch (s) {
  'iyi' => 'İyi',
  'asiri_isinma' => 'Aşırı ısınma',
  'olu' => 'Arızalı',
  'yuksek_voltaj' => 'Yüksek voltaj',
  'soguk' => 'Çok soğuk',
  _ => 'Bilinmiyor',
};

/// Şarj kaynağı.
String plugLabel(String? s) => switch (s) {
  'priz' => 'Priz',
  'usb' => 'USB',
  'kablosuz' => 'Kablosuz',
  _ => 'Takılı değil',
};

/// Kamera yönü.
String facingLabel(String s) => switch (s) {
  'on' => 'Ön',
  'arka' => 'Arka',
  _ => 'Harici',
};

/// Donanım özelliği adları (sırayla gösterilir).
const kFeatureLabels = <String, String>{
  'telefon': 'Telefon',
  'esim': 'eSIM',
  'nfc': 'NFC',
  'parmakIzi': 'Parmak izi',
  'yuzTanima': 'Yüz tanıma',
  'bluetoothLe': 'Bluetooth LE',
  'wifiDirect': 'Wi-Fi Direct',
  'wifiAware': 'Wi-Fi Aware',
  'uwb': 'UWB',
  'kizilotesi': 'Kızılötesi',
  'barometre': 'Barometre',
  'adimSayar': 'Adım sayar',
  'usbHost': 'USB host',
  'strongbox': 'StrongBox',
  'vulkan': 'Vulkan',
  'arCore': 'AR kamera',
};

/// IMEI denemesinin açıklaması.
String imeiExplanation(ImeiBlocked b) => switch (b.code) {
  'sistem_izni' =>
    'Android 10\'dan beri IMEI yalnız sistem ve operatör uygulamalarına '
        'verilir (READ_PRIVILEGED_PHONE_STATE). Kanal sordu, Android '
        'SecurityException ile reddetti${b.sdk == null ? '' : ' (API ${b.sdk})'}. '
        'IMEI\'yi görmek için tuş takımında *#06# yaz.',
  'telefon_yok' => 'Bu cihazda telefon donanımı yok.',
  'platform' => 'IMEI yalnız Android telefonda denenebilir.',
  _ => 'Android boş değer döndürdü.',
};
