import 'package:flutter/material.dart' show DateUtils;

/// Tutarı Türkçe biçimde yazar: `1234.5` -> `1.234,50 ₺`.
String formatMoney(double amount) {
  final fixed = amount.abs().toStringAsFixed(2);
  final parts = fixed.split('.');
  final whole = parts[0].replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => '.',
  );
  return '${amount < 0 ? '-' : ''}$whole,${parts[1]} ₺';
}

/// Tutarı form alanına yazılacak biçimde verir: `12.5` -> `12,50`.
String editableMoney(double amount) =>
    amount.toStringAsFixed(2).replaceAll('.', ',');

/// Kullanıcının yazdığı tutarı okur (`12,5` veya `12.5`); geçersizse `null`.
double? parseMoney(String input) {
  final value = double.tryParse(input.trim().replaceAll(',', '.'));
  if (value == null || value <= 0) return null;
  return value;
}

/// Tarihi `gg.aa.yyyy` biçiminde yazar.
String formatDate(DateTime date) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(date.day)}.${two(date.month)}.${date.year}';
}

const _months = [
  'Ocak',
  'Şubat',
  'Mart',
  'Nisan',
  'Mayıs',
  'Haziran',
  'Temmuz',
  'Ağustos',
  'Eylül',
  'Ekim',
  'Kasım',
  'Aralık',
];

/// Ay adını ve yılı yazar: `Kasım 2026`.
String formatMonth(DateTime date) => '${_months[date.month - 1]} ${date.year}';

/// Liste gruplarının başlığı: `Bugün`, `Dün` ya da `2 Kasım 2026`.
String formatDayLabel(DateTime date, {DateTime? now}) {
  final today = DateUtils.dateOnly(now ?? DateTime.now());
  final day = DateUtils.dateOnly(date);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Bugün';
  if (diff == 1) return 'Dün';
  return '${date.day} ${_months[date.month - 1]} ${date.year}';
}
