import 'package:flutter/material.dart';
import 'package:flutter_ders/app/core/sms/bank_sms.dart';
import 'package:flutter_ders/app/helper/money_format.dart';
import 'package:flutter_ders/app/models/expense.dart';
import 'package:flutter_ders/app/theme/app_theme.dart';
import 'package:flutter_ders/app/views/view_bank_sms/cubit/bank_sms_cubit.dart';
import 'package:flutter_ders/app/widgets/common.dart';

String _two(int n) => n.toString().padLeft(2, '0');

/// Saat: `14:05`.
String formatClock(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';

/// İzin kartı: ne okunduğunu ve neyin yapılmadığını anlatır.
class SmsPermissionCard extends StatelessWidget {
  /// Oluşturur.
  const SmsPermissionCard({
    required this.onAllow,
    this.permanent = false,
    super.key,
  });

  /// Düğmeye basılınca.
  final VoidCallback onAllow;

  /// "Bir daha sorma" seçildiyse ayarlara yönlendirir.
  final bool permanent;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    const points = [
      (Icons.account_balance_rounded, "Yalnız banka adlarıyla gelen SMS'ler"),
      (Icons.lock_rounded, 'Doğrulama kodları gizlenir'),
      (Icons.cloud_off_rounded, 'Hiçbir yere gönderilmez, kaydedilmez'),
      (Icons.add_card_rounded, 'İstersen tek dokunuşla harcamaya eklenir'),
    ];
    return ListView(
      padding: pagePadding(context).copyWith(top: 24, bottom: 40),
      children: [
        const Center(child: IconBadge(Icons.sms_rounded, size: 64)),
        const Gap(16),
        Text(
          "Banka SMS'lerini okumak için izin gerekli",
          style: t.titleLarge,
          textAlign: TextAlign.center,
        ),
        const Gap(8),
        Text(
          permanent
              ? 'İzin "bir daha sorma" ile reddedildi. Ayarlar → İzinler → '
                    'SMS bölümünden açabilirsin.'
              : 'Android iki izin soracak: gelen kutusunu okuma ve ekran '
                    'açıkken yeni SMS geldiğini görme.',
          style: t.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const Gap(20),
        for (final (icon, text) in points)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Icon(icon, size: 20, color: MfColors.slate600),
                const SizedBox(width: 12),
                Expanded(child: Text(text, style: t.bodyMedium)),
              ],
            ),
          ),
        const Gap(16),
        FilledButton.icon(
          key: Key(permanent ? 'bankSms_settings' : 'bankSms_allow'),
          onPressed: onAllow,
          icon: Icon(permanent ? Icons.settings_rounded : Icons.check_rounded),
          label: Text(permanent ? 'Ayarları aç' : 'İzin ver'),
        ),
      ],
    );
  }
}

/// Ortalanmış kısa mesaj.
class SmsMessage extends StatelessWidget {
  /// Oluşturur.
  const SmsMessage({
    required this.icon,
    required this.text,
    this.action,
    this.onAction,
    super.key,
  });

  /// Simge.
  final IconData icon;

  /// Mesaj.
  final String text;

  /// Düğme yazısı.
  final String? action;

