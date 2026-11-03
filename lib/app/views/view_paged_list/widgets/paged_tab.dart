import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_ders/app/core/di/injection.dart';
import 'package:flutter_ders/app/views/view_paged_list/cubit/paged_list_cubit.dart';
import 'package:flutter_ders/app/views/view_paged_list/cubit/paged_list_state.dart';
import 'package:flutter_ders/app/views/view_paged_list/widgets/paged_status_widgets.dart';

/// DERS 7 — Yükleme sırasında ne gösterileceği (lazy loading biçimi).
enum LoadingStyle {
  /// Dönen yükleniyor göstergesi.
  standard('Standart'),

  /// Gerçek kart biçiminde parıldayan gri kutular.
  skeleton('İskelet');

  const LoadingStyle(this.label);

  /// Sekme adı.
  final String label;
}

/// Bir sekmenin içeriğini kurar: gelen [state] ve kaydırma denetleyicisi
/// [scroll] ile listeyi ya da ızgarayı döndürür.
typedef PagedTabBuilder = Widget Function(
  BuildContext context,
  PagedListState state,
  ScrollController scroll,
);

/// Liste ve ızgara sekmelerinin ortak gövdesi.
///
/// Her sekmenin KENDİ cubit'i vardır; böylece iki sekme birbirinden
/// bağımsız sayfalanır. Sekme değişince içerik silinmesin diye
/// [AutomaticKeepAliveClientMixin] ile canlı tutulur.
class PagedTab extends StatefulWidget {
  /// Sekmeyi oluşturur.
  const PagedTab({required this.builder, super.key});

  /// İçeriği kuran fonksiyon.
  final PagedTabBuilder builder;

  @override
  State<PagedTab> createState() => _PagedTabState();
}

class _PagedTabState extends State<PagedTab>
    with AutomaticKeepAliveClientMixin {
  /// Sonraki sayfa, sona bu kadar piksel kala istenir.
  static const _loadMoreThreshold = 300.0;

  late final PagedListCubit _cubit = getIt<PagedListCubit>()..loadFirstPage();
  final ScrollController _scroll = ScrollController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  void _onScroll() {
    // extentAfter: görünen alanın altında kalan, henüz görülmemiş kısım.
    if (_scroll.position.extentAfter < _loadMoreThreshold) {
      _cubit.loadNextPage();
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return BlocProvider<PagedListCubit>.value(
      value: _cubit,
      child: Column(
        children: [
          const SizedBox(height: 12),
          const PagedCounter(),
          Expanded(
            child: BlocBuilder<PagedListCubit, PagedListState>(
              builder: (context, state) => RefreshIndicator(
                onRefresh: _cubit.refresh,
                child: widget.builder(context, state, _scroll),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
