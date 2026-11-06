import 'package:equatable/equatable.dart';
import 'package:flutter_ders/app/models/expense.dart';

// ─────────────────────────────────────────────────────────────────────────
// DERS 21 — Banka SMS'lerini okumak (saf Dart kısmı)
//
// Kotlin tarafı yalnızca "ham SMS" verir: gönderen, metin, tarih. Hangi
// SMS'in bankadan geldiğini, içindeki tutarı, kart son dört hanesini ve
// işyerini bulmak bu dosyanın işidir. Eklenti bilmez; testte doğrudan
// metin verilerek denenir.
//
//   RawSms (kanaldan)  ──► BankSmsParser.parse ──► BankSms? (ekrana)
//                              │
//                              ├─ gönderen beyaz listede mi? (kBanks)
//                              ├─ tek kullanımlık şifre mi? → metin gizlenir
//                              ├─ tür: harcama / iade / gelen / giden / ...
//                              └─ tutar, kart, işyeri, kategori tahmini
//
// Hiçbir şey saklanmaz: ekran kapanınca liste bellekten gider.
// ─────────────────────────────────────────────────────────────────────────

/// Kanaldan gelen, henüz yorumlanmamış SMS.
final class RawSms extends Equatable {
  /// Oluşturur.
  const RawSms({
    required this.sender,
    required this.body,
    required this.date,
    this.id,
  });

  /// Kanal haritasından okur; eksik ya da bozuk alan varsa `null`.
  static RawSms? fromChannel(Object? value) {
    if (value is! Map) return null;
    final sender = value['adres'];
    final body = value['govde'];
    final ms = value['tarih'];
    if (sender is! String || body is! String || ms is! int) return null;
    final id = value['id'];
    return RawSms(
      id: id is int ? id : null,
      sender: sender,
      body: body,
      date: DateTime.fromMillisecondsSinceEpoch(ms),
    );
  }

  /// Gelen kutusundaki kimlik; anlık gelen SMS'te yoktur.
  final int? id;

  /// Gönderen (banka SMS'lerinde ad: "AKBANK", "GARANTIBBVA" ...).
  final String sender;

  /// Metin.
  final String body;

  /// Alınma zamanı.
  final DateTime date;

  /// Aynı SMS'i (gelen kutusu + anlık) bir kez göstermek için anahtar.
  String get key => '${normalizeSender(sender)}|${body.trim()}';

  @override
  List<Object?> get props => [id, sender, body, date];
}

/// Tanınan banka.
final class BankInfo {
  /// Oluşturur.
  const BankInfo(this.name, this.color, this.senders);

  /// Ekranda görünen ad.
  final String name;

  /// Simge rengi (ARGB).
  final int color;

  /// Gönderen adında aranan parçalar ([normalizeSender] biçiminde).
  final List<String> senders;
}

/// Gönderen adı beyaz listesi. Bankalar SMS'i kendi adlarıyla (alfanümerik
/// gönderen) yollar; bu liste dışındaki hiçbir SMS ekrana gelmez. Aynı
/// liste Kotlin tarafına da gider: banka dışı SMS kanaldan hiç geçmez.
const kBanks = <BankInfo>[
  BankInfo('Ziraat Bankası', 0xFFE30613, ['ZIRAAT']),
  BankInfo('İş Bankası', 0xFF0A4D9C, ['ISBANK', 'ISBANKASI', 'MAXIMUM']),
  BankInfo('Garanti BBVA', 0xFF00A650, ['GARANTI', 'BONUS']),
  BankInfo('Akbank', 0xFFE2001A, ['AKBANK', 'AXESS']),
  BankInfo('Yapı Kredi', 0xFF004B93, ['YAPIKREDI', 'WORLDCARD']),
  BankInfo('VakıfBank', 0xFFF9B000, ['VAKIFBANK', 'VAKIFBNK']),
  BankInfo('Halkbank', 0xFF005CA9, ['HALKBANK']),
  BankInfo('QNB', 0xFF5C2D91, ['QNB', 'FINANSBANK', 'ENPARA']),
  BankInfo('DenizBank', 0xFF003F87, ['DENIZBANK']),
  BankInfo('TEB', 0xFF00843D, ['TEB']),
  BankInfo('ING', 0xFFFF6200, ['INGBANK', 'ING']),
  BankInfo('Kuveyt Türk', 0xFF00704A, ['KUVEYTTURK']),
  BankInfo('Albaraka', 0xFF8C1D40, ['ALBARAKA']),
  BankInfo('Türkiye Finans', 0xFF0072BC, ['TFKB', 'TURKIYEFINANS']),
  BankInfo('Fibabanka', 0xFF00A0DF, ['FIBABANKA']),
  BankInfo('Şekerbank', 0xFF0D7A3E, ['SEKERBANK']),
  BankInfo('Odeabank', 0xFF6D2077, ['ODEABANK']),
  BankInfo('HSBC', 0xFFDB0011, ['HSBC']),
  BankInfo('Papara', 0xFF1A1A1A, ['PAPARA']),
];

