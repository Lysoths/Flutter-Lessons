import 'package:equatable/equatable.dart';
import 'package:flutter_ders/app/core/ai/assistant_persona.dart';
import 'package:flutter_ders/app/models/expense.dart';
import 'package:flutter_ders/app/views/view_expenses/cubit/expenses_cubit.dart';

// ─────────────────────────────────────────────────────────────────────────
// DERS 20 — Araçlar (function calling)
//
// Model veriye dokunamaz; yalnız "şu aracı şu değerlerle çağır" der. Aracı
// uygulama çalıştırır ve sonucu modele geri yollar. Bu yüzden modelden
// gelen her değer burada denetlenir: tutar aralığı, bilinen kategori,
// gelecekte olmayan tarih, kısa not. Geçersiz istek kaydedilmez, modele
// hatası söylenir.
// ─────────────────────────────────────────────────────────────────────────

/// Modelin istediği bir araç çağrısı.
final class ToolCall extends Equatable {
  /// Oluşturur.
  const ToolCall(this.name, this.args, {this.id});

  /// Araç adı.
  final String name;

  /// Değerler.
  final Map<String, Object?> args;

  /// Çağrı kimliği (modelin verdiği; yanıtta geri gider).
  final String? id;

  @override
  List<Object?> get props => [name, args, id];
}

/// Sohbette gösterilen kayıt kartının türü.
enum RecordChange {
  /// Eklendi.
  added,

  /// Düzeltildi.
  edited,

  /// Silindi.
  deleted,
}

/// Asistanın yaptığı değişiklik; "Geri al" bunu tersine çevirir.
final class RecordCard extends Equatable {
  /// Oluşturur.
  const RecordCard(this.change, this.expense, {this.before});

  /// Ne oldu.
  final RecordChange change;

  /// Son hali (silmede silinen kayıt).
  final Expense expense;

  /// Düzeltmeden önceki hali.
  final Expense? before;

  @override
  List<Object?> get props => [change, expense, before];
}

/// Bir aracın sonucu.
final class ToolOutcome {
  /// Oluşturur.
  const ToolOutcome(this.response, {this.card, this.refused = false});

  /// Modele dönen yanıt.
  final Map<String, Object?> response;

  /// Sohbet kartı.
  final RecordCard? card;

  /// Konu dışı ret mi?
  final bool refused;
}

/// En büyük tutar.
const kMaxAmount = 1000000.0;

/// En uzun not.
const kMaxNoteLength = 80;

