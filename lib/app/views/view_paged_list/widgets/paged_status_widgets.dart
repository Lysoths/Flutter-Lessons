import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_ders/app/theme/app_theme.dart';
import 'package:flutter_ders/app/views/view_paged_list/cubit/paged_list_cubit.dart';
import 'package:flutter_ders/app/views/view_paged_list/cubit/paged_list_state.dart';
import 'package:flutter_ders/app/widgets/common.dart';

// DERS 7 — Sayfalı liste ve sayfalı ızgaranın ortak parçaları.

/// "120 / 500 · sayfa 6 / 25" satırı.
class PagedCounter extends StatelessWidget {
  /// Sayacı oluşturur.
  const PagedCounter({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PagedListCubit, PagedListState>(
      builder: (context, state) {
        final pages = state.total == 0
            ? 0
            : (state.total / context.read<PagedListCubit>().pageSize).ceil();
        return Padding(
          padding: pagePadding(context).copyWith(top: 0, bottom: 10),
          // Dar ekranda taşmak yerine biraz küçülür.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                Eyebrow(
                  '${state.items.length} / ${state.total} kayıt',
                  key: const Key('pagedList_counter'),
                ),
                const SizedBox(width: 8),
                Eyebrow(
                  'Sayfa ${state.page} / $pages',
                  color: MfColors.slate600,
                  background: MfColors.slate100,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Listenin/ızgaranın en altındaki satır: yükleniyor, tekrar dene veya
/// "hepsi bu kadar".
class PagedFooter extends StatelessWidget {
  /// [state] için alt satırı oluşturur.
  const PagedFooter({
    required this.state,
    required this.onRetry,
    this.showSpinner = true,
    super.key,
  });

  /// Listenin durumu.
  final PagedListState state;

  /// "Tekrar dene" düğmesi.
  final VoidCallback onRetry;

  /// Sonraki sayfa beklenirken dönen gösterge çizilsin mi? İskelet
  /// biçiminde onun yerine iskelet kartlar gösterildiği için `false`.
  final bool showSpinner;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    if (state.status == PagedListStatus.failure) {
      return PagedRetry(onRetry: onRetry);
    }
    if (!state.hasMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Text(
          'Hepsi bu kadar · ${state.total} kayıt',
          key: const Key('pagedList_end'),
          textAlign: TextAlign.center,
          style: t.bodyMedium,
        ),
      );
    }
    if (!showSpinner) return const SizedBox(height: 16);
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: SizedBox.square(
          dimension: 28,
          child: CircularProgressIndicator(
            key: Key('pagedList_loadingMore'),
            strokeWidth: 3,
          ),
        ),
      ),
    );
  }
}

/// Yükleme hatasında "Tekrar dene".
class PagedRetry extends StatelessWidget {
  /// Hata satırını oluşturur.
  const PagedRetry({required this.onRetry, super.key});

  /// "Tekrar dene" düğmesi.
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Kayıtlar yüklenemedi'),
          const Gap(8),
          OutlinedButton(
            key: const Key('pagedList_retry'),
            onPressed: onRetry,
            child: const Text('Tekrar dene'),
          ),
        ],
      ),
    );
  }
}
