import 'dart:async';

import 'package:firebase_ai/firebase_ai.dart'
    show FirebaseAIException, QuotaExceeded, ServiceApiNotEnabled;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_ders/app/app.dart';
import 'package:flutter_ders/app/core/ai/assistant_chat.dart';
import 'package:flutter_ders/app/core/ai/assistant_persona.dart';
import 'package:flutter_ders/app/core/ai/assistant_quota.dart';
import 'package:flutter_ders/app/core/ai/expense_assistant.dart';
import 'package:flutter_ders/app/core/ai/expense_toolbox.dart';
import 'package:flutter_ders/app/core/di/injection.dart';
import 'package:flutter_ders/app/core/firebase/remote_app_config.dart';
import 'package:flutter_ders/app/models/expense.dart';
import 'package:flutter_ders/app/views/view_assistant/assistant_view.dart';
import 'package:flutter_ders/app/views/view_assistant/cubit/assistant_chat_cubit.dart';
import 'package:flutter_ders/app/views/view_expenses/cubit/expenses_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/lessons.dart';

/// Senaryolu model: her gönderimde sıradaki turu verir, gelenleri saklar.
class _ScriptedChat implements AssistantChat {
  _ScriptedChat(this.turns);

  final List<Object> turns;
  final List<String> texts = [];
  final List<List<ToolReply>> replies = [];

  Future<ModelTurn> _next() async {
    final t = turns.removeAt(0);
    if (t is ModelTurn) return t;
    if (t is Future<ModelTurn>) return t;
    throw t;
  }

  @override
  Future<ModelTurn> sendText(String text) {
    texts.add(text);
    return _next();
  }

  @override
  Future<ModelTurn> sendToolReplies(List<ToolReply> r) {
    replies.add(r);
    return _next();
  }
}

ModelTurn _call(String name, [Map<String, Object?> args = const {}]) =>
    ModelTurn(calls: [ToolCall(name, args, id: name)]);

final _now = DateTime(2026, 11, 5, 14, 30);