/// Araçları [ExpensesCubit] üzerinde çalıştırır.
class ExpenseToolbox {
  /// Oluşturur.
  ExpenseToolbox(this._expenses, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final ExpensesCubit _expenses;
  final DateTime Function() _now;

  /// Bu sohbette asistanın en son eklediği / düzelttiği kayıt.
  String? _lastTouchedId;

  /// Çağrıyı çalıştırır. Bilinmeyen araç da hata olarak modele söylenir.
  Future<ToolOutcome> run(ToolCall call) async {
    try {
      return switch (call.name) {
        AssistantTools.add => await _add(call.args),
        AssistantTools.edit => await _edit(call.args),
        AssistantTools.delete => await _delete(),
        AssistantTools.summary => _summary(call.args),
        AssistantTools.refuse => const ToolOutcome({
          'durum': 'reddedildi',
        }, refused: true),
        _ => ToolOutcome({'hata': 'Bilinmeyen araç: ${call.name}'}),
      };
    } on FormatException catch (e) {
      return ToolOutcome({'hata': e.message});
    }
  }

  double _amount(Object? v) {
    final a = switch (v) {
      final num n => n.toDouble(),
      final String s => double.tryParse(s.replaceAll(',', '.')),
      _ => null,
    };
    if (a == null || a.isNaN || a <= 0 || a > kMaxAmount) {
      throw const FormatException(
        'Tutar 0 ile 1.000.000 ₺ arasında olmalı; kullanıcıya sor.',
      );
    }
    return (a * 100).roundToDouble() / 100;
  }

  ExpenseCategory _category(Object? v) {
    final name = kAssistantCategories[v];
    if (name == null) {
      throw FormatException(
        'Kategori şunlardan biri olmalı: ${kAssistantCategories.keys.join(', ')}',
      );
    }
    return ExpenseCategory.values.byName(name);
  }

  String _note(Object? v) {
    final s = (v is String ? v : '').trim().replaceAll(RegExp(r'\s+'), ' ');
    return s.length > kMaxNoteLength ? s.substring(0, kMaxNoteLength) : s;
  }

  DateTime _date(Object? v) {
    final now = _now();
    if (v is! String || v.trim().isEmpty) return now;
    final d = DateTime.tryParse(v.trim());
    if (d == null) {
      throw const FormatException('Tarih YYYY-AA-GG biçiminde olmalı.');
    }
    final day = DateTime(d.year, d.month, d.day);
    final today = DateTime(now.year, now.month, now.day);
    if (day.isAfter(today)) {
      throw const FormatException('Gelecek tarihli harcama kaydedilmez.');
    }
    if (today.difference(day).inDays > 730) {
      throw const FormatException('İki yıldan eski harcama kaydedilmez.');
    }
    // Bugünse şimdiki saat, değilse öğlen.
    return day == today ? now : day.add(const Duration(hours: 12));
  }

  Map<String, Object?> _describe(Expense e) => {
    'kimlik': e.id,
    'tutar': e.amount,
    'kategori': kAssistantCategories.entries
        .firstWhere((c) => c.value == e.category.name)
        .key,
    'not': e.note,
    'tarih': e.date.toIso8601String().substring(0, 10),
  };

  Future<ToolOutcome> _add(Map<String, Object?> a) async {
    final amount = _amount(a['tutar']);
    final category = _category(a['kategori']);
    final note = _note(a['not']);
    final date = _date(a['tarih']);
    final before = _expenses.state.expenses.map((e) => e.id).toSet();
    await _expenses.add(
      amount: amount,
      category: category,
      note: note,
      date: date,
    );
    final added = _expenses.state.expenses.firstWhere(
      (e) => !before.contains(e.id),
    );
    _lastTouchedId = added.id;
    return ToolOutcome({
      'durum': 'kaydedildi',
      ..._describe(added),
    }, card: RecordCard(RecordChange.added, added));
  }

  // Önce bu sohbette dokunulan kayıt, yoksa en yeni harcama.
  Expense? _target() {
    final list = _expenses.state.expenses;
    for (final e in list) {
      if (e.id == _lastTouchedId) return e;
    }
    return list.isEmpty ? null : list.first;
  }

  Future<ToolOutcome> _edit(Map<String, Object?> a) async {
    final target = _target();
    if (target == null) return const ToolOutcome({'hata': 'Kayıt yok.'});
    final updated = Expense(
      id: target.id,
      amount: a['tutar'] == null ? target.amount : _amount(a['tutar']),
      category: a['kategori'] == null
          ? target.category
          : _category(a['kategori']),
      date: a['tarih'] == null ? target.date : _date(a['tarih']),
      note: a['not'] == null ? target.note : _note(a['not']),
    );
    if (updated == target) {
      return const ToolOutcome({'hata': 'Değişecek alan verilmedi.'});
    }
    await _expenses.edit(updated);
    _lastTouchedId = updated.id;
    return ToolOutcome({
      'durum': 'duzeltildi',
      ..._describe(updated),
    }, card: RecordCard(RecordChange.edited, updated, before: target));
  }

  Future<ToolOutcome> _delete() async {
    final target = _target();
    if (target == null) return const ToolOutcome({'hata': 'Kayıt yok.'});
    await _expenses.remove(target.id);
    _lastTouchedId = null;
    return ToolOutcome({
      'durum': 'silindi',
      ..._describe(target),
    }, card: RecordCard(RecordChange.deleted, target));
  }

  /// Dönem özeti: yalnız sayılar gider, notlar gitmez.
  ToolOutcome _summary(Map<String, Object?> a) {
    final period = a['donem'] is String && kSummaryPeriods.contains(a['donem'])
        ? a['donem']! as String
        : 'bu_ay';
    final now = _now();
    final today = DateTime(now.year, now.month, now.day);
    final (from, to) = switch (period) {
      'gecen_ay' => (
        DateTime(now.year, now.month - 1),
        DateTime(now.year, now.month),
      ),
      'son_7_gun' => (
        today.subtract(const Duration(days: 6)),
        today.add(const Duration(days: 1)),
      ),
      'son_30_gun' => (
        today.subtract(const Duration(days: 29)),
        today.add(const Duration(days: 1)),
      ),
      'tum_zamanlar' => (DateTime(1970), today.add(const Duration(days: 1))),
      _ => (DateTime(now.year, now.month), today.add(const Duration(days: 1))),
    };
    final items = [
      for (final e in _expenses.state.expenses)
        if (!e.date.isBefore(from) && e.date.isBefore(to)) e,
    ];
    final total = items.fold<double>(0, (s, e) => s + e.amount);
    final byCategory = <String, ({double sum, int count})>{};
    for (final e in items) {
      final key = kAssistantCategories.entries
          .firstWhere((c) => c.value == e.category.name)
          .key;
      final c = byCategory[key] ?? (sum: 0.0, count: 0);
      byCategory[key] = (sum: c.sum + e.amount, count: c.count + 1);
    }
    final sorted = byCategory.entries.toList()
      ..sort((x, y) => y.value.sum.compareTo(x.value.sum));
    final days = to.difference(from).inDays.clamp(1, 100000);
    double r(double v) => (v * 100).roundToDouble() / 100;
    return ToolOutcome({
      'donem': period,
      'adet': items.length,
      'toplam': r(total),
      'gunluk_ortalama': period == 'tum_zamanlar' ? null : r(total / days),
      'kategoriler': [
        for (final c in sorted)
          {
            'kategori': c.key,
            'toplam': r(c.value.sum),
            'adet': c.value.count,
            'pay_yuzde': total == 0 ? 0 : (c.value.sum / total * 100).round(),
          },
      ],
    });
  }
}
