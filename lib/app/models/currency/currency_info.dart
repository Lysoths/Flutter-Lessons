/// DERS 15 — Takip edilen bir para birimi.
typedef CurrencyInfo = ({String code, String name, String flag});

/// Döviz ekranında takip edilen 10 para birimi.
const kTrackedCurrencies = <CurrencyInfo>[
  (code: 'USD', name: 'ABD doları', flag: '🇺🇸'),
  (code: 'EUR', name: 'Euro', flag: '🇪🇺'),
  (code: 'GBP', name: 'İngiliz sterlini', flag: '🇬🇧'),
  (code: 'CHF', name: 'İsviçre frangı', flag: '🇨🇭'),
  (code: 'JPY', name: 'Japon yeni', flag: '🇯🇵'),
  (code: 'CAD', name: 'Kanada doları', flag: '🇨🇦'),
  (code: 'AUD', name: 'Avustralya doları', flag: '🇦🇺'),
  (code: 'CNY', name: 'Çin yuanı', flag: '🇨🇳'),
  (code: 'SEK', name: 'İsveç kronu', flag: '🇸🇪'),
  (code: 'NOK', name: 'Norveç kronu', flag: '🇳🇴'),
];

/// Koda göre para birimi; yoksa ilk sıradaki (USD).
CurrencyInfo currencyInfo(String code) => kTrackedCurrencies.firstWhere(
  (c) => c.code == code,
  orElse: () => kTrackedCurrencies.first,
);

/// Kuru okunur yazar: 1 ₺ üstü 2, altı 4 ondalık (`41,23 ₺`, `0,3187 ₺`).
String formatTryRate(double value) {
  final digits = value >= 1 ? 2 : 4;
  final parts = value.toStringAsFixed(digits).split('.');
  final whole = parts[0].replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => '.',
  );
  return '$whole,${parts[1]} ₺';
}

/// Yüzde değişimi işaretiyle yazar: `+0,42 %`, `-1,10 %`.
String formatChange(double percent) {
  final sign = percent > 0 ? '+' : '';
  return '$sign${percent.toStringAsFixed(2).replaceAll('.', ',')} %';
}
