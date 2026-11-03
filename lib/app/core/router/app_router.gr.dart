// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AutoRouterGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

part of 'app_router.dart';

/// generated route for
/// [CategoryExpensesView]
class CategoryExpensesRoute extends PageRouteInfo<CategoryExpensesRouteArgs> {
  CategoryExpensesRoute({
    required String slug,
    Key? key,
    List<PageRouteInfo>? children,
  }) : super(
         CategoryExpensesRoute.name,
         args: CategoryExpensesRouteArgs(slug: slug, key: key),
         rawPathParams: {'slug': slug},
         initialChildren: children,
       );

  static const String name = 'CategoryExpensesRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final pathParams = data.inheritedPathParams;
      final args = data.argsAs<CategoryExpensesRouteArgs>(
        orElse: () =>
            CategoryExpensesRouteArgs(slug: pathParams.getString('slug')),
      );
      return CategoryExpensesView(slug: args.slug, key: args.key);
    },
  );
}

class CategoryExpensesRouteArgs {
  const CategoryExpensesRouteArgs({required this.slug, this.key});

  final String slug;

  final Key? key;

  @override
  String toString() {
    return 'CategoryExpensesRouteArgs{slug: $slug, key: $key}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! CategoryExpensesRouteArgs) return false;
    return slug == other.slug && key == other.key;
  }

  @override
  int get hashCode => slug.hashCode ^ key.hashCode;
}

/// generated route for
/// [ExpenseDetailView]
class ExpenseDetailRoute extends PageRouteInfo<ExpenseDetailRouteArgs> {
  ExpenseDetailRoute({
    required Expense expense,
    Key? key,
    List<PageRouteInfo>? children,
  }) : super(
         ExpenseDetailRoute.name,
         args: ExpenseDetailRouteArgs(expense: expense, key: key),
         initialChildren: children,
       );

  static const String name = 'ExpenseDetailRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<ExpenseDetailRouteArgs>();
      return ExpenseDetailView(expense: args.expense, key: args.key);
    },
  );
}

class ExpenseDetailRouteArgs {
  const ExpenseDetailRouteArgs({required this.expense, this.key});

  final Expense expense;

  final Key? key;

  @override
  String toString() {
    return 'ExpenseDetailRouteArgs{expense: $expense, key: $key}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ExpenseDetailRouteArgs) return false;
    return expense == other.expense && key == other.key;
  }

  @override
  int get hashCode => expense.hashCode ^ key.hashCode;
}

/// generated route for
/// [ExpensesView]
class ExpensesRoute extends PageRouteInfo<void> {
  const ExpensesRoute({List<PageRouteInfo>? children})
    : super(ExpensesRoute.name, initialChildren: children);

  static const String name = 'ExpensesRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const ExpensesView();
    },
  );
}

/// generated route for
/// [NewExpenseView]
class NewExpenseRoute extends PageRouteInfo<void> {
  const NewExpenseRoute({List<PageRouteInfo>? children})
    : super(NewExpenseRoute.name, initialChildren: children);

  static const String name = 'NewExpenseRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const NewExpenseView();
    },
  );
}