  /// Düğmeye basılınca.
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: MfColors.slate400),
            const Gap(10),
            Text(text, style: t.bodyMedium, textAlign: TextAlign.center),
            if (action != null) ...[
              const Gap(12),
              OutlinedButton(onPressed: onAction, child: Text(action!)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Bu ayın özeti: giden, gelen, SMS ve banka sayısı, dinleme durumu.
class SmsSummaryCard extends StatelessWidget {
  /// Oluşturur.
  const SmsSummaryCard({required this.state, required this.month, super.key});

  /// Ekran durumu.
  final BankSmsState state;

  /// Özetlenen ay.
  final DateTime month;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    Widget figure(String label, String value, Color color, Key key) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: t.labelMedium?.copyWith(color: MfColors.slate400)),
          const Gap(4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              key: key,
              style: t.titleLarge?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: MfColors.slate900,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${formatMonth(month)} · SMS özeti',
                  style: t.titleSmall?.copyWith(color: Colors.white),
                ),
              ),
              _LiveDot(listening: state.listening, count: state.liveCount),
            ],
          ),
          const Gap(14),
          Row(
            children: [
              figure(
                'Giden',
                formatMoney(state.spentIn(month)),
                const Color(0xFFFCA5A5),
                const Key('bankSms_spent'),
              ),
              const SizedBox(width: 12),
              figure(
                'Gelen',
                formatMoney(state.receivedIn(month)),
                const Color(0xFF6EE7B7),
                const Key('bankSms_received'),
              ),
            ],
          ),
          const Gap(12),
          Text(
            '${state.items.length} SMS · ${state.bankCount} banka · '
            'son ${state.days} gün',
            key: const Key('bankSms_counts'),
            style: t.bodySmall?.copyWith(color: MfColors.slate400),
          ),
        ],
      ),
    );
  }
}

class _LiveDot extends StatelessWidget {
  const _LiveDot({required this.listening, required this.count});

  final bool listening;
  final int count;

  @override
  Widget build(BuildContext context) {
    final color = listening ? MfColors.emerald500 : MfColors.slate500;
    return Container(
      key: const Key('bankSms_live'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            listening ? (count == 0 ? 'Dinleniyor' : '$count yeni') : 'Kapalı',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bankanın renkli baş harf simgesi.
class BankAvatar extends StatelessWidget {
  /// Oluşturur.
  const BankAvatar(this.bank, {this.size = 40, super.key});

  /// Banka.
  final BankInfo bank;

  /// Çap.
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = Color(bank.color);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(size / 3.2),
      ),
      child: Text(
        bank.name.characters.first,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.42,
        ),
      ),
    );
  }
}

/// Tutar metni ve rengi: çıkış kırmızı "−", giriş yeşil "+".
({String text, Color color}) amountLabel(BankSms sms) {
  if (sms.amount == null) return (text: '', color: MfColors.slate500);
  final value = sms.currency == 'TL'
      ? formatMoney(sms.amount!)
      : '${editableMoney(sms.amount!)} ${sms.currency}';
  if (sms.kind == BankSmsKind.info) {
    return (text: value, color: MfColors.slate600);
  }
  return sms.kind.outgoing
      ? (text: '−$value', color: MfColors.red600)
      : (text: '+$value', color: const Color(0xFF059669));
}

/// Listedeki bir banka SMS'i.
class BankSmsTile extends StatelessWidget {
  /// Oluşturur.
  const BankSmsTile({
    required this.sms,
    required this.recorded,
    required this.onTap,
    super.key,
  });

  /// SMS.
  final BankSms sms;

  /// Harcamaya eklenmiş mi?
  final bool recorded;

