// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AutoRouterGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

part of 'app_router.dart';

/// generated route for
/// [AudioPlayerView]
class AudioPlayerRoute extends PageRouteInfo<AudioPlayerRouteArgs> {
  AudioPlayerRoute({
    required DocumentItem document,
    Key? key,
    List<PageRouteInfo>? children,
  }) : super(
         AudioPlayerRoute.name,
         args: AudioPlayerRouteArgs(document: document, key: key),
         initialChildren: children,
       );

  static const String name = 'AudioPlayerRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<AudioPlayerRouteArgs>();
      return AudioPlayerView(document: args.document, key: args.key);
    },
  );
}

class AudioPlayerRouteArgs {
  const AudioPlayerRouteArgs({required this.document, this.key});

  final DocumentItem document;

  final Key? key;

  @override
  String toString() {
    return 'AudioPlayerRouteArgs{document: $document, key: $key}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! AudioPlayerRouteArgs) return false;
    return document == other.document && key == other.key;
  }

  @override
  int get hashCode => document.hashCode ^ key.hashCode;
}

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
/// [DocumentsView]
class DocumentsRoute extends PageRouteInfo<void> {
  const DocumentsRoute({List<PageRouteInfo>? children})
    : super(DocumentsRoute.name, initialChildren: children);

  static const String name = 'DocumentsRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const DocumentsView();
    },
  );
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
/// [ImageViewerView]
class ImageViewerRoute extends PageRouteInfo<ImageViewerRouteArgs> {
  ImageViewerRoute({
    required DocumentItem document,
    Key? key,
    List<PageRouteInfo>? children,
  }) : super(
         ImageViewerRoute.name,
         args: ImageViewerRouteArgs(document: document, key: key),
         initialChildren: children,
       );

  static const String name = 'ImageViewerRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<ImageViewerRouteArgs>();
      return ImageViewerView(document: args.document, key: args.key);
    },
  );
}

class ImageViewerRouteArgs {
  const ImageViewerRouteArgs({required this.document, this.key});

  final DocumentItem document;

  final Key? key;

  @override
  String toString() {
    return 'ImageViewerRouteArgs{document: $document, key: $key}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ImageViewerRouteArgs) return false;
    return document == other.document && key == other.key;
  }

  @override
  int get hashCode => document.hashCode ^ key.hashCode;
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

/// generated route for
/// [PdfViewerView]
class PdfViewerRoute extends PageRouteInfo<PdfViewerRouteArgs> {
  PdfViewerRoute({
    required DocumentItem document,
    Key? key,
    List<PageRouteInfo>? children,
  }) : super(
         PdfViewerRoute.name,
         args: PdfViewerRouteArgs(document: document, key: key),
         initialChildren: children,
       );

  static const String name = 'PdfViewerRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<PdfViewerRouteArgs>();
      return PdfViewerView(document: args.document, key: args.key);
    },
  );
}

class PdfViewerRouteArgs {
  const PdfViewerRouteArgs({required this.document, this.key});

  final DocumentItem document;

  final Key? key;

  @override
  String toString() {
    return 'PdfViewerRouteArgs{document: $document, key: $key}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! PdfViewerRouteArgs) return false;
    return document == other.document && key == other.key;
  }

  @override
  int get hashCode => document.hashCode ^ key.hashCode;
}
