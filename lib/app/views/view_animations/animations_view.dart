import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show timeDilation;
import 'package:flutter_ders/app/core/analytics/app_events.dart';
import 'package:flutter_ders/app/core/router/app_router.dart';
import 'package:flutter_ders/app/core/router/route_transitions.dart';
import 'package:flutter_ders/app/theme/app_theme.dart';
import 'package:flutter_ders/app/widgets/common.dart';

/// DERS 6 — 20 geçiş animasyonunun vitrini.
///
/// Her satır aynı demo sayfasını farklı bir senaryoyla açar:
///   context.router.push(AnimationDemoRoute(senaryo: 'fade'))
/// Hangi animasyonun oynayacağına rota tablosu, gönderilen senaryoya
/// bakarak karar verir (bkz. app_router.dart → AnimationDemoRoute).
@RoutePage()
class AnimationsView extends StatefulWidget {
  /// Vitrini oluşturur.
  const AnimationsView({super.key});

  @override
  State<AnimationsView> createState() => _AnimationsViewState();
}

class _AnimationsViewState extends State<AnimationsView> {
  bool _slowMotion = false;

  void _setSlowMotion(bool value) {
    track(AppEvent.slowMotionToggled, value ? 'acik' : 'kapali');
    // timeDilation tüm animasyonları yavaşlatır (5 = beş kat yavaş).
    setState(() => _slowMotion = value);
    timeDilation = value ? 5 : 1;
  }

  @override
  void dispose() {
    timeDilation = 1;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Geçiş animasyonları'),
        titleTextStyle: t.titleLarge,
      ),
      body: ListView(
        padding: pagePadding(context).copyWith(top: 8, bottom: 24),
        children: [
          Card(
            child: SwitchListTile(
              key: const Key('animations_slowMotion'),
              value: _slowMotion,
              onChanged: _setSlowMotion,
              title: Text('Yavaş çekim (5x)', style: t.titleMedium),
              subtitle: const Text('Geçişleri incelemek için yavaşlatır'),
              secondary: const Icon(Icons.slow_motion_video_rounded),
            ),
          ),
          const Gap(16),
          for (final (i, a) in RouteAnimation.values.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _AnimationTile(
                number: i + 1,
                animation: a,
                onTap: () {
                  track(AppEvent.transitionOpened, a.name);
                  context.router.push(AnimationDemoRoute(senaryo: a.name));
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _AnimationTile extends StatelessWidget {
  const _AnimationTile({
    required this.number,
    required this.animation,
    required this.onTap,
  });

  final int number;
  final RouteAnimation animation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(16);
    Widget badge = IconBadge(animation.icon, size: 44);
    // Yalnızca Hero senaryosunda ikon, demo sayfasındaki ikonla eşleşir.
    if (animation == RouteAnimation.hero) {
      badge = Hero(tag: 'route_animation_hero', child: badge);
    }
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: const BorderSide(color: MfColors.slate200),
      ),
      child: InkWell(
        key: Key('animationTile_${animation.name}'),
        borderRadius: radius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
          child: Row(
            children: [
              SizedBox(
                width: 26,
                child: Text(
                  '$number',
                  style: t.labelMedium,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 6),
              badge,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(animation.label, style: t.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      animation.description,
                      style: t.bodyMedium?.copyWith(fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: MfColors.slate400),
            ],
          ),
        ),
      ),
    );
  }
}