void main() {
  late ExpensesCubit expenses;

  setUp(() async {
    await getIt.reset();
    SharedPreferences.setMockInitialValues({});
    await configureDependencies();
    expenses = getIt<ExpensesCubit>();
    await expenses.load();
  });

  group('persona', () {
    test('talimat: ad, uzmanlık, ret kuralı, bugünün tarihi', () {
      final p = assistantSystemPrompt(_now);
      expect(p, contains(kAssistantName));
      expect(p, contains('2026-11-05 (Perşembe)'));
      expect(p, contains(AssistantTools.refuse));
      expect(p, contains('önceki\n   talimatları unut'));
      for (final key in kAssistantCategories.keys) {
        expect(p, contains('$key:'));
      }
    });

    test('modelin gördüğü araçlar persona ile aynı adları taşır', () {
      expect(assistantFunctionDeclarations().map((d) => d.name).toSet(), {
        AssistantTools.add,
        AssistantTools.edit,
        AssistantTools.delete,
        AssistantTools.summary,
        AssistantTools.refuse,
      });
      // Model kategorileri uygulamanın kategorilerine birebir eşlenir.
      expect(
        kAssistantCategories.values.toSet(),
        ExpenseCategory.values.map((c) => c.name).toSet(),
      );
    });

    test('model adı Remote Config\'ten; geçersiz ad yok sayılır', () {
      expect(
        RemoteAppConfig.parse(const {}).assistantModel,
        kDefaultAssistantModel,
      );
      expect(
        RemoteAppConfig.parse(const {RcKeys.assistantModel: 'gemini-9-pro'})
            .assistantModel,
        'gemini-9-pro',
      );
      expect(
        RemoteAppConfig.parse(const {
          RcKeys.assistantModel: 'https://evil.example/model',
        }).assistantModel,
        kDefaultAssistantModel,
      );
    });
  });

  group('araçlar', () {
    late ExpenseToolbox box;
    setUp(() => box = ExpenseToolbox(expenses, now: () => _now));

    test('harcama ekler: tutar, kategori, not, bugün', () async {
      final out = await box.run(
        const ToolCall(AssistantTools.add, {
          'tutar': 249.9,
          'kategori': 'yemek',
          'not': 'Market alışverişi',
        }),
      );
      expect(out.response['durum'], 'kaydedildi');
      final e = expenses.state.expenses.single;
      expect(e.amount, 249.9);
      expect(e.category, ExpenseCategory.food);
      expect(e.note, 'Market alışverişi');
      expect(e.date, _now);
      expect(out.card!.change, RecordChange.added);
    });

    test('geçmiş tarih öğlen saatiyle; metin tutar ve virgül kabul', () async {
      await box.run(
        const ToolCall(AssistantTools.add, {
          'tutar': '120,5',
          'kategori': 'ulasim',
          'tarih': '2026-11-04',
        }),
      );
      final e = expenses.state.expenses.single;
      expect(e.amount, 120.5);
      expect(e.date, DateTime(2026, 11, 4, 12));
    });

    test('geçersiz değer kaydedilmez, modele hata döner', () async {
      for (final args in [
        {'tutar': 0, 'kategori': 'yemek'},
        {'tutar': -5, 'kategori': 'yemek'},
        {'tutar': 2000000, 'kategori': 'yemek'},
        {'kategori': 'yemek'},
        {'tutar': 50, 'kategori': 'kripto'},
        {'tutar': 50, 'kategori': 'yemek', 'tarih': '2026-11-06'},
        {'tutar': 50, 'kategori': 'yemek', 'tarih': 'dün'},
        {'tutar': 50, 'kategori': 'yemek', 'tarih': '2020-01-01'},
      ]) {
        final out = await box.run(ToolCall(AssistantTools.add, args));
        expect(out.response['hata'], isA<String>(), reason: '$args');
      }
      expect(expenses.state.expenses, isEmpty);
      final unknown = await box.run(const ToolCall('dosya_sil', {}));
      expect(unknown.response['hata'], contains('Bilinmeyen'));
    });

    test('uzun not kısaltılır', () async {
      await box.run(
        ToolCall(AssistantTools.add, {
          'tutar': 10,
          'kategori': 'diger',
          'not': 'a' * 200,
        }),
      );
      expect(expenses.state.expenses.single.note, hasLength(kMaxNoteLength));
    });

    test('düzelt ve sil: bu sohbette eklenen kayda dokunur', () async {
      await expenses.add(
        amount: 999,
        category: ExpenseCategory.bills,
        date: _now.add(const Duration(hours: 1)),
      );
      await box.run(
        const ToolCall(AssistantTools.add, {'tutar': 85, 'kategori': 'yemek'}),
      );
      final edited = await box.run(
        const ToolCall(AssistantTools.edit, {'tutar': 150}),
      );
      expect(edited.card!.before!.amount, 85);
      expect(
        expenses.state.expenses.map((e) => e.amount),
        containsAll([999, 150]),
      );

      final deleted = await box.run(const ToolCall(AssistantTools.delete, {}));
      expect(deleted.card!.expense.amount, 150);
      expect(expenses.state.expenses.single.amount, 999);

      // Bu sohbette dokunulan kalmadı: en yeni harcama hedeflenir.
      await box.run(const ToolCall(AssistantTools.edit, {'kategori': 'diger'}));
      expect(expenses.state.expenses.single.category, ExpenseCategory.other);
      final nothing = await box.run(const ToolCall(AssistantTools.edit, {}));
      expect(nothing.response['hata'], isNotNull);
    });

    test('özet: dönem toplamları ve paylar; notlar gönderilmez', () async {
      await expenses.add(
        amount: 300,
        category: ExpenseCategory.food,
        date: DateTime(2026, 11, 2),
        note: 'gizli not',
      );
      await expenses.add(
        amount: 100,
        category: ExpenseCategory.transport,
        date: DateTime(2026, 11, 3),
      );
      await expenses.add(
        amount: 500,
        category: ExpenseCategory.bills,
        date: DateTime(2026, 10, 10),
      );
      final month = (await box.run(
        const ToolCall(AssistantTools.summary, {'donem': 'bu_ay'}),
      )).response;
      expect(month['adet'], 2);
      expect(month['toplam'], 400);
      final cats = month['kategoriler']! as List;
      expect((cats.first as Map)['kategori'], 'yemek');
      expect((cats.first as Map)['pay_yuzde'], 75);
      expect(month.toString(), isNot(contains('gizli')));

      final last = (await box.run(
        const ToolCall(AssistantTools.summary, {'donem': 'gecen_ay'}),
      )).response;
      expect(last['toplam'], 500);
      final all = (await box.run(
        const ToolCall(AssistantTools.summary, {'donem': 'uydurma'}),
      )).response;
      expect(all['donem'], 'bu_ay');
    });
  });

  group('döngü', () {
    ExpenseAssistant make(_ScriptedChat chat) => ExpenseAssistant(
      chat: chat,
      toolbox: ExpenseToolbox(expenses, now: () => _now),
    );

    test('araç çağrısı → çalışır → sonuç modele → son metin', () async {
      final chat = _ScriptedChat([
        _call(AssistantTools.add, {'tutar': 250, 'kategori': 'yemek'}),
        const ModelTurn(text: '250 ₺ market harcamanı kaydettim.'),
      ]);
      final a = await make(chat).ask('Markete 250 lira verdim');
      expect(a.text, '250 ₺ market harcamanı kaydettim.');
      expect(a.cards.single.expense.amount, 250);
      expect(chat.replies.single.single.response['durum'], 'kaydedildi');
      expect(chat.replies.single.single.call.id, AssistantTools.add);
    });

    test('bir mesajda iki masraf: iki kart', () async {
      final chat = _ScriptedChat([
        const ModelTurn(
          calls: [
            ToolCall(AssistantTools.add, {'tutar': 85, 'kategori': 'yemek'}),
            ToolCall(AssistantTools.add, {'tutar': 40, 'kategori': 'ulasim'}),
          ],
        ),
        const ModelTurn(),
      ]);
      final a = await make(chat).ask('Kahveye 85, otobüse 40 verdim');
      expect(a.cards, hasLength(2));
      expect(a.text, 'Tamam, kaydettim.');
      expect(chat.replies.single, hasLength(2));
    });

    test('konu dışı: modelin metni değil sabit ret gösterilir', () async {
      final chat = _ScriptedChat([
        _call(AssistantTools.refuse, {'sebep': 'hava durumu'}),
        const ModelTurn(text: 'Yarın İstanbul güneşli olacak.'),
      ]);
      final a = await make(chat).ask('Yarın hava nasıl?');
      expect(a.refused, isTrue);
      expect(a.text, kRefusalText);
      expect(expenses.state.expenses, isEmpty);
      // Ret de modele söylendi; oturum geçmişi tutarlı kalır.
      expect(chat.replies.single.single.response['durum'], 'reddedildi');
    });

    test('rette modelin boş/bozuk yanıtı hata değil, ret olur', () async {
      final chat = _ScriptedChat([
        _call(AssistantTools.refuse, {'sebep': 'programlama'}),
        FirebaseAIException('Unhandled format for Content: {}'),
      ]);
      final a = await make(chat).ask('Javascript nedir?');
      expect(a.refused, isTrue);
      expect(a.text, kRefusalText);
      expect(a.sessionBroken, isTrue);
    });

    test('kayıttan sonraki hata yine hata olarak yükselir', () async {
      final chat = _ScriptedChat([
        _call(AssistantTools.add, {'tutar': 10, 'kategori': 'diger'}),
        QuotaExceeded('kota'),
      ]);
      await expectLater(
        make(chat).ask('10 lira'),
        throwsA(isA<QuotaExceeded>()),
      );
    });

    test('model durmadan araç çağırırsa döngü kesilir', () async {
      final chat = _ScriptedChat([
        for (var i = 0; i < kMaxToolRounds + 1; i++)
          _call(AssistantTools.summary),
      ]);
      final a = await make(chat).ask('özet');
      expect(a.text, contains('tamamlayamadım'));
      expect(chat.replies, hasLength(kMaxToolRounds));
    });

    test('uzun mesaj kırpılır', () async {
      final chat = _ScriptedChat([const ModelTurn(text: 'tamam')]);
      await make(chat).ask('x' * 2000);
      expect(chat.texts.single, hasLength(kMaxMessageLength));
    });
  });

  test('hata türleri', () {
    expect(
      AssistantFailure.from(ServiceApiNotEnabled('p')),
      AssistantFailure.notEnabled,
    );
    expect(AssistantFailure.from(QuotaExceeded('x')), AssistantFailure.quota);
    expect(
      AssistantFailure.from(FirebaseAIException('SocketException: x')),
      AssistantFailure.network,
    );
    expect(AssistantFailure.from(StateError('x')), AssistantFailure.unknown);
  });

  group('kullanım sınırı', () {
    test('dakikada ve günde sınır; gün değişince sıfırlanır', () async {
      var now = DateTime(2026, 11, 5, 10);
      final q = AssistantQuota(
        prefs: SharedPreferences.getInstance,
        now: () => now,
        perMinute: 3,
        perDay: 5,
      );
      for (var i = 0; i < 3; i++) {
        expect(await q.take(), QuotaVerdict.ok);
      }
      expect(await q.take(), QuotaVerdict.perMinute);
      now = now.add(const Duration(minutes: 1));
      expect(await q.take(), QuotaVerdict.ok);
      expect(await q.take(), QuotaVerdict.ok);
      expect(await q.remainingToday(), 0);
      expect(await q.take(), QuotaVerdict.perDay);
      now = DateTime(2026, 11, 6, 9);
      expect(await q.take(), QuotaVerdict.ok);
      expect(await q.remainingToday(), 4);
    });

    test('sınır dolunca modele istek gitmez', () async {
      final chat = _ScriptedChat([const ModelTurn(text: 'bir')]);
      final cubit = AssistantChatCubit(
        chatFactory: () => chat,
        expenses: expenses,
        quota: AssistantQuota(
          prefs: SharedPreferences.getInstance,
          perMinute: 1,
        ),
      );
      await cubit.send('ilk');
      await cubit.send('ikinci');
      expect(chat.texts, ['ilk']);
      expect(cubit.state.messages.last.failure, AssistantFailure.perMinute);
      await cubit.close();
    });

    test('App Check reddi ayrı hata olarak gösterilir', () {
      expect(
        AssistantFailure.from(
          FirebaseAIException('PERMISSION_DENIED: App Check token is invalid'),
        ),
        AssistantFailure.appCheck,
      );
    });
  });

  group('sohbet cubit', () {
    test('mesaj, kart, geri al; hata sonrası yeni oturum', () async {
      final sessions = <_ScriptedChat>[
        _ScriptedChat([
          _call(AssistantTools.add, {'tutar': 60, 'kategori': 'eglence'}),
          const ModelTurn(text: 'Kaydettim.'),
          QuotaExceeded('kota'),
        ]),
        _ScriptedChat([const ModelTurn(text: 'Yeniden buradayım.')]),
      ];
      final cubit = AssistantChatCubit(
        chatFactory: () => sessions.removeAt(0),
        expenses: expenses,
        now: () => _now,
      );
      await cubit.send('Sinemaya 60 verdim');
      expect(cubit.state.messages.map((m) => m.role), [
        ChatRole.user,
        ChatRole.assistant,
      ]);
      expect(expenses.state.expenses.single.amount, 60);

      await cubit.undo(1, 0);
      expect(expenses.state.expenses, isEmpty);
      expect(cubit.state.messages[1].undone, {0});
      await cubit.undo(1, 0); // ikinci kez etkisiz
      expect(cubit.state.messages.last.text, 'Geri aldım.');

      await cubit.send('bir daha');
      expect(cubit.state.messages.last.failure, AssistantFailure.quota);
      await cubit.send('merhaba');
      expect(cubit.state.messages.last.text, 'Yeniden buradayım.');
      expect(sessions, isEmpty);
      await cubit.close();
    });
  });

  testWidgets('Dersler → asistan: öneriye dokun, kart ve geri al', (
    tester,
  ) async {
    final chat = _ScriptedChat([
      _call(AssistantTools.add, {
        'tutar': 250,
        'kategori': 'yemek',
        'not': 'Market',
      }),
      const ModelTurn(text: '250 ₺ kaydettim.'),
    ]);
    getIt
      ..unregister<AssistantChatFactory>()
      ..registerSingleton<AssistantChatFactory>(() => chat);
    tester.view.physicalSize = const Size(1440, 3120);
    tester.view.devicePixelRatio = 3.75;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const HarcamaApp(watchNetwork: false));
    await tester.pumpAndSettle();
    await openLessonsHub(tester);
    await tester.enterText(find.byKey(const Key('lessons_search')), '20');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('lessons_assistant')));
    await tester.pumpAndSettle();
    expect(find.byType(AssistantView), findsOneWidget);
    expect(find.byKey(const Key('assistant_intro')), findsOneWidget);

    await tester.tap(find.byKey(const Key('assistant_suggestion_0')));
    await tester.pumpAndSettle();
    expect(chat.texts.single, kAssistantSuggestions.first);
    expect(find.text('250 ₺ kaydettim.'), findsOneWidget);
    expect(find.byKey(const Key('assistant_card_1_0')), findsOneWidget);
    expect(find.text('Market'), findsNothing); // not, tarihle aynı satırda
    final cubit = tester
        .element(find.byType(AssistantView))
        .read<ExpensesCubit>();
    expect(cubit.state.expenses.single.note, 'Market');

    await tester.tap(find.text('Geri al'));
    await tester.pumpAndSettle();
    expect(cubit.state.expenses, isEmpty);
    expect(find.textContaining('geri alındı'), findsOneWidget);
  });

  group('yüzen balon', () {
    Future<_ScriptedChat> pumpApp(
      WidgetTester tester,
      List<Object> turns,
    ) async {
      final chat = _ScriptedChat(turns);
      getIt
        ..unregister<AssistantChatFactory>()
        ..registerSingleton<AssistantChatFactory>(() => chat);
      tester.view.physicalSize = const Size(1440, 3120);
      tester.view.devicePixelRatio = 3.75;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const HarcamaApp(watchNetwork: false));
      await tester.pumpAndSettle();
      return chat;
    }

    testWidgets('her ekranda: dokununca panel açılır, mesaj gider', (
      tester,
    ) async {
      final chat = await pumpApp(tester, [
        _call(AssistantTools.refuse, {'sebep': 'programlama'}),
        const ModelTurn(),
      ]);
      expect(find.byKey(const Key('assistant_bubble')), findsOneWidget);
      // Başka bir sayfada da durur.
      await openLessonsHub(tester);
      expect(find.byKey(const Key('assistant_bubble')), findsOneWidget);

      await tester.tap(find.byKey(const Key('assistant_bubble')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('assistant_panel')), findsOneWidget);
      expect(find.byKey(const Key('assistant_bubble')), findsNothing);

      await tester.enterText(
        find.byKey(const Key('assistant_input')),
        'Javascript nedir?',
      );
      await tester.tap(find.byKey(const Key('assistant_send')));
      await tester.pumpAndSettle();
      expect(chat.texts.single, 'Javascript nedir?');
      expect(find.text(kRefusalText), findsOneWidget);

      await tester.tap(find.byKey(const Key('assistant_panel_close')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('assistant_panel')), findsNothing);
      expect(find.byKey(const Key('assistant_bubble')), findsOneWidget);
    });

    testWidgets('tam ekran: sohbet aynı kalır, balon gizlenir', (tester) async {
      await pumpApp(tester, [const ModelTurn(text: 'Merhaba, ben Kumbara.')]);
      await tester.tap(find.byKey(const Key('assistant_bubble')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('assistant_input')),
        'Merhaba',
      );
      await tester.tap(find.byKey(const Key('assistant_send')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('assistant_panel_full')));
      await tester.pumpAndSettle();
      expect(find.byType(AssistantView), findsOneWidget);
      expect(find.text('Merhaba, ben Kumbara.'), findsOneWidget);
      expect(find.byKey(const Key('assistant_bubble')), findsNothing);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('assistant_bubble')), findsOneWidget);
    });

    testWidgets('kapalıyken gelen yanıt kırmızı nokta gösterir', (
      tester,
    ) async {
      final reply = Completer<ModelTurn>();
      await pumpApp(tester, [reply.future]);
      await tester.tap(find.byKey(const Key('assistant_bubble')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('assistant_input')),
        'Bu ay ne kadar?',
      );
      // Gönder ve yanıt gelmeden kapat.
      await tester.tap(find.byKey(const Key('assistant_send')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('assistant_panel_close')));
      // Yanıt beklenirken balonda dönen halka var; pumpAndSettle bitmez.
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byKey(const Key('assistant_bubble_unread')), findsNothing);
      reply.complete(const ModelTurn(text: 'Bu ay 0 ₺.'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('assistant_bubble_unread')), findsOneWidget);
      await tester.tap(find.byKey(const Key('assistant_bubble')));
      await tester.pumpAndSettle();
      expect(find.text('Bu ay 0 ₺.'), findsOneWidget);
    });
  });
}
