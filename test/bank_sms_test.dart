import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_ders/app/core/di/injection.dart';
import 'package:flutter_ders/app/core/repository/expense_repository.dart';
import 'package:flutter_ders/app/core/sms/bank_sms.dart';
import 'package:flutter_ders/app/core/sms/sms_source.dart';
import 'package:flutter_ders/app/models/expense.dart';
import 'package:flutter_ders/app/views/view_bank_sms/bank_sms_view.dart';
import 'package:flutter_ders/app/views/view_bank_sms/cubit/bank_sms_cubit.dart';
import 'package:flutter_ders/app/views/view_expenses/cubit/expenses_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryRepository implements ExpenseRepository {
  List<Expense> saved = [];

  @override
  Future<List<Expense>> getAll() async => [...saved];

  @override
  Future<void> saveAll(List<Expense> expenses) async => saved = [...expenses];
}

// Örnek SMS'ler uydurmadır; gerçek bankaların biçimine benzetildi.
final _today = () {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day, 9);
}();

RawSms _sms(String sender, String body, int minutes, [int? id]) => RawSms(
  id: id,
  sender: sender,
  body: body,
  date: _today.add(Duration(minutes: minutes)),
);

final _purchase = _sms(
  'GARANTI BBVA',
  "1234 ile biten kartinizla 05.11.2026 14:32'de MIGROS KADIKOY isyerinde "
      '1.250,75 TL tutarinda harcama yapilmistir. Kullanilabilir limit: '
      '8.749,25 TL',
  50,
  1,
);
final _incoming = _sms(
  'AKBANK',
  'Hesabiniza AHMET Y. tarafindan 500,00 TL FAST ile gonderildi.',
  40,
  2,
);
final _otp = _sms(
  'ISBANK',
  'Internet alisverisi icin tek kullanimlik sifreniz 482913. Kimseyle '
      'paylasmayin.',
  30,
  3,
);
final _foreign = _sms(
  'YAPIKREDI',
  '****5678 kartinizla AMAZON.COM isyerinde USD 49.99 harcama yapildi.',
  20,
  4,
);
final _bill = _sms(
  'TEB',
  'Turkcell faturaniz 349,90 TL otomatik odeme talimatinizla odenmistir.',
  10,
  5,
);
final _friend = _sms('+905551112233', 'Akşam yemeğe geliyor musun?', 5, 6);

final _inbox = [_purchase, _incoming, _otp, _foreign, _bill, _friend];

