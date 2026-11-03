import 'package:flutter/material.dart';
import 'package:flutter_ders/app/models/expense.dart';
import 'package:flutter_ders/app/theme/app_theme.dart';

/// Her kategorinin vurgu rengi.
extension ExpenseCategoryStyle on ExpenseCategory {
  /// Kategori vurgu rengi.
  Color get accent => switch (this) {
    ExpenseCategory.food => const Color(0xFFF97316),
    ExpenseCategory.transport => MfColors.blue600,
    ExpenseCategory.bills => const Color(0xFF8B5CF6),
    ExpenseCategory.fun => const Color(0xFFEC4899),
    ExpenseCategory.other => MfColors.emerald500,
  };
}
