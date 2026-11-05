import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_ders/app/core/ai/assistant_chat.dart';
import 'package:flutter_ders/app/core/ai/assistant_quota.dart';
import 'package:flutter_ders/app/core/ai/expense_assistant.dart';
import 'package:flutter_ders/app/core/ai/expense_toolbox.dart';
import 'package:flutter_ders/app/core/analytics/app_events.dart';
import 'package:flutter_ders/app/views/view_expenses/cubit/expenses_cubit.dart';

/// Kim yazdı.
enum ChatRole {
  /// Kullanıcı.
  user,

  /// Asistan.
  assistant,
}

/// Sohbetteki bir mesaj.
final class ChatMessage extends Equatable {
  /// Oluşturur.
  const ChatMessage({
    required this.role,
    required this.text,
    this.cards = const [],
    this.undone = const {},
    this.refused = false,
    this.failure,
  });

  /// Kim.
  final ChatRole role;

  /// Metin.
  final String text;

  /// Kayıt kartları.
  final List<RecordCard> cards;

  /// Geri alınan kartların sırası.
  final Set<int> undone;

  /// Konu dışı ret.
  final bool refused;

  /// Hata.
  final AssistantFailure? failure;

  /// Kopya.
  ChatMessage copyWith({Set<int>? undone}) => ChatMessage(
    role: role,
    text: text,
    cards: cards,
    undone: undone ?? this.undone,
    refused: refused,
    failure: failure,
  );

  @override
  List<Object?> get props => [role, text, cards, undone, refused, failure];
}

/// Sohbet durumu.
final class AssistantChatState extends Equatable {
  /// Oluşturur.
  const AssistantChatState({this.messages = const [], this.busy = false});

  /// Mesajlar (eskiden yeniye).
  final List<ChatMessage> messages;

  /// Yanıt bekleniyor mu?
  final bool busy;

  @override
  List<Object?> get props => [messages, busy];
}

/// Ders 20 — Sohbet ekranının ViewModel'i.
class AssistantChatCubit extends Cubit<AssistantChatState> {
  /// [expenses] uygulama genelindeki harcama cubit'idir; asistanın
  /// kayıtları ana sayfada hemen görünür.
  AssistantChatCubit({
    required this._chatFactory,
    required this._expenses,
    this._now,
    this._quota,
  }) : super(const AssistantChatState());

  final AssistantChatFactory _chatFactory;
  final ExpensesCubit _expenses;

  /// Uygulama içi kullanım sınırı (null: sınırsız, testler).
  final AssistantQuota? _quota;
  final DateTime Function()? _now;
  ExpenseAssistant? _assistant;

  ExpenseAssistant get _session => _assistant ??= ExpenseAssistant(
    chat: _chatFactory(),
    toolbox: ExpenseToolbox(_expenses, now: _now),
  );

  void _append(ChatMessage m) => emit(
    AssistantChatState(messages: [...state.messages, m], busy: state.busy),
  );

  /// Mesaj gönderir.
  Future<void> send(String text) async {
    final message = text.trim();
    if (message.isEmpty || state.busy) return;
    track(AppEvent.assistantSent);
    emit(
      AssistantChatState(
        messages: [
          ...state.messages,
          ChatMessage(role: ChatRole.user, text: message),
        ],
        busy: true,
      ),
    );
    final verdict = await _quota?.take() ?? QuotaVerdict.ok;
    if (verdict != QuotaVerdict.ok) {
      final failure = verdict == QuotaVerdict.perMinute
          ? AssistantFailure.perMinute
          : AssistantFailure.perDay;
      track(AppEvent.assistantFailed, failure.code);
      if (isClosed) return;
      emit(
        AssistantChatState(
          messages: [
            ...state.messages,
            ChatMessage(
              role: ChatRole.assistant,
              text: failure.message,
              failure: failure,
            ),
          ],
        ),
      );
      return;
    }
    try {
      final answer = await _session.ask(message);
      if (isClosed) return;
      if (answer.refused) track(AppEvent.assistantRefused);
      if (answer.sessionBroken) _assistant = null;
      for (final c in answer.cards) {
        track(AppEvent.assistantRecorded, c.change.name);
      }
      emit(
        AssistantChatState(
          messages: [
            ...state.messages,
            ChatMessage(
              role: ChatRole.assistant,
              text: answer.text.isEmpty
                  ? 'Anlayamadım; masrafı tutarıyla yazar mısın?'
                  : answer.text,
              cards: answer.cards,
              refused: answer.refused,
            ),
          ],
        ),
      );
    } on Object catch (e) {
      if (isClosed) return;
      final failure = AssistantFailure.from(e);
      // Yalnız hatanın türü ve SDK iletisi; kullanıcının mesajı yazılmaz.
      final detail = '$e';
      debugPrint(
        'Asistan hatası (${failure.code}): ${e.runtimeType}: '
        '${detail.length > 300 ? detail.substring(0, 300) : detail}',
      );
      track(AppEvent.assistantFailed, failure.code);
      // Yarım kalan tur oturum geçmişini bozabilir; sonraki mesaj yeni
      // oturumla başlar.
      _assistant = null;
      emit(
        AssistantChatState(
          messages: [
            ...state.messages,
            ChatMessage(
              role: ChatRole.assistant,
              text: failure.message,
              failure: failure,
            ),
          ],
        ),
      );
    }
  }

  /// [messageIndex]. mesajın [cardIndex]. kartını geri alır.
  Future<void> undo(int messageIndex, int cardIndex) async {
    final m = state.messages[messageIndex];
    if (m.undone.contains(cardIndex)) return;
    final card = m.cards[cardIndex];
    track(AppEvent.assistantUndone, card.change.name);
    switch (card.change) {
      case RecordChange.added:
        await _expenses.remove(card.expense.id);
      case RecordChange.edited:
        await _expenses.edit(card.before!);
      case RecordChange.deleted:
        await _expenses.restore(card.expense);
    }
    if (isClosed) return;
    final messages = [...state.messages];
    messages[messageIndex] = m.copyWith(undone: {...m.undone, cardIndex});
    emit(AssistantChatState(messages: messages, busy: state.busy));
    _append(const ChatMessage(role: ChatRole.assistant, text: 'Geri aldım.'));
  }

  /// Sohbeti sıfırlar (model geçmişi de).
  void reset() {
    track(AppEvent.assistantReset);
    _assistant = null;
    emit(const AssistantChatState());
  }
}
