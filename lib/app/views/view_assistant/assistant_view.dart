import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_ders/app/core/ai/assistant_persona.dart';
import 'package:flutter_ders/app/core/ai/expense_toolbox.dart';
import 'package:flutter_ders/app/helper/money_format.dart';
import 'package:flutter_ders/app/theme/app_theme.dart';
import 'package:flutter_ders/app/theme/category_style.dart';
import 'package:flutter_ders/app/views/view_assistant/cubit/assistant_chat_cubit.dart';
import 'package:flutter_ders/app/widgets/common.dart';

/// Örnek mesajlar.
const kAssistantSuggestions = [
  'Markete 250 lira verdim',
  'Dün taksiye 120 ₺ ödedim',
  'Bu ay ne kadar harcadım?',
  'Tasarruf önerin var mı?',
  'Son kaydı 150 yap',
];

/// DERS 20 — Firebase AI ile harcama asistanı (tam ekran).
///
/// Sohbet uygulama genelindeki [AssistantChatCubit]'tedir; sağdaki balon
/// ile bu ekran aynı konuşmayı gösterir.
@RoutePage()
class AssistantView extends StatelessWidget {
  /// Sayfayı oluşturur.
  const AssistantView({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            const AssistantAvatar(size: 34),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    kAssistantName,
                    style: t.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Harcama asistanı · Gemini',
                    style: t.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            key: const Key('assistant_reset'),
            tooltip: 'Yeni sohbet',
            onPressed: context.read<AssistantChatCubit>().reset,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: const AssistantConversation(),
    );
  }
}

/// Mesaj listesi (ya da tanıtım) ve yazma çubuğu. Tam ekranda ve balonun
/// panelinde aynı parça kullanılır.
class AssistantConversation extends StatefulWidget {
  /// Oluşturur.
  const AssistantConversation({super.key, this.autofocus = false});

  /// Açılınca klavye gelsin mi?
  final bool autofocus;

  @override
  State<AssistantConversation> createState() => _AssistantConversationState();
}

class _AssistantConversationState extends State<AssistantConversation> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _toBottom();
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send([String? text]) {
    final value = text ?? _input.text;
    if (value.trim().isEmpty) return;
    _input.clear();
    context.read<AssistantChatCubit>().send(value);
  }

  void _toBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted && _scroll.hasClients) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: BlocConsumer<AssistantChatCubit, AssistantChatState>(
            listener: (_, _) => _toBottom(),
            builder: (context, s) {
              if (s.messages.isEmpty) {
                return _Intro(onSuggestion: _send);
              }
              return ListView.builder(
                key: const Key('assistant_list'),
                controller: _scroll,
                padding: pagePadding(context).copyWith(top: 12, bottom: 12),
                itemCount: s.messages.length + (s.busy ? 1 : 0),
                itemBuilder: (context, i) => i == s.messages.length
                    ? const _Typing()
                    : _Bubble(index: i, message: s.messages[i]),
              );
            },
          ),
        ),
        _InputBar(
          controller: _input,
          onSend: _send,
          autofocus: widget.autofocus,
        ),
      ],
    );
  }
}

/// Asistanın simgesi (kumbara, turuncu degrade).
class AssistantAvatar extends StatelessWidget {
  /// Oluşturur.
  const AssistantAvatar({super.key, this.size = 40});

  /// Kenar uzunluğu.
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFFF59E0B), MfColors.claude],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(size / 3),
    ),
    child: Icon(Icons.savings_rounded, color: Colors.white, size: size * 0.55),
  );
}

class _Intro extends StatelessWidget {
  const _Intro({required this.onSuggestion});

