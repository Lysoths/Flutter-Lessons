import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_ders/app/core/analytics/app_events.dart';
import 'package:flutter_ders/app/theme/app_theme.dart';
import 'package:flutter_ders/app/views/view_animation_control/widgets/box_3d.dart';
import 'package:flutter_ders/app/views/view_animation_control/widgets/curve_option.dart';
import 'package:flutter_ders/app/widgets/common.dart';

// ─────────────────────────────────────────────────────────────────────────
// DERS 8 — AnimationController ile 3B obje kontrolü
//
// AnimationController bir "saattir": her karede (saniyede ~60/120 kez)
// value'yu 0.0 → 1.0 arasında ilerletir. Ne zaman başlayacağı, duracağı,
// geri gideceği tamamen bizim elimizde:
//   forward()  ileri oynat        reverse()  geri oynat
//   stop()     olduğu yerde dur    reset()    başa (0.0) dön
//   repeat()   sürekli tekrarla    repeat(reverse: true) gidip gel
//   value = x  elle istenen yere getir
//
// Saatin çalışması için bir "tıkırtı" kaynağı (vsync) gerekir; State'e
// TickerProviderStateMixin eklenir. Sayfa kapanınca dispose() ile saat
// MUTLAKA kapatılır, yoksa arka planda çalışmaya devam eder.
//
// Bu panelde ayrıca:
//   CurvedAnimation   → düz zamanı seçilen eğriye (Curves) göre büker
//   AnimatedSwitcher  → küp / kart / kule değişirken eskisini söndürüp
//                       yenisini büyüterek getirir
//   AnimatedContainer → sahnenin rengi ve yüksekliği değişince aradaki
//                       geçişi kendisi canlandırır (controller'sız)
// ─────────────────────────────────────────────────────────────────────────

/// 3B objeyi AnimationController ile yöneten panel.
class Object3DPanel extends StatefulWidget {
  /// Paneli oluşturur.
  const Object3DPanel({super.key});

  @override
  State<Object3DPanel> createState() => _Object3DPanelState();
}

