import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_ders/app/helper/money_format.dart';
import 'package:flutter_ders/app/views/view_expenses/widgets/expense_tile_widget.dart';
import 'package:flutter_ders/app/views/view_paged_list/cubit/paged_list_cubit.dart';
import 'package:flutter_ders/app/views/view_paged_list/cubit/paged_list_state.dart';
import 'package:flutter_ders/app/views/view_paged_list/widgets/expense_tile_skeleton.dart';
import 'package:flutter_ders/app/views/view_paged_list/widgets/paged_status_widgets.dart';
import 'package:flutter_ders/app/views/view_paged_list/widgets/paged_tab.dart';
import 'package:flutter_ders/app/widgets/common.dart';

// ─────────────────────────────────────────────────────────────────────────
// DERS 7 — Sayfalama (pagination) + ListView.builder + lazy loading
//
// ListView(children: [...])  → 500 satırın HEPSİNİ baştan oluşturur.
// ListView.builder(...)      → yalnızca ekranda görünen satırları
//                              oluşturur; kaydırdıkça itemBuilder(index)
//                              yenilerini ister (React'teki sanal liste).
//
// Lazy loading: kayıtlar 20'şer gelir, liste sonuna yaklaşınca sonraki
// sayfa istenir. Beklerken ne gösterileceği iki sekmede farklıdır:
//   Standart → ortada / en altta dönen gösterge
//   İskelet  → gerçek satır biçiminde parıldayan gri kutular
// ─────────────────────────────────────────────────────────────────────────

/// 500 örnek harcamayı sayfa sayfa gösteren ekran.
@RoutePage()
class PagedListView extends StatelessWidget {
  /// Ekranı oluşturur.
  const PagedListView({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return DefaultTabController(
      length: LoadingStyle.values.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Sayfalı liste'),
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
                    _PagedList(style: s, state: state, scroll: scroll),
              ),
          ],
        ),
      ),
    );
  }
}

class _PagedList extends StatelessWidget {
  const _PagedList({
    required this.style,
    required this.state,
    required this.scroll,
  });

  /// İlk açılışta kaç iskelet satır çizilir.
  static const _initialSkeletons = 8;

  /// Devamı beklenirken listenin sonuna kaç iskelet satır eklenir.
  static const _tailSkeletons = 3;

  final LoadingStyle style;
  final PagedListState state;
  final ScrollController scroll;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<PagedListCubit>();
    final skeleton = style == LoadingStyle.skeleton;
    final padding = pagePadding(context).copyWith(top: 8, bottom: 24);

    if (state.items.isEmpty) {
      if (state.status == PagedListStatus.failure) {
        return Center(child: PagedRetry(onRetry: cubit.retry));
      }
      if (!skeleton) {
        return const Center(child: CircularProgressIndicator());
      }
      return ListView.builder(
        key: const Key('pagedList_initialSkeleton'),
        physics: const NeverScrollableScrollPhysics(),
        padding: padding,
        itemCount: _initialSkeletons,
        itemBuilder: (_, _) => const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: ExpenseTileSkeleton(),
        ),
      );
    }

    // İskelet biçiminde, devamı varsa listenin sonunda iskelet satırlar
    // bekler; kullanıcı oraya gelince yerlerini gerçek satırlar alır.
    final tail =
        skeleton && state.hasMore && state.status != PagedListStatus.failure
        ? _tailSkeletons
        : 0;
    return ListView.builder(
      key: Key('pagedList_list_${style.name}'),
      controller: scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: padding,
      itemCount: state.items.length + tail + 1,
      itemBuilder: (context, index) {
        if (index < state.items.length) {
          final e = state.items[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ExpenseTileWidget(
              expense: e,
              subtitle:
                  '#${index + 1} · ${e.category.label} · '
                  '${formatDate(e.date)}',
            ),
          );
        }
        if (index < state.items.length + tail) {
          return const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: ExpenseTileSkeleton(),
          );
        }
        return PagedFooter(
          state: state,
          onRetry: cubit.retry,
          showSpinner: !skeleton,
        );
      },
    );
  }
}