  final ValueChanged<String> onSuggestion;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ListView(
      key: const Key('assistant_intro'),
      padding: pagePadding(context).copyWith(top: 16, bottom: 16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: MfColors.slate900,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const AssistantAvatar(size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Merhaba, ben $kAssistantName.',
                      style: t.titleMedium?.copyWith(color: Colors.white),
                    ),
                  ),
                ],
              ),
              const Gap(10),
              Text(
                'Masrafını yazman yeter; tutarını, kategorisini ve notunu '
                'çıkarıp kaydı ben oluştururum.',
                style: t.bodyMedium?.copyWith(color: MfColors.slate200),
              ),
              const Gap(12),
              for (final e in kAssistantExpertise)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 16,
                        color: MfColors.emerald500,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          e,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              const Gap(4),
              const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.block_rounded, size: 16, color: Color(0xFFF87171)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Harcama dışındaki sorulara yanıt vermem.',
                      style: TextStyle(color: MfColors.slate200),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Gap(16),
        Text('Şunları deneyebilirsin', style: t.titleSmall),
        const Gap(8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (i, s) in kAssistantSuggestions.indexed)
              ActionChip(
                key: Key('assistant_suggestion_$i'),
                label: Text(s),
                onPressed: () => onSuggestion(s),
              ),
          ],
        ),
        const Gap(16),
        Text(
          'Yazdıkların yanıt üretmek için Firebase üzerinden Gemini\'ye '
          'gider. Özet sorularında modele yalnız kategori toplamları '
          'gönderilir, harcama notların gönderilmez.',
          style: t.bodySmall,
        ),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.index, required this.message});

  final int index;
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final mine = message.role == ChatRole.user;
    final failed = message.failure != null;
    final bg = mine
        ? MfColors.blue600
        : failed
        ? const Color(0xFFFEF2F2)
        : message.refused
        ? const Color(0xFFFFFBEB)
        : Colors.white;
    final fg = mine ? Colors.white : MfColors.slate900;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: mine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!mine) ...[
            const AssistantAvatar(size: 28),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: mine
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Container(
                  key: Key('assistant_msg_$index'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(mine ? 18 : 4),
                      bottomRight: Radius.circular(mine ? 4 : 18),
                    ),
                    border: mine ? null : Border.all(color: MfColors.slate200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (message.refused) ...[
                        const Icon(
                          Icons.block_rounded,
                          size: 16,
                          color: Color(0xFFD97706),
                        ),
                        const SizedBox(width: 6),
                      ],
                      if (failed) ...[
                        const Icon(
                          Icons.error_outline_rounded,
                          size: 16,
                          color: MfColors.red600,
                        ),
                        const SizedBox(width: 6),
                      ],
                      Flexible(
                        child: SelectableText(
                          message.text,
                          style: TextStyle(color: fg, height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ),
                for (final (i, card) in message.cards.indexed)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: _RecordTile(
                      key: Key('assistant_card_${index}_$i'),
                      card: card,
                      undone: message.undone.contains(i),
                      onUndo: () =>
                          context.read<AssistantChatCubit>().undo(index, i),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({
    required this.card,
    required this.undone,
    required this.onUndo,
    super.key,
  });

  final RecordCard card;
  final bool undone;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final e = card.expense;
    final color = e.category.accent;
    final (label, icon) = switch (card.change) {
      RecordChange.added => ('Kaydedildi', Icons.add_task_rounded),
      RecordChange.edited => ('Düzeltildi', Icons.edit_rounded),
      RecordChange.deleted => ('Silindi', Icons.delete_outline_rounded),
    };
    final before = card.before;
    return Opacity(
      opacity: undone ? 0.5 : 1,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 340),
        padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(e.category.icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, size: 13, color: MfColors.slate500),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          undone ? '$label · geri alındı' : label,
                          overflow: TextOverflow.ellipsis,
                          style: t.labelSmall?.copyWith(
                            color: MfColors.slate500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${formatMoney(e.amount)} · ${e.category.label}',
                    style: t.titleSmall?.copyWith(
                      decoration: card.change == RecordChange.deleted
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  Text(
                    [
                      if (e.note.isNotEmpty) e.note,
                      formatDate(e.date),
                      if (before != null && before.amount != e.amount)
                        'önce ${formatMoney(before.amount)}',
                    ].join(' · '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodySmall,
                  ),
                ],
              ),
            ),
            if (!undone)
              TextButton(onPressed: onUndo, child: const Text('Geri al')),
          ],
        ),
      ),
    );
  }
}

class _Typing extends StatelessWidget {
  const _Typing();

  @override
  Widget build(BuildContext context) => const Padding(
    key: Key('assistant_typing'),
    padding: EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        AssistantAvatar(size: 28),
        SizedBox(width: 8),
        SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        SizedBox(width: 8),
        Text('Düşünüyor…'),
      ],
    ),
  );
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.onSend,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final busy = context.select<AssistantChatCubit, bool>((c) => c.state.busy);
    return Material(
      color: Colors.white,
      elevation: 6,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('assistant_input'),
                  controller: controller,
                  autofocus: autofocus,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: 500,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                  decoration: const InputDecoration(
                    hintText: 'Örn. “Kahveye 85 lira verdim”',
                    counterText: '',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton.filled(
                key: const Key('assistant_send'),
                onPressed: busy ? null : onSend,
                icon: const Icon(Icons.send_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