/// Kotlin'e gönderilen anahtarların hepsi.
List<String> get kBankSenderKeys => [for (final b in kBanks) ...b.senders];

/// Gönderen adını karşılaştırılabilir yapar: büyük harf, Türkçe harfler
/// Latin karşılığına, harf ve rakam dışı her şey atılır.
/// `"Garanti BBVA"` → `GARANTIBBVA`. Kotlin tarafı da aynısını yapar.
String normalizeSender(String s) {
  const map = {
    'ç': 'C', 'Ç': 'C', 'ğ': 'G', 'Ğ': 'G', 'ı': 'I', 'İ': 'I', //
    'ö': 'O', 'Ö': 'O', 'ş': 'S', 'Ş': 'S', 'ü': 'U', 'Ü': 'U',
  };
  final b = StringBuffer();
  for (final ch in s.split('')) {
    final c = map[ch] ?? ch.toUpperCase();
    if (RegExp('[A-Z0-9]').hasMatch(c)) b.write(c);
  }
  return b.toString();
}

/// Gönderenin bankası; listede yoksa `null`.
///
/// Kısa anahtarlar ("ING", "TEB", "QNB") başka adların içinde de geçebilir
/// ("TEBLIGAT" gibi); bu yüzden 4 harften kısa olanlar yalnız tam eşleşir
/// ya da adın başında durur.
BankInfo? bankOf(String sender) {
  final s = normalizeSender(sender);
  if (s.isEmpty) return null;
  for (final bank in kBanks) {
    for (final key in bank.senders) {
      final hit = key.length < 4
          ? s == key || (s.startsWith(key) && s.length <= key.length + 4)
          : s.contains(key);
      if (hit) return bank;
    }
  }
  return null;
}

/// SMS'in türü.
enum BankSmsKind {
  /// Kartla harcama / alışveriş.
  purchase('Harcama', outgoing: true),

  /// ATM'den nakit çekim.
  withdrawal('Nakit çekim', outgoing: true),

  /// Giden havale / EFT / FAST.
  transferOut('Giden para', outgoing: true),

  /// Fatura ya da otomatik ödeme.
  bill('Fatura ödemesi', outgoing: true),

  /// Hesaba gelen para.
  incoming('Gelen para', outgoing: false),

  /// İade.
  refund('İade', outgoing: false),

  /// Tek kullanımlık şifre. Metni ekranda gösterilmez.
  otp('Doğrulama kodu', outgoing: false),

  /// Kampanya, ekstre, bilgi.
  info('Bilgi', outgoing: false);

  const BankSmsKind(this.label, {required this.outgoing});

  /// Ekrandaki ad.
  final String label;

  /// Hesaptan para çıkışı mı?
  final bool outgoing;

  /// "Harcama olarak ekle" düğmesi gösterilir mi?
  bool get canRecord => outgoing;
}