class _Object3DPanelState extends State<Object3DPanel>
    with SingleTickerProviderStateMixin {
  /// 1x hızda bir tam tur süresi.
  static const _baseDuration = Duration(seconds: 4);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _baseDuration,
  );

  /// Düz zamanı seçili eğriye göre büken animasyon.
  late CurvedAnimation _curved = CurvedAnimation(
    parent: _controller,
    curve: _curve.curve,
  );

  CurveOption _curve = CurveOption.linear;
  Shape3D _shape = Shape3D.cube;
  double _speed = 1;
  bool _loop = true;
  bool _pingPong = false;
  bool _night = false;
  bool _bigStage = false;

  @override
  void initState() {
    super.initState();
    // Durum (ileri / geri / bitti / başta) değişince ekrandaki yazı
    // güncellensin.
    _controller.addStatusListener((_) => setState(() {}));
    _play();
  }

  @override
  void dispose() {
    _curved.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _play() {
    if (_loop) {
      _controller.repeat(reverse: _pingPong);
    } else {
      _controller.forward();
    }
  }

  /// Durdurmak durumu (status) değiştirmez ve kare üretmez; yazının
  /// "Durdu" olması için ekran elle yenilenir.
  void _stop() => setState(_controller.stop);

  void _setSpeed(double speed) {
    final wasRunning = _controller.isAnimating;
    final backwards = _controller.status == AnimationStatus.reverse;
    setState(() => _speed = speed);
    _controller.duration = _baseDuration * (1 / speed);
    // Yeni süre ancak yeniden başlatınca geçerli olur; kaldığı yerden devam.
    if (!wasRunning) return;
    if (_loop) {
      _play();
    } else if (backwards) {
      _controller.reverse();
    } else {
      _controller.forward();
    }
  }

  void _setCurve(CurveOption option) {
    track(AppEvent.curveSelected, option.name);
    setState(() {
      _curve = option;
      _curved.dispose();
      _curved = CurvedAnimation(parent: _controller, curve: option.curve);
    });
  }

  void _setLoop({bool? loop, bool? pingPong}) {
    setState(() {
      _loop = loop ?? _loop;
      _pingPong = pingPong ?? _pingPong;
      if (_pingPong) _loop = true;
    });
    if (_controller.isAnimating) {
      _controller.stop();
      _play();
    }
  }

  String get _statusLabel => switch (_controller.status) {
    AnimationStatus.forward => _controller.isAnimating ? 'İleri' : 'Durdu',
    AnimationStatus.reverse => _controller.isAnimating ? 'Geri' : 'Durdu',
    AnimationStatus.completed => 'Bitti (1.0)',
    AnimationStatus.dismissed => 'Başta (0.0)',
  };

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ListView(
      key: const Key('object3d_list'),
      padding: pagePadding(context).copyWith(top: 16, bottom: 32),
      children: [
        _stage(),
        const Gap(12),
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => Row(
            children: [
              Eyebrow(_statusLabel, key: const Key('object3d_status')),
              const SizedBox(width: 8),
              Eyebrow(
                'value: ${_controller.value.toStringAsFixed(2)}',
                color: MfColors.slate600,
                background: MfColors.slate100,
              ),
            ],
          ),
        ),
        const Gap(16),
        _buttons(),
        const Gap(8),
        // Elle sarma: kaydırıcı controller.value'yu doğrudan yazar.
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => _LabeledSlider(
            label: 'İlerleme',
            sliderKey: const Key('object3d_progress'),
            value: _controller.value,
            valueText: '${(_controller.value * 100).round()}%',
            onChanged: (v) {
              _controller
                ..stop()
                ..value = v;
            },
          ),
        ),
        _LabeledSlider(
          label: 'Hız',
          sliderKey: const Key('object3d_speed'),
          value: _speed,
          min: 0.25,
          max: 3,
          divisions: 11,
          valueText: '${_speed.toStringAsFixed(2)}x',
          onChanged: _setSpeed,
        ),
        const Gap(8),
        Text('Eğri (Curves)', style: t.titleSmall),
        const Gap(8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in CurveOption.values)
              ChoiceChip(
                key: Key('object3d_curve_${c.name}'),
                label: Text(c.label),
                selected: _curve == c,
                onSelected: (_) => _setCurve(c),
              ),
          ],
        ),
        const Gap(16),
        Text('Obje (AnimatedSwitcher)', style: t.titleSmall),
        const Gap(8),
        SegmentedButton<Shape3D>(
          segments: [
            for (final s in Shape3D.values)
              ButtonSegment(
                value: s,
                label: Text(s.label, key: Key('object3d_shape_${s.name}')),
              ),
          ],
          selected: {_shape},
          onSelectionChanged: (s) {
            track(AppEvent.shapeSelected, s.first.name);
            setState(() => _shape = s.first);
          },
        ),
        const Gap(8),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                key: const Key('object3d_loop'),
                title: const Text('Sürekli tekrar'),
                subtitle: const Text('repeat()'),
                value: _loop,
                onChanged: (v) => _setLoop(loop: v),
              ),
              SwitchListTile(
                key: const Key('object3d_pingPong'),
                title: const Text('Gidip gel'),
                subtitle: const Text('repeat(reverse: true)'),
                value: _pingPong,
                onChanged: (v) => _setLoop(pingPong: v),
              ),
              SwitchListTile(
                key: const Key('object3d_night'),
                title: const Text('Gece sahnesi'),
                subtitle: const Text('AnimatedContainer rengi'),
                value: _night,
                onChanged: (v) => setState(() => _night = v),
              ),
              SwitchListTile(
                key: const Key('object3d_bigStage'),
                title: const Text('Büyük sahne'),
                subtitle: const Text('AnimatedContainer yüksekliği'),
                value: _bigStage,
                onChanged: (v) => setState(() => _bigStage = v),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Objenin durduğu sahne.
  Widget _stage() {
    return AnimatedContainer(
      key: const Key('object3d_stage'),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOutCubic,
      height: _bigStage ? 380 : 280,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: _night
              ? const [Color(0xFF0F172A), Color(0xFF312E81)]
              : const [MfColors.blue50, Colors.white],
        ),
        border: Border.all(color: MfColors.slate200),
      ),
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 450),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(scale: animation, child: child),
          ),
          child: AnimatedBuilder(
            key: ValueKey(_shape),
            animation: _curved,
            builder: (context, _) {
              final v = _curved.value;
              return Box3D(
                shape: _shape,
                // Bir tam tur Y ekseninde, X'te hafif sallanma.
                rotationY: v * 2 * math.pi,
                rotationX: -0.45 + 0.25 * math.sin(v * 2 * math.pi),
                color: _night ? const Color(0xFF8B5CF6) : MfColors.blue600,
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buttons() {
    Widget button(
      String key,
      IconData icon,
      String label,
      VoidCallback onTap,
    ) => Expanded(
      child: OutlinedButton(
        key: Key('object3d_$key'),
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
    );
    return Row(
      children: [
        button('play', Icons.play_arrow_rounded, 'Oynat', _play),
        const SizedBox(width: 6),
        button('stop', Icons.pause_rounded, 'Durdur', _stop),
        const SizedBox(width: 6),
        button('reverse', Icons.fast_rewind_rounded, 'Geri', () {
          _controller.reverse();
        }),
        const SizedBox(width: 6),
        button(
          'reset',
          Icons.restart_alt_rounded,
          'Başa sar',
          _controller.reset,
        ),
      ],
    );
  }
}

class _LabeledSlider extends StatelessWidget {
  const _LabeledSlider({
    required this.label,
    required this.sliderKey,
    required this.value,
    required this.valueText,
    required this.onChanged,
    this.min = 0,
    this.max = 1,
    this.divisions,
  });

  final String label;
  final Key sliderKey;
  final double value;
  final String valueText;
  final ValueChanged<double> onChanged;
  final double min;
  final double max;
  final int? divisions;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Row(
      children: [
        SizedBox(width: 64, child: Text(label, style: t.titleSmall)),
        Expanded(
          child: Slider(
            key: sliderKey,
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 48,
          child: Text(valueText, textAlign: TextAlign.end, style: t.bodyMedium),
        ),
      ],
    );
  }
}
