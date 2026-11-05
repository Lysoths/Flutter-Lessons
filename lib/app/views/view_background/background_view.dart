import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_ders/app/core/background/background_models.dart';
import 'package:flutter_ders/app/core/background/notification_plan.dart';
import 'package:flutter_ders/app/core/di/injection.dart';
import 'package:flutter_ders/app/theme/app_theme.dart';
import 'package:flutter_ders/app/views/view_background/cubit/background_lab_cubit.dart';
import 'package:flutter_ders/app/views/view_background/widgets/background_panels.dart';
import 'package:flutter_ders/app/widgets/common.dart';

/// DERS 19 — Arka plan servisi ve bildirim simülasyonu.
@RoutePage()
class BackgroundView extends StatelessWidget {
  /// Sayfayı oluşturur.
  const BackgroundView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<BackgroundLabCubit>()..init(),
      child: const _BackgroundBody(),
    );
  }
}

class _BackgroundBody extends StatelessWidget {
  const _BackgroundBody();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Arka plan ve bildirimler'),
        titleTextStyle: t.titleLarge,
      ),
      body: BlocConsumer<BackgroundLabCubit, BackgroundLabState>(
        listenWhen: (a, b) => b.message != null && a.message != b.message,
        listener: (context, s) => ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(s.message!))),
        builder: (context, s) {
          if (!s.ready) {
            return const Center(child: CircularProgressIndicator());
          }
          final cubit = context.read<BackgroundLabCubit>();
          return ListView(
            key: const Key('bg_list'),
            padding: pagePadding(context).copyWith(top: 8, bottom: 40),
            children: [
              Text(
                'Servis uygulamanın açık, arka planda ya da kapalı olduğunu '
                'izler. Uygulama arkadayken 3 saniyede bir konum alır ve '
                'telefona kaydeder; konum hiçbir yere gönderilmez. Arka '
                'plana geçince farklı anlarda görselli ve düğmeli '
                'bildirimler gelir.',
                style: t.bodyMedium,
              ),
              const Gap(14),
              ServiceCard(
                state: s,
                onStart: cubit.start,
                onStop: cubit.stop,
                onPreview: cubit.preview,
                onMuted: (v) => cubit.setMuted(muted: v),
                onClear: cubit.clear,
              ),
              const Gap(18),
              const SectionTitle(
                icon: Icons.insights_rounded,
                title: 'İş istatistiği',
              ),
              const Gap(10),
              StatsGrid(stats: s.stats, stored: s.stored),
              const Gap(12),
              PresenceBar(stats: s.stats),
              const Gap(18),
              const SectionTitle(
                icon: Icons.notifications_active_rounded,
                title: 'Bildirim zaman çizelgesi',
              ),
              const Gap(4),
              Text(
                'Uygulama arka plana geçince başlar; öne gelince bekleyenler '
                'iptal edilir.',
                style: t.bodySmall,
              ),
              const Gap(10),
              PlanList(plan: s.plan, stats: s.stats),
              const Gap(18),
              const SectionTitle(
                icon: Icons.swap_horiz_rounded,
                title: 'Durum geçişleri',
              ),
              const Gap(10),
              ChangesList(changes: s.stats.changes),
              const Gap(18),
              SectionTitle(
                icon: Icons.location_on_rounded,
                title: 'Son konumlar',
                trailing: '${s.stored} kayıt',
              ),
              const Gap(10),
              SamplesList(samples: s.recent),
            ],
          );
        },
      ),
    );
  }
}

/// Ekrandaki durum rengi.
Color presenceColor(AppPresence p) => switch (p) {
  AppPresence.open => MfColors.emerald500,
  AppPresence.background => const Color(0xFFF59E0B),
  AppPresence.closed => MfColors.slate500,
};

/// Bildirim türünün simgesi.
IconData kindIcon(NotificationKind k) => switch (k) {
  NotificationKind.bigText => Icons.notes_rounded,
  NotificationKind.bigPicture => Icons.image_rounded,
  NotificationKind.bigPictureCollapsed => Icons.photo_size_select_large_rounded,
  NotificationKind.inbox => Icons.inbox_rounded,
  NotificationKind.progress => Icons.linear_scale_rounded,
  NotificationKind.messaging => Icons.forum_rounded,
  NotificationKind.summary => Icons.layers_rounded,
};