void main() {
  group('ayrıştırıcı', () {
    test('gönderen beyaz listesi', () {
      expect(bankOf('Garanti BBVA')?.name, 'Garanti BBVA');
      expect(bankOf('İŞBANK')?.name, 'İş Bankası');
      expect(bankOf('TEB')?.name, 'TEB');
      // Kısa anahtar başka adın içinde geçince banka sayılmaz.
      expect(bankOf('TEBLIGAT'), isNull);
      expect(bankOf('+905551112233'), isNull);
      expect(normalizeSender('Kuveyt Türk'), 'KUVEYTTURK');
    });

    test('bankaların sayı biçimleri', () {
      expect(BankSmsParser.parseBankNumber('1.234,56'), 1234.56);
      expect(BankSmsParser.parseBankNumber('1,234.56'), 1234.56);
      expect(BankSmsParser.parseBankNumber('1.250'), 1250);
      expect(BankSmsParser.parseBankNumber('99.90'), 99.9);
      expect(BankSmsParser.parseBankNumber('250'), 250);
    });

    test('kart harcaması: tutar, kart, işyeri, kategori', () {
      final s = BankSmsParser.parse(_purchase)!;
      expect(s.bank.name, 'Garanti BBVA');
      expect(s.kind, BankSmsKind.purchase);
      expect(s.amount, 1250.75);
      expect(s.currency, 'TL');
      expect(s.cardLast4, '1234');
      expect(s.merchant, 'MIGROS KADIKOY');
      expect(s.recordable, isTrue);
      expect(guessCategory(s), ExpenseCategory.food);
      expect(s.expenseNote, 'SMS · Garanti BBVA · MIGROS KADIKOY');
    });

    test('gelen para, fatura, yabancı para', () {
      final inc = BankSmsParser.parse(_incoming)!;
      expect(inc.kind, BankSmsKind.incoming);
      expect(inc.amount, 500);
      expect(inc.recordable, isFalse);

      final bill = BankSmsParser.parse(_bill)!;
      expect(bill.kind, BankSmsKind.bill);
      expect(bill.amount, 349.9);
      expect(guessCategory(bill), ExpenseCategory.bills);

      final usd = BankSmsParser.parse(_foreign)!;
      expect(usd.kind, BankSmsKind.purchase);
      expect(usd.currency, 'USD');
      expect(usd.amount, 49.99);
      expect(usd.cardLast4, '5678');
      expect(usd.merchant, 'AMAZON.COM');
      // TL karşılığı bilinmediği için harcamaya çevrilmez.
      expect(usd.recordable, isFalse);
    });

    test('doğrulama kodu: metin ve tutar gizli', () {
      final s = BankSmsParser.parse(_otp)!;
      expect(s.kind, BankSmsKind.otp);
      expect(s.amount, isNull);
      expect(s.visibleBody, isNot(contains('482913')));
      expect(s.recordable, isFalse);
    });

    // Telefonda görülen hata: Garanti'nin kredi kampanyası "Giden para"
    // sayılmıştı. Kampanyalar da "kredi", "havale", "hesabınıza", "TL"
    // içerir; işlem sayılmak için geçmiş zaman + tutar gerekir.
    group('kampanya ve bilgi SMSleri işlem sayılmaz', () {
      const campaigns = [
        "Size ozel 150.000 TL'ye varan Ihtiyac Kredisi! Garanti BBVA "
            "Mobil'den hemen basvurun, kredi tutari hesabiniza aninda "
            'aktarilsin. Havale/EFT/FAST ucretsiz. Ret icin RET yaz 3340',
        'Kredi kartinizla yapacaginiz 2.000 TL ve uzeri harcamalara 200 TL '
            'bonus! Kampanyaya katilmak icin KATIL yazip 4700e gonderin.',
        'Maasinizi bankamiza tasiyin, 15.000 TL promosyon hesabiniza '
            'yatirilsin. Detayli bilgi: garantibbva.com.tr',
        'Faizsiz 10.000 TL nakit avans firsati! Kartinizin sifresini '
            'kimseyle paylasmayin. Mersis: 0879001756600379',
        'Ekstreniz kesildi. Donem borcunuz 4.250,30 TL, son odeme tarihi '
            '15.11.2026.',
      ];
      for (final body in campaigns) {
        test(body.substring(0, 30), () {
          final s = BankSmsParser.parse(_sms('GARANTIBBVA', body, 1))!;
          expect(s.kind, BankSmsKind.info);
          expect(s.amount, isNull);
          expect(s.recordable, isFalse);
        });
      }
    });

    test('gerçek işlemler, altlıkta "şifre" geçse de', () {
      expect(
        BankSmsParser.kindOf(
          '1234 ile biten kartinizla 250,00 TL harcama yapilmistir. '
          'Sifrenizi kimseyle paylasmayin.',
        ),
        BankSmsKind.purchase,
      );
      expect(
        BankSmsParser.kindOf(
          'Hesabinizdan AYSE K. adina 1.000,00 TL FAST gonderilmistir.',
        ),
        BankSmsKind.transferOut,
      );
      expect(
        BankSmsParser.kindOf('ATM\'den 500 TL nakit cekilmistir.'),
        BankSmsKind.withdrawal,
      );
      expect(
        BankSmsParser.kindOf('MIGROS 120,00 TL iade edilmistir.'),
        BankSmsKind.refund,
      );
      expect(
        BankSmsParser.kindOf('Hesabiniza 3.500,00 TL EFT gelmistir.'),
        BankSmsKind.incoming,
      );
      // Kelime içinde geçen "eft" / "atm" işlem türü sayılmaz.
      expect(
        BankSmsParser.kindOf('Teftis sonucu 50 TL katma deger odenmistir.'),
        isNot(anyOf(BankSmsKind.transferOut, BankSmsKind.withdrawal)),
      );
    });

    test('doğrulama kodu ancak kod yanındaysa', () {
      expect(
        BankSmsParser.kindOf('Dogrulama kodunuz: 7731 . Kimseyle paylasmayin'),
        BankSmsKind.otp,
      );
      expect(
        BankSmsParser.kindOf('482913 tek kullanimlik sifrenizdir.'),
        BankSmsKind.otp,
      );
      expect(
        BankSmsParser.kindOf('Sifrenizi kimseyle paylasmayin. Iyi gunler.'),
        BankSmsKind.info,
      );
    });

    test('banka dışı SMS ve bozuk kanal verisi', () {
      expect(BankSmsParser.parse(_friend), isNull);
      expect(RawSms.fromChannel({'adres': 'AKBANK'}), isNull);
      expect(RawSms.fromChannel('x'), isNull);
      final ok = RawSms.fromChannel({
        'id': 7,
        'adres': 'AKBANK',
        'govde': 'Bilgi',
        'tarih': 0,
      })!;
      expect(ok.id, 7);
      expect(ok.date, DateTime.fromMillisecondsSinceEpoch(0));
    });
  });

  group('cubit', () {
    late MemorySmsSource source;
    late ExpensesCubit expenses;
    late BankSmsCubit cubit;

    setUp(() async {
      source = MemorySmsSource(messages: _inbox);
      expenses = ExpensesCubit(repository: _MemoryRepository());
      await expenses.load();
      cubit = BankSmsCubit(source: source, expenses: expenses);
    });

    tearDown(() async {
      await cubit.close();
      await expenses.close();
    });

    test('izin → gelen kutusu: yalnız banka SMSleri, yeniden eskiye', () async {
      await cubit.init();
      expect(cubit.state.status, BankSmsStatus.needsPermission);

      await cubit.requestAccess();
      expect(source.requests, 1);
      expect(cubit.state.status, BankSmsStatus.ready);
      expect(cubit.state.listening, isTrue);
      expect(cubit.state.items.map((s) => s.raw.id), [1, 2, 3, 4, 5]);
      expect(cubit.state.bankCount, 5);

      final month = DateTime(_today.year, _today.month);
      // Harcama + fatura; dolar harcaması toplama girmez.
      expect(cubit.state.spentIn(month), closeTo(1600.65, 0.001));
      expect(cubit.state.receivedIn(month), 500);
      // Bloc gözlemcisi durumu konsola yazar: SMS içeriği görünmemeli.
      final log = cubit.state.toString();
      expect(log, isNot(contains('MIGROS')));
      expect(log, isNot(contains('1250')));
      expect(log, contains('5 SMS'));
    });

    test('süzgeçler', () async {
      source.state = SmsAccess.granted;
      await cubit.init();
      cubit.setFilter(BankSmsFilter.incoming);
      expect(cubit.state.visible.map((s) => s.raw.id), [2]);
      cubit.setFilter(BankSmsFilter.spending);
      expect(cubit.state.visible.map((s) => s.raw.id), [1, 4, 5]);
      cubit.setFilter(BankSmsFilter.other);
      expect(cubit.state.visible.map((s) => s.raw.id), [3]);
    });

    test('anlık gelen SMS listeye düşer, yenileyince tekrarlanmaz', () async {
      source.state = SmsAccess.granted;
      await cubit.init();
      final live = _sms(
        'VAKIFBANK',
        'Kartinizla 75,00 TL harcama yapildi.',
        90,
      );
      source
        ..deliver(_sms('+905551112233', 'Merhaba', 91))
        ..deliver(live);
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.liveCount, 1);
      expect(cubit.state.items.first.live, isTrue);
      expect(cubit.state.items.first.amount, 75);

      await cubit.refresh();
      expect(
        cubit.state.items.where((s) => s.raw.key == live.key),
        hasLength(1),
      );
      expect(cubit.state.items.first.live, isTrue);
    });

    test('harcamaya ekle, ikinci kez eklenmez, geri al', () async {
      source.state = SmsAccess.granted;
      await cubit.init();
      final sms = cubit.state.items.firstWhere((s) => s.raw.id == 1);

      expect(await cubit.record(sms, ExpenseCategory.food), isTrue);
      final saved = expenses.state.expenses.single;
      expect(saved.amount, 1250.75);
      expect(saved.date, sms.date);
      expect(saved.note, contains('Garanti'));
      expect(cubit.recorded(sms), isTrue);
      expect(await cubit.record(sms, ExpenseCategory.food), isFalse);

      await cubit.undo(sms);
      expect(expenses.state.expenses, isEmpty);
      expect(cubit.recorded(sms), isFalse);

      // Gelen para harcamaya çevrilmez.
      final inc = cubit.state.items.firstWhere((s) => s.raw.id == 2);
      expect(await cubit.record(inc, ExpenseCategory.other), isFalse);
    });

    test('kalıcı ret → ayarlar', () async {
      source.afterRequest = SmsAccess.permanentlyDenied;
      await cubit.requestAccess();
      expect(cubit.state.status, BankSmsStatus.permanentlyDenied);
      await cubit.openSettings();
      expect(source.settingsOpened, 1);
    });
  });

  group('ekran', () {
    late MemorySmsSource source;
    late ExpensesCubit expenses;

    setUp(() async {
      await getIt.reset();
      source = MemorySmsSource(messages: _inbox);
      getIt.registerSingleton<SmsSource>(source);
      expenses = ExpensesCubit(repository: _MemoryRepository());
      await expenses.load();
    });

    tearDown(() async {
      await expenses.close();
      await getIt.reset();
    });

    Future<void> pumpView(WidgetTester tester) async {
      tester.view
        ..physicalSize = const Size(1440, 3120)
        ..devicePixelRatio = 3.75;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<ExpensesCubit>.value(
            value: expenses,
            child: const BankSmsView(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Finder tile(RawSms s) =>
        find.byKey(Key('bankSms_tile_${s.date.millisecondsSinceEpoch}'));

    testWidgets('izin ver → liste ve özet', (tester) async {
      await pumpView(tester);
      expect(find.byKey(const Key('bankSms_allow')), findsOneWidget);

      await tester.tap(find.byKey(const Key('bankSms_allow')));
      await tester.pumpAndSettle();
      expect(find.text('MIGROS KADIKOY'), findsOneWidget);
      expect(find.text('−1.250,75 ₺'), findsOneWidget);
      expect(find.text('+500,00 ₺'), findsOneWidget);
      expect(find.text('Akşam yemeğe geliyor musun?'), findsNothing);
      expect(
        tester.widget<Text>(find.byKey(const Key('bankSms_spent'))).data,
        '1.600,65 ₺',
      );
      expect(find.text('Dinleniyor'), findsOneWidget);

      await tester.tap(find.byKey(const Key('bankSms_filter_incoming')));
      await tester.pumpAndSettle();
      expect(find.text('MIGROS KADIKOY'), findsNothing);
      expect(find.text('+500,00 ₺'), findsOneWidget);
    });

    testWidgets('SMS ayrıntısından harcamaya ekle ve geri al', (tester) async {
      source.state = SmsAccess.granted;
      await pumpView(tester);

      await tester.tap(tile(_purchase));
      await tester.pumpAndSettle();
      // Kategori tahmini: market → Yemek.
      expect(
        tester
            .widget<ChoiceChip>(find.byKey(const Key('bankSms_category_food')))
            .selected,
        isTrue,
      );
      await tester.tap(find.byKey(const Key('bankSms_category_other')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('bankSms_record')));
      await tester.pumpAndSettle();

      expect(find.text('1.250,75 ₺ Diğer olarak eklendi.'), findsOneWidget);
      expect(expenses.state.expenses.single.category, ExpenseCategory.other);
      expect(find.text('Eklendi'), findsOneWidget);

      await tester.tap(find.text('Geri al'));
      await tester.pumpAndSettle();
      expect(expenses.state.expenses, isEmpty);
      expect(find.text('Eklendi'), findsNothing);
    });

    testWidgets('doğrulama kodu ekranda gösterilmez', (tester) async {
      source.state = SmsAccess.granted;
      await pumpView(tester);
      await tester.tap(tile(_otp));
      await tester.pumpAndSettle();
      expect(find.textContaining('482913'), findsNothing);
      expect(
        find.textContaining('güvenlik için gösterilmiyor'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('bankSms_record')), findsNothing);
    });

    testWidgets('ekran açıkken gelen SMS "Yeni" olarak görünür', (
      tester,
    ) async {
      source.state = SmsAccess.granted;
      await pumpView(tester);
      source.deliver(
        _sms(
          'ZIRAAT',
          'Kartinizla SHELL isyerinde 900,00 TL harcama yapildi.',
          120,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('SHELL'), findsOneWidget);
      expect(find.text('Yeni'), findsOneWidget);
      expect(find.text('1 yeni'), findsOneWidget);
    });
  });
}
