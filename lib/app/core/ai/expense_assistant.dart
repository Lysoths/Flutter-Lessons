import 'package:flutter_ders/app/core/ai/assistant_chat.dart';
import 'package:flutter_ders/app/core/ai/assistant_persona.dart';
import 'package:flutter_ders/app/core/ai/expense_toolbox.dart';

/// Bir kullanıcı mesajının sonucu.
final class AssistantAnswer {
  /// Oluşturur.
  const AssistantAnswer({
    required this.text,
    this.cards = const [],
    this.refused = false,
    this.toolsUsed = const [],
    this.sessionBroken = false,
  });

  /// Ekranda gösterilecek metin.
  final String text;

  /// Kayıt kartları (eklendi / düzeltildi / silindi).
  final List<RecordCard> cards;

  /// Konu dışı ret mi?
  final bool refused;

  /// Çağrılan araçlar (sırasıyla).
  final List<String> toolsUsed;

  /// Oturum geçmişi yarım kaldı; sonraki mesaj yeni oturumla başlamalı.
  final bool sessionBroken;
}

/// En çok kaç araç turu (model sonsuz döngüye girmesin).
const kMaxToolRounds = 5;

/// En uzun kullanıcı mesajı.
const kMaxMessageLength = 500;

/// Model ile araçları birleştiren döngü.
class ExpenseAssistant {
  /// Oluşturur.
  ExpenseAssistant({required this.chat, required this.toolbox});

  /// Oturum.
  final AssistantChat chat;

  /// Araçlar.
  final ExpenseToolbox toolbox;

  /// Mesajı gönderir; araç çağrılarını çalıştırıp son metni döndürür.
  Future<AssistantAnswer> ask(String message) async {
    final text = message.trim();
    final input = text.length > kMaxMessageLength
        ? text.substring(0, kMaxMessageLength)
        : text;
    var turn = await chat.sendText(input);
    final cards = <RecordCard>[];
    final used = <String>[];
    var refused = false;
    for (var round = 0; turn.calls.isNotEmpty; round++) {
      if (round >= kMaxToolRounds) {
        return AssistantAnswer(
          text: 'Bu isteği tamamlayamadım; daha kısa yazar mısın?',
          cards: cards,
          toolsUsed: used,
        );
      }
      final replies = <ToolReply>[];
      for (final call in turn.calls) {
        used.add(call.name);
        final out = await toolbox.run(call);
        if (out.card != null) cards.add(out.card!);
        refused = refused || out.refused;
        replies.add((call: call, response: out.response));
      }
      // Ret de modele söylenir; yoksa oturum geçmişi yarım kalır ve sonraki
      // mesaj hata verir. Modelin buna yazdığı metin gösterilmez.
      //
      // "Başka bir şey yazma" denen model rette çoğu zaman BOŞ bir yanıt
      // döner; SDK bunu çözerken hata verebilir. Rette o yanıta zaten
      // ihtiyaç yok: hata olursa ret yine gösterilir, oturum yenilenir.
      final onlyRefusal = turn.calls.every(
        (c) => c.name == AssistantTools.refuse,
      );
      try {
        turn = await chat.sendToolReplies(replies);
      } on Object {
        if (!onlyRefusal) rethrow;
        return AssistantAnswer(
          text: kRefusalText,
          refused: true,
          toolsUsed: used,
          sessionBroken: true,
        );
      }
    }
    if (refused && cards.isEmpty) {
      return AssistantAnswer(
        text: kRefusalText,
        refused: true,
        toolsUsed: used,
      );
    }
    final reply = turn.text?.trim() ?? '';
    return AssistantAnswer(
      text: reply.isEmpty && cards.isNotEmpty ? 'Tamam, kaydettim.' : reply,
      cards: cards,
      toolsUsed: used,
    );
  }
}