  /// Dokunulunca.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final amount = amountLabel(sms);
    final meta = [
      sms.bank.name,
      if (sms.cardLast4 != null) '•••• ${sms.cardLast4}',
      formatClock(sms.date),
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: sms.live ? MfColors.blue50 : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: MfColors.slate200),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: Key('bankSms_tile_${sms.date.millisecondsSinceEpoch}'),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
            child: Row(
              children: [
                BankAvatar(sms.bank),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (sms.kind == BankSmsKind.otp) ...[
                            const Icon(
                              Icons.lock_rounded,
                              size: 14,
                              color: MfColors.slate500,
                            ),
                            const SizedBox(width: 4),
                          ],
                          Flexible(
                            child: Text(
                              sms.title,
                              style: t.titleSmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (sms.live) ...[
                            const SizedBox(width: 6),
                            const Eyebrow('Yeni'),
                          ],
                        ],
                      ),
                      const Gap(2),
                      Text(
                        meta,
                        style: t.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      amount.text,
                      style: t.titleSmall?.copyWith(color: amount.color),
                    ),
                    if (recorded) ...[
                      const Gap(4),
                      const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            size: 13,
                            color: MfColors.emerald500,
                          ),
                          SizedBox(width: 3),
                          Text(
                            'Eklendi',
                            style: TextStyle(
                              fontSize: 11,
                              color: MfColors.emerald500,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ] else if (sms.kind != BankSmsKind.info &&
                        sms.kind != BankSmsKind.otp) ...[
                      const Gap(4),
                      Text(sms.kind.label, style: t.labelSmall),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Ayrıntı penceresinin sonucu.
sealed class SmsSheetAction {
  const SmsSheetAction();
}

/// Seçilen kategoriyle harcama olarak ekle.
final class RecordAction extends SmsSheetAction {
  /// Oluşturur.
  const RecordAction(this.category);

  /// Kategori.
  final ExpenseCategory category;
}

/// Eklenen harcamayı geri al.
final class UndoAction extends SmsSheetAction {
  /// Oluşturur.
  const UndoAction();
}

/// SMS ayrıntısı; harcamaya çevrilebiliyorsa kategori seçtirir.
class BankSmsDetailSheet extends StatefulWidget {
  /// Oluşturur.
  const BankSmsDetailSheet({
    required this.sms,
    required this.recorded,
    required this.initial,
    super.key,
  });

  /// SMS.
  final BankSms sms;

  /// Daha önce eklendi mi?
  final bool recorded;

  /// Tahmin edilen kategori.
  final ExpenseCategory initial;

  @override
  State<BankSmsDetailSheet> createState() => _BankSmsDetailSheetState();
}

class _BankSmsDetailSheetState extends State<BankSmsDetailSheet> {
  late ExpenseCategory _category = widget.initial;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final sms = widget.sms;
    final amount = amountLabel(sms);
    final facts = [
      ('Tür', sms.kind.label),
      if (sms.merchant != null) ('İşyeri', sms.merchant!),
      if (sms.cardLast4 != null) ('Kart', '•••• ${sms.cardLast4}'),
      ('Zaman', '${formatDate(sms.date)} ${formatClock(sms.date)}'),
      ('Gönderen', sms.raw.sender),
    ];
    return SingleChildScrollView(
      padding: pagePadding(context).copyWith(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              BankAvatar(sms.bank, size: 48),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(sms.bank.name, style: t.titleMedium),
                    if (amount.text.isNotEmpty)
                      Text(
                        amount.text,
                        style: t.headlineSmall?.copyWith(color: amount.color),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const Gap(16),
          for (final (label, value) in facts)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 84,
                    child: Text(
                      label,
                      style: t.bodySmall?.copyWith(color: MfColors.slate500),
                    ),
                  ),
                  Expanded(child: Text(value, style: t.bodyMedium)),
                ],
              ),
            ),
          const Gap(10),
          Container(
            key: const Key('bankSms_body'),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: MfColors.slate50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: MfColors.slate200),
            ),
            child: Text(sms.visibleBody, style: t.bodyMedium),
          ),
          if (widget.recorded) ...[
            const Gap(18),
            OutlinedButton.icon(
              key: const Key('bankSms_undo'),
              onPressed: () => Navigator.pop(context, const UndoAction()),
              icon: const Icon(Icons.undo_rounded),
              label: const Text('Harcamalardan çıkar'),
            ),
          ] else if (sms.recordable) ...[
            const Gap(18),
            Text('Kategori', style: t.labelLarge),
            const Gap(8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in ExpenseCategory.values)
                  ChoiceChip(
                    key: Key('bankSms_category_${c.name}'),
                    avatar: Icon(c.icon, size: 16),
                    label: Text(c.label),
                    selected: _category == c,
                    onSelected: (_) => setState(() => _category = c),
                  ),
              ],
            ),
            const Gap(14),
            FilledButton.icon(
              key: const Key('bankSms_record'),
              onPressed: () => Navigator.pop(context, RecordAction(_category)),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Harcama olarak ekle'),
            ),
          ] else if (sms.kind.canRecord && sms.currency != 'TL') ...[
            const Gap(14),
            Text(
              'Yabancı para harcaması; TL karşılığı belli olmadığı için '
              'eklenemiyor.',
              style: t.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}
