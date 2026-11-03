import 'dart:convert';

import 'package:flutter_ders/app/core/repository/expense_repository.dart';
import 'package:flutter_ders/app/models/expense.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Harcamaları telefon hafızasında JSON metni olarak saklar.
class LocalExpenseRepository implements ExpenseRepository {
  /// [SharedPreferences] ile bir depo oluşturur.
  LocalExpenseRepository(this._prefs);

  /// Kaydın tutulduğu anahtar.
  static const storageKey = 'expenses';

  final SharedPreferences _prefs;

  @override
  Future<List<Expense>> getAll() async {
    final raw = _prefs.getString(storageKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<Object?>;
    return [
      for (final item in list) Expense.fromJson(item! as Map<String, Object?>),
    ];
  }

  @override
  Future<void> saveAll(List<Expense> expenses) async {
    final raw = jsonEncode([for (final e in expenses) e.toJson()]);
    await _prefs.setString(storageKey, raw);
  }
}
