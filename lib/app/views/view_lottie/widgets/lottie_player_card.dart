import 'package:flutter/material.dart';
import 'package:flutter_ders/app/core/analytics/app_events.dart';
import 'package:flutter_ders/app/models/lottie_item.dart';
import 'package:flutter_ders/app/theme/app_theme.dart';
import 'package:flutter_ders/app/widgets/common.dart';
import 'package:lottie/lottie.dart';

/// DERS 9 — Bir Lottie animasyonunu Ders 8'deki AnimationController ile
/// oynatan kart.
///
/// `Lottie.asset` JSON'u okur ve bir `LottieComposition` (katmanlar,
/// kareler, süre) üretir. `controller` verilirse animasyonun saatini biz
/// yönetiriz: value 0.0 → ilk kare, 1.0 → son kare.
class LottiePlayerCard extends StatefulWidget {
  /// [item] için oynatıcı oluşturur.
  const LottiePlayerCard({required this.item, super.key});

  /// Oynatılan animasyon.
  final LottieItem item;

  @override
  State<LottiePlayerCard> createState() => _LottiePlayerCardState();
}

class _LottiePlayerCardState extends State<LottiePlayerCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);

  LottieComposition? _composition;
  double _speed = 1;
  bool _recolor = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onLoaded(LottieComposition composition) {
    setState(() => _composition = composition);
    // Süre JSON'dan gelir: (op - ip) / fr saniye.
    _controller
      ..duration = composition.duration * (1 / _speed)
      ..repeat();
  }

  void _toggle() {
    track(AppEvent.lottieToggled);
    setState(() {
      if (_controller.isAnimating) {
        _controller.stop();
      } else {
        _controller.repeat();
      }
    });
  }

  void _setSpeed(double speed) {
    final c = _composition;
    if (c == null) return;
    setState(() => _speed = speed);
    _controller.duration = c.duration * (1 / speed);
    if (_controller.isAnimating) _controller.repeat();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = _composition;
    // Material: içindeki SwitchListTile'ın dokunma efekti görünsün.
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: MfColors.slate200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 220,
              child: Lottie.asset(
                widget.item.assetPath,
                key: Key('lottiePlayer_${widget.item.id}'),
                controller: _controller,
                onLoaded: _onLoaded,
                fit: BoxFit.contain,
                // Çalışma anında renk değiştirme: JSON'daki tüm dolgu ve
                // çizgi renkleri ('**' = her katman) tek renge boyanır.
                // Video/GIF'te bu mümkün değildir; Lottie veri olduğu için
                // mümkündür.
                delegates: _recolor
                    ? LottieDelegates(
                        values: [
                          ValueDelegate.color(const [
                            '**',
                          ], value: MfColors.emerald500),
                          ValueDelegate.strokeColor(const [
                            '**',
                          ], value: MfColors.emerald500),
                        ],
                      )
                    : null,
                errorBuilder: (context, error, _) =>
                    const Center(child: Text('Animasyon okunamadı')),
              ),
            ),
            const Gap(8),
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final frame = c == null
                    ? 0
                    : (c.startFrame + c.durationFrames * _controller.value)
                          .floor();
                return Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Eyebrow(
                      c == null
                          ? 'Yükleniyor…'
                          : 'Kare $frame / ${c.endFrame.floor()}',
                      key: const Key('lottiePlayer_frame'),
                    ),
                    if (c != null)
                      Eyebrow(
                        '${c.frameRate.toStringAsFixed(0)} fps · '
                        '${(c.duration.inMilliseconds / 1000).toStringAsFixed(2)} sn',
                        color: MfColors.slate600,
                        background: MfColors.slate100,
                      ),
                  ],
                );
              },
            ),
            const Gap(8),
            // İlerleme: controller.value'yu elle yazmak = istenen kareye git.
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => Slider(
                key: const Key('lottiePlayer_progress'),
                value: _controller.value,
                onChanged: c == null
                    ? null
                    : (v) => setState(() {
                        _controller
                          ..stop()
                          ..value = v;
                      }),
              ),
            ),
            Row(
              children: [
                Text('Hız', style: t.titleSmall),
                Expanded(
                  child: Slider(
                    key: const Key('lottiePlayer_speed'),
                    value: _speed,
                    min: 0.25,
                    max: 3,
                    divisions: 11,
                    onChanged: c == null ? null : _setSpeed,
                  ),
                ),
                SizedBox(
                  width: 44,
                  child: Text(
                    '${_speed.toStringAsFixed(2)}x',
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
            SwitchListTile(
              key: const Key('lottiePlayer_recolor'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Renkleri değiştir'),
              subtitle: const Text('LottieDelegates: JSON çalışırken boyanır'),
              value: _recolor,
              onChanged: (v) => setState(() => _recolor = v),
            ),
            FilledButton.tonalIcon(
              key: const Key('lottiePlayer_toggle'),
              onPressed: c == null ? null : _toggle,
              icon: Icon(
                _controller.isAnimating
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
              ),
              label: Text(_controller.isAnimating ? 'Durdur' : 'Oynat'),
            ),
          ],
        ),
      ),
    );
  }
}
