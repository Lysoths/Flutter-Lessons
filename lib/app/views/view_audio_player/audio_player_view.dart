import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ders/app/core/analytics/app_events.dart';
import 'package:flutter_ders/app/models/document_item.dart';
import 'package:flutter_ders/app/theme/app_theme.dart';
import 'package:flutter_ders/app/widgets/common.dart';
import 'package:just_audio/just_audio.dart';

/// DERS 5 — Ses asset: `just_audio` ile `setAsset` → `play`.
///
/// Oynatıcı bu ekranla birlikte yaşar: ekran açılınca oluşturulur,
/// kapanınca `dispose` ile durdurulur (yoksa ses arka planda sürer).
@RoutePage()
class AudioPlayerView extends StatefulWidget {
  /// [document] sesini çalar.
  const AudioPlayerView({required this.document, super.key});

  /// Çalınan belge.
  final DocumentItem document;

  @override
  State<AudioPlayerView> createState() => _AudioPlayerViewState();
}

class _AudioPlayerViewState extends State<AudioPlayerView> {
  final _player = AudioPlayer();
  Duration? _duration;
  Object? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final duration = await _player.setAsset(widget.document.assetPath);
      if (mounted) setState(() => _duration = duration);
    } on Object catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _toggle(PlayerState state) async {
    track(AppEvent.audioToggled, state.playing ? 'durdur' : 'oynat');
    if (state.processingState == ProcessingState.completed) {
      await _player.seek(Duration.zero);
    }
    if (state.playing && state.processingState != ProcessingState.completed) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  @override
  void dispose() {
    unawaited(_player.dispose());
    super.dispose();
  }

  static String _format(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    const accent = Color(0xFF8B5CF6);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.document.title),
        titleTextStyle: t.titleLarge,
      ),
      body: Padding(
        padding: pagePadding(context),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const IconBadge(Icons.graphic_eq_rounded, accent: accent, size: 96),
            const Gap(20),
            Text(widget.document.title, style: t.headlineSmall),
            const Gap(6),
            Text(
              widget.document.description,
              style: t.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const Gap(32),
            if (_error != null)
              Text('Ses yüklenemedi: $_error', style: t.bodyMedium)
            else ...[
              StreamBuilder<Duration>(
                stream: _player.positionStream,
                builder: (context, snapshot) {
                  final total = _duration ?? Duration.zero;
                  final position = snapshot.data ?? Duration.zero;
                  final max = total.inMilliseconds.toDouble();
                  return Column(
                    children: [
                      Slider(
                        activeColor: accent,
                        max: max <= 0 ? 1 : max,
                        value: position.inMilliseconds
                            .clamp(0, max <= 0 ? 1 : max)
                            .toDouble(),
                        onChanged: max <= 0
                            ? null
                            : (v) => _player.seek(
                                Duration(milliseconds: v.round()),
                              ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_format(position), style: t.bodySmall),
                          Text(_format(total), style: t.bodySmall),
                        ],
                      ),
                    ],
                  );
                },
              ),
              const Gap(16),
              StreamBuilder<PlayerState>(
                stream: _player.playerStateStream,
                builder: (context, snapshot) {
                  final state = snapshot.data;
                  final playing =
                      (state?.playing ?? false) &&
                      state?.processingState != ProcessingState.completed;
                  return IconButton.filled(
                    key: const Key('audioPlayer_toggle'),
                    iconSize: 40,
                    style: IconButton.styleFrom(
                      backgroundColor: MfColors.slate900,
                      foregroundColor: Colors.white,
                      fixedSize: const Size(72, 72),
                    ),
                    onPressed: state == null || _duration == null
                        ? null
                        : () => _toggle(state),
                    icon: Icon(
                      playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    ),
                  );
                },
              ),
            ],
            const Gap(24),
            Text(
              widget.document.source,
              style: t.bodySmall?.copyWith(color: MfColors.slate500),
            ),
          ],
        ),
      ),
    );
  }
}
