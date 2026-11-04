import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_ders/app/core/di/injection.dart';
import 'package:flutter_ders/app/views/view_network/widgets/network_cards.dart';
import 'package:flutter_ders/app/views/view_retrofit/cubit/retrofit_demos.dart';
import 'package:flutter_ders/app/views/view_retrofit/cubit/retrofit_lab_cubit.dart';
import 'package:flutter_ders/app/views/view_retrofit/cubit/retrofit_lab_state.dart';
import 'package:flutter_ders/app/views/view_retrofit/widgets/demo_card.dart';
import 'package:flutter_ders/app/views/view_retrofit/widgets/exchange_tile.dart';
import 'package:flutter_ders/app/widgets/common.dart';

// ─────────────────────────────────────────────────────────────────────────
// DERS 16 — retrofit ile ağ geliştirme ekranı
//
// Her kart bir retrofit özelliği: anotasyon, arayüzdeki tanımı, değiştirilebilen
// girdiler ve "Gönder". Sonuçta iki şey görünür:
//   1. Retrofit'in döndürdüğü Dart nesnesi (Post, List<Post>, HttpResponse ...)
//   2. Ağdan gerçekten geçen istek ve cevap (RecordingInterceptor)
// ─────────────────────────────────────────────────────────────────────────

/// Retrofit dersinin sayfası.
@RoutePage()
class RetrofitView extends StatelessWidget {
  /// Sayfayı oluşturur.
  const RetrofitView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<RetrofitLabCubit>(),
      child: const _RetrofitPage(),
    );
  }
}

class _RetrofitPage extends StatelessWidget {
  const _RetrofitPage();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cubit = context.read<RetrofitLabCubit>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Retrofit ile ağ'),
        titleTextStyle: t.titleLarge,
        actions: [
          BlocSelector<RetrofitLabCubit, RetrofitLabState, int>(
            selector: (s) => s.log.length,
            builder: (context, count) => IconButton(
              key: const Key('retrofit_log'),
              tooltip: 'Ağ kaydı',
              onPressed: () => _showLog(context),
              icon: Badge(
                isLabelVisible: count > 0,
                label: Text('$count'),
                child: const Icon(Icons.receipt_long_rounded),
              ),
            ),
          ),
        ],
      ),
      body: BlocBuilder<RetrofitLabCubit, RetrofitLabState>(
        buildWhen: (a, b) => a.group != b.group,
        builder: (context, state) {
          final demos = state.visible;
          return ListView.builder(
            key: const Key('retrofit_list'),
            padding: pagePadding(context).copyWith(top: 16, bottom: 32),
            itemCount: demos.length + 1,
            itemBuilder: (context, i) {
              if (i == 0) {
                return _Header(group: state.group, onGroup: cubit.showGroup);
              }
              final demo = demos[i - 1];
              return DemoCard(key: ValueKey(demo.id), demo: demo);
            },
          );
        },
      ),
    );
  }

  void _showLog(BuildContext context) {
    final cubit = context.read<RetrofitLabCubit>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) =>
          BlocProvider.value(value: cubit, child: const _LogSheet()),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.group, required this.onGroup});

  final DemoGroup? group;
  final ValueChanged<DemoGroup?> onGroup;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Servis bir arayüz olarak yazılır, istemci kodunu build_runner '
          'üretir. Karta dokun, değerleri değiştir, Gönder: retrofit\'in '
          'döndürdüğü nesneyi ve ağdan geçen ham isteği birlikte gör.',
          style: t.bodyMedium,
        ),
        const Gap(12),
        const CodeBox('''
@RestApi(baseUrl: 'https://jsonplaceholder.typicode.com')
abstract class PostsApi {
  factory PostsApi(Dio dio) = _PostsApi;   // üretilen sınıf

  @GET('/posts/{id}')
  Future<Post> getPost(@Path('id') int id);
}

final post = await PostsApi(dio).getPost(1);   // Post nesnesi'''),
        const Gap(14),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ChoiceChip(
                key: const Key('retrofit_group_all'),
                label: Text('Hepsi (${kRetrofitDemos.length})'),
                selected: group == null,
                onSelected: (_) => onGroup(null),
              ),
              for (final g in DemoGroup.values) ...[
                const SizedBox(width: 6),
                ChoiceChip(
                  key: Key('retrofit_group_${g.name}'),
                  label: Text(
                    '${g.label} '
                    '(${kRetrofitDemos.where((d) => d.group == g).length})',
                  ),
                  selected: group == g,
                  onSelected: (_) => onGroup(g),
                ),
              ],
            ],
          ),
        ),
        const Gap(14),
      ],
    );
  }
}

class _LogSheet extends StatelessWidget {
  const _LogSheet();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (context, controller) =>
          BlocBuilder<RetrofitLabCubit, RetrofitLabState>(
            builder: (context, state) => ListView(
              key: const Key('retrofit_log_sheet'),
              controller: controller,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Ağ kaydı (${state.log.length})',
                        style: t.titleMedium,
                      ),
                    ),
                    TextButton(
                      onPressed: state.log.isEmpty
                          ? null
                          : context.read<RetrofitLabCubit>().clearLog,
                      child: const Text('Temizle'),
                    ),
                  ],
                ),
                Text(
                  'RecordingInterceptor: retrofit\'in attığı her istek Dio\'dan '
                  'geçer ve burada kaydedilir. Yeniden eskiye.',
                  style: t.bodySmall,
                ),
                const Gap(10),
                if (state.log.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('Henüz istek yok.')),
                  ),
                for (final e in state.log) ExchangeTile(e, showDemo: true),
              ],
            ),
          ),
    );
  }
}
