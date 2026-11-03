import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_ders/app/views/view_expenses/cubit/expenses_cubit.dart';
import 'package:flutter_ders/app/views/view_expenses/widgets/expense_form_sheet.dart';

/// DERS 4 — auto_route: yeni harcama formu kendi başına bir rota.
///
/// Hem "Harcama ekle" düğmesi hem `harcamatakibim://app/yeni` linki bu
/// sayfayı açar. Kimse sonucunu beklemediği için kaydı kendisi yapar.
@RoutePage()
class NewExpenseView extends StatelessWidget {
  /// Formu oluşturur.
  const NewExpenseView({super.key});

  @override
  Widget build(BuildContext context) {
    return ExpenseFormSheet(
      onSaved: (saved) => context.read<ExpensesCubit>().add(
        amount: saved.amount,
        category: saved.category,
        date: saved.date,
        note: saved.note,
      ),
    );
  }
}