/// Yorumlanmış banka SMS'i.
final class BankSms extends Equatable {
  /// Oluşturur.
  const BankSms({
    required this.raw,
    required this.bank,
    required this.kind,
    this.amount,
    this.currency = 'TL',
    this.cardLast4,
    this.merchant,
    this.live = false,
  });

  /// Ham SMS.
  final RawSms raw;

  /// Banka.
  final BankInfo bank;

  /// Tür.
  final BankSmsKind kind;

  /// Tutar (bulunamadıysa `null`).
  final double? amount;

  /// Para birimi: TL, USD, EUR.
  final String currency;

  /// Kartın son dört hanesi.
  final String? cardLast4;

  /// İşyeri / alıcı.
  final String? merchant;

  /// Ekran açıkken anlık geldi mi?
  final bool live;

  /// Alınma zamanı.
  DateTime get date => raw.date;

  /// Ekranda gösterilecek metin; doğrulama kodlarında gizlidir.
  String get visibleBody => kind == BankSmsKind.otp
      ? 'Tek kullanımlık şifre içerir; güvenlik için gösterilmiyor.'
      : raw.body;

  /// Liste başlığı: işyeri, yoksa tür adı.
  String get title => merchant ?? kind.label;

  /// Harcamaya çevrilebilir mi? (TL, tutarı belli, para çıkışı)
  bool get recordable =>
      kind.canRecord && amount != null && amount! > 0 && currency == 'TL';

  /// Harcama kaydına yazılacak kısa not (en çok 80 karakter).
  String get expenseNote {
    final text = 'SMS · ${bank.name}${merchant == null ? '' : ' · $merchant'}';
    return text.length > 80 ? text.substring(0, 80) : text;
  }

  /// Anlık gelmiş olarak işaretlenmiş kopya.
  BankSms asLive() => BankSms(
    raw: raw,
    bank: bank,
    kind: kind,
    amount: amount,
    currency: currency,
    cardLast4: cardLast4,
    merchant: merchant,
    live: true,
  );

  @override
  List<Object?> get props => [raw, kind, amount, currency, cardLast4, live];
}

/// Banka SMS'i yorumlayıcısı.
abstract final class BankSmsParser {
  /// [sms] bankadan değilse `null`; bankadansa türü, tutarı ve ayrıntıları
  /// çıkarılmış hâli.
  static BankSms? parse(RawSms sms, {bool live = false}) {
    final bank = bankOf(sms.sender);
    if (bank == null) return null;
    final text = _fold(sms.body);
    final money = _amountOf(sms.body);
    final kind = classify(text, hasAmount: money != null);
    if (kind == BankSmsKind.otp || kind == BankSmsKind.info) {
      // Kampanya / bilgi SMS'indeki "100.000 TL'ye varan kredi" gibi
      // tutarlar işlem değildir; gösterilmez, toplama girmez.
      return BankSms(raw: sms, bank: bank, kind: kind, live: live);
    }
    return BankSms(
      raw: sms,
      bank: bank,
      kind: kind,
      amount: money?.amount,
      currency: money?.currency ?? 'TL',
      cardLast4: _cardOf(sms.body),
      merchant: kind == BankSmsKind.purchase || kind == BankSmsKind.refund
          ? _merchantOf(sms.body)
          : null,
      live: live,
    );
  }

  /// Küçük harf + Türkçe harfler Latin; anahtar kelime aramak için.
  /// Bankalar SMS'i bazen Türkçe karaktersiz yazar ("islem", "isyeri").
  static String _fold(String s) {
    const map = {
      'ç': 'c', 'Ç': 'c', 'ğ': 'g', 'Ğ': 'g', 'ı': 'i', 'İ': 'i', //
      'ö': 'o', 'Ö': 'o', 'ş': 's', 'Ş': 's', 'ü': 'u', 'Ü': 'u',
    };
    return s.split('').map((c) => map[c] ?? c.toLowerCase()).join();
  }

