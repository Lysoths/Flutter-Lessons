import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ders/app/views/view_animation_control/widgets/object_3d_panel.dart';
import 'package:flutter_ders/app/views/view_animation_control/widgets/pulse_card.dart';
import 'package:flutter_ders/app/views/view_animation_control/widgets/pulse_effects.dart';
import 'package:flutter_ders/app/widgets/common.dart';

/// DERS 8 — AnimationController ile animasyon kontrolü.
///
/// İki sekme:
///   3B obje → tek controller; oynat/durdur/geri/başa sar, hız, ilerleme,
///             eğri (Curves), AnimatedSwitcher ve AnimatedContainer
///   Nabız   → 8 efekt, her biri kendi controller'ıyla sürekli tekrar
@RoutePage()
class AnimationControlView extends StatelessWidget {
  /// Ekranı oluşturur.
  const AnimationControlView({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Animasyon kontrolü'),
          titleTextStyle: t.titleLarge,
          bottom: const TabBar(
            tabs: [
              Tab(key: Key('animationControl_tab3d'), text: '3B obje'),
              Tab(key: Key('animationControl_tabPulse'), text: 'Nabız'),
            ],
          ),
        ),
        body: TabBarView(
          // Sekme kaydırmak, kaydırıcılarla karışmasın diye kapalı.
          physics: const NeverScrollableScrollPhysics(),
          children: [
            const Object3DPanel(),
            ListView(
              key: const Key('pulse_list'),
              padding: pagePadding(context).copyWith(top: 16, bottom: 32),
              children: [
                for (final e in PulseEffect.values)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: PulseCard(effect: e),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
