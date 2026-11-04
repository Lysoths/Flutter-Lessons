/// Süreyi okunur yazar: 1 ms altı mikrosaniye (`840 µs`), üstü
/// milisaniye (`12,34 ms`), 1 sn üstü saniye (`1,25 sn`).
String formatDuration(Duration d) {
  final us = d.inMicroseconds;
  if (us < 1000) return '$us µs';
  if (us < 1000000) return '${_decimal(us / 1000)} ms';
  return '${_decimal(us / 1000000)} sn';
}

/// Bayt sayısını okunur yazar: `512 B`, `12,3 KB`, `1,20 MB`, `3,45 GB`.
String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${_decimal(bytes / 1024, 1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${_decimal(bytes / (1024 * 1024))} MB';
  }
  return '${_decimal(bytes / (1024 * 1024 * 1024))} GB';
}

/// [count] kayıt [d] sürdüyse kayıt başına süre: `0,8 µs/kayıt`.
String formatPerItem(Duration d, int count) =>
    count == 0 ? '-' : '${_decimal(d.inMicroseconds / count, 1)} µs/kayıt';

/// [count] kayıt [d] sürdüyse saniyedeki kayıt sayısı: `~125.000/sn`.
String formatRate(Duration d, int count) {
  if (d.inMicroseconds == 0) return '-';
  final perSecond = (count / (d.inMicroseconds / 1000000)).round();
  final digits = perSecond.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => '.',
  );
  return '~$digits kayıt/sn';
}

String _decimal(double v, [int digits = 2]) =>
    v.toStringAsFixed(digits).replaceAll('.', ',');
