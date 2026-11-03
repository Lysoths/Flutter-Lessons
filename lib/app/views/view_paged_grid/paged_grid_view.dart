import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_ders/app/views/view_paged_grid/widgets/expense_grid_card.dart';
import 'package:flutter_ders/app/views/view_paged_grid/widgets/expense_grid_card_skeleton.dart';
import 'package:flutter_ders/app/views/view_paged_list/cubit/paged_list_cubit.dart';
import 'package:flutter_ders/app/views/view_paged_list/cubit/paged_list_state.dart';
import 'package:flutter_ders/app/views/view_paged_list/widgets/paged_status_widgets.dart';
import 'package:flutter_ders/app/views/view_paged_list/widgets/paged_tab.dart';

// ─────────────────────────────────────────────────────────────────────────
// DERS 7 — Sayfalama + GridView.builder (2. ekran) + lazy loading
//
// Veri tarafı liste ekranıyla AYNI: aynı depo, aynı PagedListCubit,
// aynı iki sekme (Standart / İskelet). Değişen yalnızca görünüm.
//
// Izgarada "en alttaki satır" bir hücreye sığmaz (tek sütun genişliğinde
// kalırdı). Bu yüzden CustomScrollView kullanılır:
//   SliverGrid         → kartlar (GridView.builder'ın içindeki parça)
//   SliverToBoxAdapter → tam genişlikte yükleniyor / hepsi bu kadar satırı
// ─────────────────────────────────────────────────────────────────────────

/// Kart en fazla 200 px genişlikte: telefonda 2, geniş ekranda daha çok
/// sütun olur.
const _gridDelegate = SliverGridDelegateWithMaxCrossAxisExtent(
  maxCrossAxisExtent: 200,
  mainAxisExtent: 150,
  mainAxisSpacing: 10,
  crossAxisSpacing: 10,
);

/// 500 örnek harcamayı sayfa sayfa ızgarada gösteren ekran.
@RoutePage()
class PagedGridView extends StatelessWidget {
  /// Ekranı oluşturur.
  const PagedGridView({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return DefaultTabController(
      length: LoadingStyle.values.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Sayfalı ızgara'),
          titleTextStyle: t.titleLarge,
          bottom: TabBar(
            tabs: [
              for (final s in LoadingStyle.values)
                Tab(key: Key('pagedTab_${s.name}'), text: s.label),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            for (final s in LoadingStyle.values)
              PagedTab(
                builder: (context, state, scroll) =>
                    _PagedGrid(style: s, state: state, scroll: scroll),
              ),
          ],
        ),
      ),
    );
  }
}

class _PagedGrid extends StatelessWidget {
  const _PagedGrid({
    required this.style,
    required this.state,
    required this.scroll,
  });

  /// İlk açılışta kaç iskelet kart çizilir.
  static const _initialSkeletons = 8;

  /// Devamı beklenirken ızgaranın sonuna kaç iskelet kart eklenir.
  static const _tailSkeletons = 4;

  final LoadingStyle style;
  final PagedListState state;
  final ScrollController scroll;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<PagedListCubit>();
    final skeleton = style == LoadingStyle.skeleton;
    final pad = MediaQuery.paddingOf(context);
    final gridPadding = EdgeInsets.fromLTRB(
      pad.left + 20,
      8,
      pad.right + 20,
      0,
    );

    if (state.items.isEmpty) {
      if (state.status == PagedListStatus.failure) {
        return Center(child: PagedRetry(onRetry: cubit.retry));
      }
      if (!skeleton) {
        return const Center(child: CircularProgressIndicator());
      }
      return GridView.builder(
        key: const Key('pagedGrid_initialSkeleton'),
        physics: const NeverScrollableScrollPhysics(),
        padding: gridPadding,
        gridDelegate: _gridDelegate,
        itemCount: _initialSkeletons,
        itemBuilder: (_, _) => const ExpenseGridCardSkeleton(),
      );
    }

    final tail =
        skeleton && state.hasMore && state.status != PagedListStatus.failure
        ? _tailSkeletons
        : 0;
    return CustomScrollView(
      key: Key('pagedGrid_grid_${style.name}'),
      controller: scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: gridPadding,
          sliver: SliverGrid.builder(
            gridDelegate: _gridDelegate,
            itemCount: state.items.length + tail,
            itemBuilder: (context, index) => index < state.items.length
                ? ExpenseGridCard(
                    expense: state.items[index],
                    number: index + 1,
                  )
                : const ExpenseGridCardSkeleton(),
          ),
        ),
        SliverToBoxAdapter(
          child: PagedFooter(
            state: state,
            onRetry: cubit.retry,
            showSpinner: !skeleton,
          ),
        ),
        SliverToBoxAdapter(child: SizedBox(height: pad.bottom + 8)),
      ],
    );
  }
}
