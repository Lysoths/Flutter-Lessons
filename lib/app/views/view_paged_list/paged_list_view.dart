import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_ders/app/core/di/injection.dart';
import 'package:flutter_ders/app/helper/money_format.dart';
import 'package:flutter_ders/app/views/view_expenses/widgets/expense_tile_widget.dart';
import 'package:flutter_ders/app/views/view_paged_list/cubit/paged_list_cubit.dart';
import 'package:flutter_ders/app/views/view_paged_list/cubit/paged_list_state.dart';
import 'package:flutter_ders/app/views/view_paged_list/widgets/paged_status_widgets.dart';
import 'package:flutter_ders/app/widgets/common.dart';

// ─────────────────────────────────────────────────────────────────────────
// DERS 7 — Sayfalama (pagination) + ListView.builder
//
// ListView(children: [...])  → 500 satırın HEPSİNİ baştan oluşturur.
// ListView.builder(...)      → yalnızca ekranda görünen satırları
//                              oluşturur; kaydırdıkça itemBuilder(index)
//                              yenilerini ister (React'teki sanal liste).
//
// Sayfalama: kayıtlar 20'şer gelir. Liste sonuna 300 px kala
// cubit.loadNextPage() sonraki sayfayı ister ve listenin sonuna ekler.
// itemCount = gelen kayıt + 1; o fazla satır en alttaki "yükleniyor /
// tekrar dene / hepsi bu kadar" satırıdır.
// ─────────────────────────────────────────────────────────────────────────

/// 500 örnek harcamayı sayfa sayfa gösteren ekran.
@RoutePage()
class PagedListView extends StatelessWidget {
  /// Ekranı oluşturur.
  const PagedListView({super.key});

  @override
  Widget build(BuildContext context) {
    // Cubit bu sayfaya ait: sayfa açılınca oluşur, kapanınca kapanır.
    return BlocProvider<PagedListCubit>(
      create: (_) => getIt<PagedListCubit>()..loadFirstPage(),
      child: const _PagedListBody(),
    );
  }
}

class _PagedListBody extends StatefulWidget {
  const _PagedListBody();

  @override
  State<_PagedListBody> createState() => _PagedListBodyState();
}

class _PagedListBodyState extends State<_PagedListBody> {
  /// Sonraki sayfa, listenin sonuna bu kadar piksel kala istenir.
  static const _loadMoreThreshold = 300.0;

  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  void _onScroll() {
    // extentAfter: görünen alanın altında kalan, henüz görülmemiş kısım.
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sayfalı liste'),
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
            child: ListView.builder(
              key: const Key('pagedList_list'),
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: pagePadding(context).copyWith(top: 8, bottom: 24),
              itemCount: state.items.length + 1,
              itemBuilder: (context, index) {
                if (index == state.items.length) {
                  return PagedFooter(state: state, onRetry: cubit.retry);
                }
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
              },
            ),
          );
        },
      ),
    );
  }
}
