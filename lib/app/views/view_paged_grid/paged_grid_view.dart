import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_ders/app/core/di/injection.dart';
import 'package:flutter_ders/app/views/view_paged_grid/widgets/expense_grid_card.dart';
import 'package:flutter_ders/app/views/view_paged_list/cubit/paged_list_cubit.dart';
import 'package:flutter_ders/app/views/view_paged_list/cubit/paged_list_state.dart';
import 'package:flutter_ders/app/views/view_paged_list/widgets/paged_status_widgets.dart';

// ─────────────────────────────────────────────────────────────────────────
// DERS 7 — Sayfalama + GridView.builder (2. ekran)
//
// Veri tarafı liste ekranıyla AYNI: aynı depo, aynı PagedListCubit.
// Değişen yalnızca görünüm. GridView.builder da ListView.builder gibi
// yalnızca görünen kartları oluşturur.
//
// Izgarada "en alttaki satır" bir hücreye sığmaz (tek sütun genişliğinde
// kalırdı). Bu yüzden CustomScrollView kullanılır:
//   SliverGrid         → kartlar (GridView.builder'ın içindeki parça)
//   SliverToBoxAdapter → tam genişlikte yükleniyor / hepsi bu kadar satırı
// ─────────────────────────────────────────────────────────────────────────

/// 500 örnek harcamayı sayfa sayfa ızgarada gösteren ekran.
@RoutePage()
class PagedGridView extends StatelessWidget {
  /// Ekranı oluşturur.
  const PagedGridView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<PagedListCubit>(
      create: (_) => getIt<PagedListCubit>()..loadFirstPage(),
      child: const _PagedGridBody(),
    );
  }
}

class _PagedGridBody extends StatefulWidget {
  const _PagedGridBody();

  @override
  State<_PagedGridBody> createState() => _PagedGridBodyState();
}

class _PagedGridBodyState extends State<_PagedGridBody> {
  static const _loadMoreThreshold = 300.0;

  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scroll.position.extentAfter < _loadMoreThreshold) {
      context.read<PagedListCubit>().loadNextPage();
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final pad = MediaQuery.paddingOf(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sayfalı ızgara'),
        titleTextStyle: t.titleLarge,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(40),
          child: PagedCounter(),
        ),
      ),
      body: BlocBuilder<PagedListCubit, PagedListState>(
        builder: (context, state) {
          final cubit = context.read<PagedListCubit>();
          if (state.items.isEmpty) {
            return switch (state.status) {
              PagedListStatus.failure => Center(
                child: PagedRetry(onRetry: cubit.retry),
              ),
              _ => const Center(child: CircularProgressIndicator()),
            };
          }
          return RefreshIndicator(
            onRefresh: cubit.refresh,
            child: CustomScrollView(
              key: const Key('pagedGrid_grid'),
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    pad.left + 20,
                    8,
                    pad.right + 20,
                    0,
                  ),
                  sliver: SliverGrid.builder(
                    // Kart en fazla 200 px genişlikte: telefonda 2,
                    // tablette/yatayda daha çok sütun olur.
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 200,
                          mainAxisExtent: 150,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                        ),
                    itemCount: state.items.length,
                    itemBuilder: (context, index) => ExpenseGridCard(
                      expense: state.items[index],
                      number: index + 1,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: PagedFooter(state: state, onRetry: cubit.retry),
                ),
                SliverToBoxAdapter(child: SizedBox(height: pad.bottom + 8)),
              ],
            ),
          );
        },
      ),
    );
  }
}
