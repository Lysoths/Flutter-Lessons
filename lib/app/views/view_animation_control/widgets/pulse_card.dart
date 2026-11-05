import 'package:flutter/material.dart';
import 'package:flutter_ders/app/core/analytics/app_events.dart';
import 'package:flutter_ders/app/theme/app_theme.dart';
import 'package:flutter_ders/app/views/view_animation_control/widgets/curve_option.dart';
import 'package:flutter_ders/app/views/view_animation_control/widgets/pulse_effects.dart';
import 'package:flutter_ders/app/widgets/common.dart';

/// DERS 8 — Bir nabız efektini kendi AnimationController'ıyla oynatan kart.
///
/// Her kartın kendi saati var: biri durunca diğerleri etkilenmez.
class PulseCard extends StatefulWidget {
  /// [effect] için kart oluşturur.
  const PulseCard({required this.effect, super.key});

  /// Oynatılan efekt.
  final PulseEffect effect;

  @override
  State<PulseCard> createState() => _PulseCardState();
}

class _PulseCardState extends State<PulseCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.effect.period,
  )..repeat();

  late CurvedAnimation _curved = CurvedAnimation(
    parent: _controller,
    curve: _curve.curve,
  );

  CurveOption _curve = CurveOption.linear;

  /// Yalnızca bpm kartında kullanılır.
  double _bpm = 72;

  @override
  void dispose() {
    _curved.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    track(AppEvent.pulseToggled, widget.effect.name);
    setState(() {
      if (_controller.isAnimating) {
        _controller.stop();
      } else {
        _controller.repeat();
      }
    });
  }

  void _setCurve(CurveOption option) {
    setState(() {
      _curve = option;
      _curved.dispose();
      _curved = CurvedAnimation(parent: _controller, curve: option.curve);
    });
  }

  void _setBpm(double bpm) {
    setState(() => _bpm = bpm);
    // Bir vuruş = 60 / bpm saniye.
    _controller.duration = Duration(milliseconds: (60000 / bpm).round());
    if (_controller.isAnimating) _controller.repeat();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final e = widget.effect;
    final playing = _controller.isAnimating;
    return Container(
      key: Key('pulse_${e.name}'),
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MfColors.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(e.label, style: t.titleMedium),
          const SizedBox(height: 2),
          Text(e.description, style: t.bodyMedium?.copyWith(fontSize: 13)),
          SizedBox(
            height: 150,
            child: Center(
              child: AnimatedBuilder(
                animation: _curved,
                builder: (context, _) => e.frame(_curved.value),
              ),
            ),
          ),
          if (e == PulseEffect.bpm)
            Row(
              children: [
                Expanded(
                  child: Slider(
                    key: const Key('pulse_bpm_slider'),
                    value: _bpm,
                    min: 40,
                    max: 180,
                    divisions: 28,
                    onChanged: _setBpm,
                  ),
                ),
                SizedBox(
                  width: 64,
                  child: Text(
                    '${_bpm.round()} bpm',
                    key: const Key('pulse_bpm_value'),
                    style: t.titleSmall,
                  ),
                ),
              ],
            ),
          Row(
            children: [
              FilledButton.tonalIcon(
                key: Key('pulse_${e.name}_toggle'),
                onPressed: _toggle,
                // Temadaki düğmeler tam genişlik; satır içinde kendi boyu.
                style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                icon: Icon(
                  playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                ),
                label: Text(playing ? 'Durdur' : 'Oynat'),
              ),
              const SizedBox(width: 8),
              // Dar ekranda taşmasın: kalan yeri alır, sığmazsa küçülür.
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: PopupMenuButton<CurveOption>(
                    key: Key('pulse_${e.name}_curve'),
                    initialValue: _curve,
                    onSelected: _setCurve,
                    itemBuilder: (_) => [
                      for (final c in CurveOption.values)
                        PopupMenuItem(value: c, child: Text(c.label)),
                    ],
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Eyebrow('Eğri: ${_curve.label} ▾'),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
