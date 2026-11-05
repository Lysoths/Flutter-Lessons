// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AutoRouterGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

part of 'app_router.dart';

/// generated route for
/// [AnimationControlView]
class AnimationControlRoute extends PageRouteInfo<void> {
  const AnimationControlRoute({List<PageRouteInfo>? children})
    : super(AnimationControlRoute.name, initialChildren: children);

  static const String name = 'AnimationControlRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const AnimationControlView();
    },
  );
}

/// generated route for
/// [AnimationDemoView]
class AnimationDemoRoute extends PageRouteInfo<AnimationDemoRouteArgs> {
  AnimationDemoRoute({
    required String senaryo,
    Key? key,
    List<PageRouteInfo>? children,
  }) : super(
         AnimationDemoRoute.name,
         args: AnimationDemoRouteArgs(senaryo: senaryo, key: key),
         rawPathParams: {'senaryo': senaryo},
         initialChildren: children,
       );

  static const String name = 'AnimationDemoRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final pathParams = data.inheritedPathParams;
      final args = data.argsAs<AnimationDemoRouteArgs>(
        orElse: () =>
            AnimationDemoRouteArgs(senaryo: pathParams.getString('senaryo')),
      );
      return AnimationDemoView(senaryo: args.senaryo, key: args.key);
    },
  );
}

class AnimationDemoRouteArgs {
  const AnimationDemoRouteArgs({required this.senaryo, this.key});

  final String senaryo;

  final Key? key;

  @override
  String toString() {
    return 'AnimationDemoRouteArgs{senaryo: $senaryo, key: $key}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! AnimationDemoRouteArgs) return false;
    return senaryo == other.senaryo && key == other.key;
  }

  @override
  int get hashCode => senaryo.hashCode ^ key.hashCode;
}

/// generated route for
/// [AnimationsView]
class AnimationsRoute extends PageRouteInfo<void> {
  const AnimationsRoute({List<PageRouteInfo>? children})
    : super(AnimationsRoute.name, initialChildren: children);

  static const String name = 'AnimationsRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const AnimationsView();
    },
  );
}

/// generated route for
/// [AppNetworkView]
class AppNetworkRoute extends PageRouteInfo<void> {
  const AppNetworkRoute({List<PageRouteInfo>? children})
    : super(AppNetworkRoute.name, initialChildren: children);

  static const String name = 'AppNetworkRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const AppNetworkView();
    },
  );
}

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
/// [BlocDemoView]
class BlocDemoRoute extends PageRouteInfo<void> {
  const BlocDemoRoute({List<PageRouteInfo>? children})
    : super(BlocDemoRoute.name, initialChildren: children);

  static const String name = 'BlocDemoRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const BlocDemoView();
    },
  );
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
/// [CurrencyView]
class CurrencyRoute extends PageRouteInfo<void> {
  const CurrencyRoute({List<PageRouteInfo>? children})
    : super(CurrencyRoute.name, initialChildren: children);

  static const String name = 'CurrencyRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const CurrencyView();
    },
  );
}

/// generated route for
/// [DeviceInfoView]
class DeviceInfoRoute extends PageRouteInfo<void> {
  const DeviceInfoRoute({List<PageRouteInfo>? children})
    : super(DeviceInfoRoute.name, initialChildren: children);

  static const String name = 'DeviceInfoRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const DeviceInfoView();
    },
  );
}

/// generated route for
/// [DeviceView]
class DeviceRoute extends PageRouteInfo<void> {
  const DeviceRoute({List<PageRouteInfo>? children})
    : super(DeviceRoute.name, initialChildren: children);

  static const String name = 'DeviceRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const DeviceView();
    },
  );
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
/// [FirebaseView]
class FirebaseRoute extends PageRouteInfo<void> {
  const FirebaseRoute({List<PageRouteInfo>? children})
    : super(FirebaseRoute.name, initialChildren: children);

  static const String name = 'FirebaseRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const FirebaseView();
    },
  );
}

/// generated route for
/// [HiveStorageView]
class HiveStorageRoute extends PageRouteInfo<void> {
  const HiveStorageRoute({List<PageRouteInfo>? children})
    : super(HiveStorageRoute.name, initialChildren: children);

  static const String name = 'HiveStorageRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const HiveStorageView();
    },
  );
}

/// generated route for
/// [ImageCacheView]
class ImageCacheRoute extends PageRouteInfo<void> {
  const ImageCacheRoute({List<PageRouteInfo>? children})
    : super(ImageCacheRoute.name, initialChildren: children);

  static const String name = 'ImageCacheRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const ImageCacheView();
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
/// [LessonsView]
class LessonsRoute extends PageRouteInfo<void> {
  const LessonsRoute({List<PageRouteInfo>? children})
    : super(LessonsRoute.name, initialChildren: children);

  static const String name = 'LessonsRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const LessonsView();
    },
  );
}

/// generated route for
/// [LottieView]
class LottieRoute extends PageRouteInfo<void> {
  const LottieRoute({List<PageRouteInfo>? children})
    : super(LottieRoute.name, initialChildren: children);

  static const String name = 'LottieRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const LottieView();
    },
  );
}

/// generated route for
/// [NetworkView]
class NetworkRoute extends PageRouteInfo<void> {
  const NetworkRoute({List<PageRouteInfo>? children})
    : super(NetworkRoute.name, initialChildren: children);

  static const String name = 'NetworkRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const NetworkView();
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

/// generated route for
/// [PagedGridView]
class PagedGridRoute extends PageRouteInfo<void> {
  const PagedGridRoute({List<PageRouteInfo>? children})
    : super(PagedGridRoute.name, initialChildren: children);

  static const String name = 'PagedGridRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const PagedGridView();
    },
  );
}

/// generated route for
/// [PagedListView]
class PagedListRoute extends PageRouteInfo<void> {
  const PagedListRoute({List<PageRouteInfo>? children})
    : super(PagedListRoute.name, initialChildren: children);

  static const String name = 'PagedListRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const PagedListView();
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

/// generated route for
/// [RetrofitView]
class RetrofitRoute extends PageRouteInfo<void> {
  const RetrofitRoute({List<PageRouteInfo>? children})
    : super(RetrofitRoute.name, initialChildren: children);

  static const String name = 'RetrofitRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const RetrofitView();
    },
  );
}

/// generated route for
/// [SharedPreferencesView]
class SharedPreferencesRoute extends PageRouteInfo<void> {
  const SharedPreferencesRoute({List<PageRouteInfo>? children})
    : super(SharedPreferencesRoute.name, initialChildren: children);

  static const String name = 'SharedPreferencesRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const SharedPreferencesView();
    },
  );
}

/// generated route for
/// [SqfliteStorageView]
class SqfliteStorageRoute extends PageRouteInfo<void> {
  const SqfliteStorageRoute({List<PageRouteInfo>? children})
    : super(SqfliteStorageRoute.name, initialChildren: children);

  static const String name = 'SqfliteStorageRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const SqfliteStorageView();
    },
  );
}

/// generated route for
/// [StorageHubView]
class StorageHubRoute extends PageRouteInfo<void> {
  const StorageHubRoute({List<PageRouteInfo>? children})
    : super(StorageHubRoute.name, initialChildren: children);

  static const String name = 'StorageHubRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const StorageHubView();
    },
  );
}

/// generated route for
/// [SyncAsyncView]
class SyncAsyncRoute extends PageRouteInfo<void> {
  const SyncAsyncRoute({List<PageRouteInfo>? children})
    : super(SyncAsyncRoute.name, initialChildren: children);

  static const String name = 'SyncAsyncRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const SyncAsyncView();
    },
  );
}
