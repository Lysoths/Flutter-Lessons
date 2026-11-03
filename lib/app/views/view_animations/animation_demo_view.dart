import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ders/app/core/router/app_router.dart';
import 'package:flutter_ders/app/core/router/route_transitions.dart';
import 'package:flutter_ders/app/theme/app_theme.dart';
import 'package:flutter_ders/app/widgets/common.dart';

/// DERS 6 — Bir geçiş senaryosunun açtığı örnek sayfa.
///
/// Sayfanın kendisi animasyon bilmez; nasıl açılacağına rota karar verir.
/// "Sonraki" düğmesi `replace` ile bu sayfayı bir sonraki senaryonun
/// sayfasıyla değiştirir, böylece yeni geçiş hemen oynar.
///
/// Senaryo yolun parçasıdır (`/animasyon/fade`). auto_route rotaları
/// varsayılan olarak ADIYLA tanır; 20 senaryonun adı aynı olduğu için
/// rota `usesPathAsKey: true` ile YOLUYLA tanınır (bkz. app_router.dart).
@RoutePage()
class AnimationDemoView extends StatelessWidget {
  /// [senaryo] adlı geçiş için sayfa oluşturur (ör. `fade`).
  const AnimationDemoView({
    @PathParam('senaryo') required this.senaryo,
    super.key,
  });

  /// Senaryonun adı (`RouteAnimation.name`).
  final String senaryo;

  /// Bu sayfayı açan senaryo; bilinmeyen ad → solma.
  RouteAnimation get animation => routeAnimationNamed(senaryo);

  static const _colors = [
    MfColors.blue600,
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
    Color(0xFFF97316),
    MfColors.emerald500,
  ];

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    const all = RouteAnimation.values;
    final index = animation.index;
    final accent = _colors[index % _colors.length];
    Widget icon = Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Icon(animation.icon, color: Colors.white, size: 44),
    );
    if (animation == RouteAnimation.hero) {
      icon = Hero(tag: 'route_animation_hero', child: icon);
    }

    void go(int i) => context.router.replace(
      AnimationDemoRoute(senaryo: all[i % all.length].name),
    );

    return Scaffold(
      backgroundColor: accent,
      appBar: AppBar(
        backgroundColor: accent,
        surfaceTintColor: accent,
        foregroundColor: Colors.white,
        title: Text('Senaryo ${index + 1} / ${all.length}'),
      ),
      body: SafeArea(
        child: Padding(
          padding: pagePadding(context),
          child: Column(
            children: [
              const Spacer(),
              icon,
              const Gap(24),
              Text(
                animation.label,
                key: const Key('animationDemo_title'),
                textAlign: TextAlign.center,
                style: t.headlineSmall?.copyWith(color: Colors.white),
              ),
              const Gap(8),
              Text(
                animation.description,
                textAlign: TextAlign.center,
                style: t.bodyLarge?.copyWith(color: Colors.white70),
              ),
              const Gap(16),
              Eyebrow(
                'Süre: ${animation.duration.inMilliseconds} ms',
                color: Colors.white,
                background: Colors.white.withValues(alpha: 0.18),
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('animationDemo_previous'),
                      onPressed: () => go(index - 1 + all.length),
                      icon: const Icon(Icons.chevron_left_rounded),
                      label: const Text('Önceki'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      key: const Key('animationDemo_next'),
                      onPressed: () => go(index + 1),
                      icon: const Icon(Icons.chevron_right_rounded),
                      label: const Text('Sonraki'),
                    ),
                  ),
                ],
              ),
              const Gap(10),
              TextButton(
                onPressed: () => context.router.maybePop(),
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                child: const Text('Listeye dön (ters animasyon)'),
              ),
              const Gap(8),
            ],
          ),
        ),
      ),
    );
  }
}