  // ── Sınıflandırma ──────────────────────────────────────────────────────
  //
  // Bankalar aynı gönderen adıyla hem işlem hem kampanya SMS'i yollar.
  // Kampanyada da "kredi", "havale", "hesabınıza", "TL" geçer:
  //   "Size özel 100.000 TL'ye varan krediniz hazır! Başvurun, tutar
  //    hesabınıza anında aktarılsın. Havale/EFT ücretsiz."
  // Bu yüzden anahtar kelime tek başına yetmez. Bir SMS'in işlem sayılması
  // için üç şart birlikte aranır:
  //   1. işlem türünü söyleyen bir kelime (harcama, havale, iade ...),
  //   2. işlemin GERÇEKLEŞTİĞİNİ söyleyen geçmiş zaman
  //      ("yapılmıştır", "gönderildi", "aktarılmıştır" — kampanyalar
  //      "yapacağınız", "aktarılsın", "başvurun" der),
  //   3. bir tutar.
  // Biri eksikse SMS "Bilgi"dir; tutarı gösterilmez, toplama girmez.
  //
  // Kelimeler kelime başında aranır: "eft" "teftiş"in, "atm" "katma"nın
  // içinde eşleşmesin. Kısa kelimelerin sonu da sınırlıdır.

  /// Doğrulama kodu kelimeleri. Yalnız yanında 4–8 haneli bir kod varsa
  /// sayılır: "şifrenizi kimseyle paylaşmayın" altlığı her SMS'te olabilir.
  static const _otpWords = [
    'sifre',
    'dogrulama kod',
    'onay kod',
    'tek kullanimlik',
    'guvenlik kod',
    '3d secure',
    'otp',
  ];

  /// İşlemin gerçekleştiğini söyleyen geçmiş zaman ekleri.
  static const _doneWords = [
    'yapilmistir',
    'yapildi',
    'gerceklesmistir',
    'gerceklesti',
    'gerceklestirilmistir',
    'gerceklestirildi',
    'gonderilmistir',
    'gonderildi',
    'gonderdi',
    'cekilmistir',
    'cekildi',
    'odenmistir',
    'odendi',
    'aktarilmistir',
    'aktarildi',
    'yatirilmistir',
    'yatirildi',
    'gelmistir',
    'tahsil edilmistir',
    'tahsil edildi',
    'onaylanmistir',
    'onaylandi',
    'iade edilmistir',
    'iade edildi',
    'provizyon alin',
    'harcamanizin',
  ];

  // Sıra önemli: iade metninde "harcama", gelen para metninde "havale"
  // de geçer; özelden genele doğru aranır.
  static const _rules = <(BankSmsKind, List<String>)>[
    (BankSmsKind.refund, ['iade']),
    (BankSmsKind.withdrawal, ['nakit cek', 'para cek', 'atm']),
    (
      BankSmsKind.incoming,
      [
        'hesabiniza',
        'gelen havale',
        'gelen eft',
        'gelen fast',
        'size gonderdi',
        'gonderdi',
        'yatirildi',
        'yatirilmistir',
      ],
    ),
    (
      BankSmsKind.transferOut,
      ['havale', 'eft', 'fast', 'transfer', 'gonderildi', 'gonderilmistir'],
    ),
    (BankSmsKind.bill, ['fatura', 'otomatik odeme', 'talimat']),
    (
      BankSmsKind.purchase,
      [
        'harcama',
        'alisveris',
        'isyeri',
        'islem',
        'provizyon',
        'odeme',
        'kartiniz',
      ],
    ),
  ];

  /// Sonu da sınırlı aranan kısa kelimeler.
  static const _shortWords = {'atm', 'eft', 'fast', 'otp'};

  static final _patterns = <String, RegExp>{};

  /// [word] katlanmış metinde kelime başında geçiyor mu?
  static bool _has(String folded, String word) =>
      _find(folded, word).isNotEmpty;

  static Iterable<RegExpMatch> _find(String folded, String word) {
    final p = _patterns.putIfAbsent(word, () {
      final tail = _shortWords.contains(word) ? '(?![a-z])' : '';
      return RegExp('(?<![a-z0-9])${RegExp.escape(word)}$tail');
    });
    return p.allMatches(folded);
  }

  // 4–8 haneli tek başına sayı: daha uzun sayının (MERSİS, telefon) parçası
  // ya da bir tutar ("1.250 TL") olmamalı. Cümle sonu noktası serbest.
  static final _code = RegExp(
    r'(?<![\d.,])\d{4,8}(?!\d|[.,]\d)(?!\s*(?:tl|try|₺))',
  );

  static bool _isOtp(String folded) {
    // Kodlar bütün metinde aranır (metni kesmek uzun bir sayıyı "kod"
    // parçasına çevirirdi); sonra kelimeye yakın olan var mı bakılır.
    final codes = _code.allMatches(folded).toList();
    if (codes.isEmpty) return false;
    for (final w in _otpWords) {
      for (final m in _find(folded, w)) {
        final near = codes.any(
          (c) => c.end >= m.start - 30 && c.start <= m.end + 40,
        );
        if (near) return true;
      }
    }
    return false;
  }

  /// Katlanmış (küçük harf, Türkçe harfsiz) metnin türü. Test edilebilsin
  /// diye açık.
  static BankSmsKind classify(String folded, {required bool hasAmount}) {
    final done = _doneWords.any((w) => _has(folded, w));
    // Tamamlanmış bir işlemin altlığındaki "şifrenizi paylaşmayın" OTP
    // sayılmaz; kod yanında olmalı.
    if (!done && _isOtp(folded)) return BankSmsKind.otp;
    if (!done || !hasAmount) return BankSmsKind.info;
    for (final (kind, words) in _rules) {
      if (words.any((w) => _has(folded, w))) return kind;
    }
    return BankSmsKind.info;
  }

  /// Ham metni sınıflandırır (testler ve hata ayıklama için).
  static BankSmsKind kindOf(String body) =>
      classify(_fold(body), hasAmount: _amountOf(body) != null);

  // Sayı: 1.234,56 · 1,234.56 · 250,00 · 250 · 99.90
  static const _num =
      r'\d{1,3}(?:[.,]\d{3})+(?:[.,]\d{1,2})?|\d+(?:[.,]\d{1,2})?';
  static final _amountAfter = RegExp(
    '($_num)\\s*(TL|TRY|₺|USD|EUR)(?![A-Za-z])',
    caseSensitive: false,
  );
  static final _amountBefore = RegExp(
    '(TL|TRY|₺|USD|EUR)\\s*($_num)',
    caseSensitive: false,
  );

  static ({double amount, String currency})? _amountOf(String body) {
    final after = _amountAfter.firstMatch(body);
    final before = _amountBefore.firstMatch(body);
    final useAfter =
        after != null && (before == null || after.start <= before.start);
    final String number;
    final String unit;
    if (useAfter) {
      number = after.group(1)!;
      unit = after.group(2)!;
    } else if (before != null) {
      number = before.group(2)!;
      unit = before.group(1)!;
    } else {
      return null;
    }
    final value = parseBankNumber(number);
    if (value == null) return null;
    final u = unit.toUpperCase();
    return (amount: value, currency: u == 'TRY' || u == '₺' ? 'TL' : u);
  }

  /// Bankaların yazdığı sayıyı okur. Son ayraçtan sonra 1–2 hane varsa o
  /// ayraç ondalıktır; 3 hane varsa binlik ayracıdır.
  /// `1.234,56` → 1234.56, `1,234.56` → 1234.56, `1.250` → 1250,
  /// `99.90` → 99.9.
  static double? parseBankNumber(String s) {
    final last = s.lastIndexOf(RegExp('[.,]'));
    if (last < 0) return double.tryParse(s);
    final tail = s.length - last - 1;
    final whole = s.substring(0, last).replaceAll(RegExp('[.,]'), '');
    final frac = s.substring(last + 1);
    return tail == 3
        ? double.tryParse('$whole$frac')
        : double.tryParse('$whole.$frac');
  }

  static final _cardPatterns = [
    RegExp(r'(\d{4})\s*(?:ile biten|ile sonlanan)', caseSensitive: false),
    RegExp(r'[*Xx•]{2,}[\s-]*(\d{4})\b'),
    RegExp(r'\b\d{4}[\s-]?\*{2,}[\s*-]*(\d{4})\b'),
  ];

  static String? _cardOf(String body) {
    for (final p in _cardPatterns) {
      final m = p.firstMatch(body);
      if (m != null) return m.group(1);
    }
    return null;
  }

  // "MIGROS KADIKOY isyerinde", "isyeri: MIGROS", "MIGROS'ta"
  static final _merchantPatterns = [
    RegExp(
      r"([A-ZÇĞİÖŞÜ0-9][A-ZÇĞİÖŞÜ0-9 .&'*/-]{1,40}?)\s+(?:isyerinde|isyerinden|işyerinde|işyerinden|uye isyerinde|üye işyerinde|magazasinda|mağazasında)",
    ),
    RegExp(
      r"(?:isyeri|işyeri|islem yeri|işlem yeri)\s*[:=]\s*([A-ZÇĞİÖŞÜ0-9][A-ZÇĞİÖŞÜ0-9 .&'*/-]{1,40})",
      caseSensitive: false,
    ),
  ];

  static String? _merchantOf(String body) {
    for (final p in _merchantPatterns) {
      final m = p.firstMatch(body);
      if (m == null) continue;
      final name = m
          .group(1)!
          .replaceAll(RegExp(r'\s+'), ' ')
          .replaceAll(RegExp(r'[\s.,:-]+$'), '')
          .trim();
      // Tarih ya da kart numarası işyeri sanılmasın.
      if (name.length < 2 || RegExp(r'^[\d\s./*-]+$').hasMatch(name)) {
        continue;
      }
      return name;
    }
    return null;
  }
}

/// İşyeri adına göre kategori tahmini; kullanıcı eklemeden önce değiştirir.
ExpenseCategory guessCategory(BankSms sms) {
  final text = BankSmsParser._fold('${sms.merchant ?? ''} ${sms.raw.body}');
  const rules = <(ExpenseCategory, List<String>)>[
    (
      ExpenseCategory.bills,
      [
        'fatura',
        'turkcell',
        'vodafone',
        'turk telekom',
        'enerjisa',
        'elektrik',
        'dogalgaz',
        'igdas',
        'iski',
        'superonline',
      ],
    ),
    (
      ExpenseCategory.transport,
      [
        'shell',
        'opet',
        'petrol',
        'akaryakit',
        'taksi',
        'uber',
        'bitaksi',
        'metro',
        'istanbulkart',
        'otopark',
        'pegasus',
        'thy',
        'ajet',
      ],
    ),
    (
      ExpenseCategory.fun,
      [
        'netflix',
        'spotify',
        'sinema',
        'cinema',
        'biletix',
        'steam',
        'youtube',
        'playstation',
        'disney',
      ],
    ),
    (
      ExpenseCategory.food,
      [
        'migros',
        'a101',
        'bim',
        'sok market',
        'carrefour',
        'getir',
        'yemeksepeti',
        'trendyol yemek',
        'restoran',
        'restaurant',
        'cafe',
        'kafe',
        'starbucks',
        'burger',
        'pizza',
        'firin',
        'market',
      ],
    ),
  ];
  for (final (category, words) in rules) {
    if (words.any(text.contains)) return category;
  }
  return ExpenseCategory.other;
}

/// Bu SMS'ten daha önce harcama oluşturulmuş mu? Hiçbir şey saklanmadığı
/// için kayıtlara bakılır: aynı tutar ve SMS'in tam zamanı.
bool isRecorded(BankSms sms, Iterable<Expense> expenses) =>
    sms.amount != null &&
    expenses.any((e) => e.amount == sms.amount && e.date == sms.date);
