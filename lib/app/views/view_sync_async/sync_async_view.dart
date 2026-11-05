import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_ders/app/core/analytics/app_events.dart';
import 'package:flutter_ders/app/helper/sync_async_demo.dart';
import 'package:flutter_ders/app/theme/app_theme.dart';
import 'package:flutter_ders/app/widgets/common.dart';

/// Bir çalıştırmanın sonucu.
typedef _RunResult = ({WorkMode mode, Duration total, Duration longestFreeze});

/// DERS 10 — Sync ve async farkını canlı gösteren sayfa.
///
/// Üstteki çark ve kare sayacı ana iş parçacığının nabzıdır: her karede
/// ilerler. Bir iş ana iş parçacığını kilitlerse ikisi de durur. Kareler
/// arasındaki en uzun boşluk "donma süresi" olarak ölçülür.
@RoutePage()
class SyncAsyncView extends StatefulWidget {
  /// Sayfayı oluşturur.
  const SyncAsyncView({super.key});

  @override
  State<SyncAsyncView> createState() => _SyncAsyncViewState();
}

class _SyncAsyncViewState extends State<SyncAsyncView>
    with TickerProviderStateMixin {
  /// Her senaryonun süresi.
  static const _workMs = 2000;

  /// Bundan uzun kare boşluğu "dondu" sayılır.
  static const _freezeLimit = Duration(milliseconds: 200);

  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  )..repeat();

  /// Her karede çağrılır; kareler arası boşluğu ölçer.
  late final Ticker _ticker = createTicker(_onFrame);
  final ValueNotifier<int> _frames = ValueNotifier(0);
  Duration _lastFrame = Duration.zero;
  Duration _longestGap = Duration.zero;
  bool _measuring = false;

  WorkMode? _running;
  final List<_RunResult> _results = [];
  final List<String> _order = [];

  @override
  void initState() {
    super.initState();
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _spin.dispose();
    _frames.dispose();
    super.dispose();
  }

  void _onFrame(Duration elapsed) {
    final gap = elapsed - _lastFrame;
    _lastFrame = elapsed;
    if (_measuring && gap > _longestGap) _longestGap = gap;
    _frames.value++;
  }

  Future<void> _run(WorkMode mode) async {
    track(AppEvent.syncAsyncRun, mode.name);
    setState(() => _running = mode);
    // "Çalışıyor" yazısı ekrana çizilsin, sonra iş başlasın.
    await WidgetsBinding.instance.endOfFrame;
    _longestGap = Duration.zero;
    _measuring = true;
    final watch = Stopwatch()..start();
    await mode.run(_workMs);
    watch.stop();
    // İşten sonraki ilk kare, donmanın ne kadar sürdüğünü ölçer.
    await WidgetsBinding.instance.endOfFrame;
    _measuring = false;
    if (!mounted) return;
    setState(() {
      _running = null;
      _results.insert(0, (
        mode: mode,
        total: watch.elapsed,
        longestFreeze: _longestGap,
      ));
    });
  }

  Future<void> _runOrder() async {
    track(AppEvent.orderRun);
    setState(_order.clear);
    await runOrderDemo((step) => setState(() => _order.add(step)));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync / Async'),
        titleTextStyle: t.titleLarge,
      ),
      body: ListView(
        key: const Key('syncAsync_list'),
        padding: pagePadding(context).copyWith(top: 8, bottom: 32),
        children: [
          const SectionHeader(
            eyebrow: 'Ders 10',
            title: 'Senkron mu, asenkron mu?',
            body:
                'Dart tek iş parçacığında çalışır: ekranı çizen ile '
                'düğmenin kodu aynı sıradadır. Aşağıdaki çark her karede '
                'döner; bir iş sırayı kilitlerse çark da durur.',
          ),
          const Gap(16),
          _heartbeat(t),
          const Gap(20),
          Text('Aynı 2 saniyelik iş, dört yol', style: t.titleLarge),
          const Gap(10),
          for (final m in WorkMode.values) ...[
            _ModeCard(
              mode: m,
              running: _running == m,
              enabled: _running == null,
              result: _results.where((r) => r.mode == m).firstOrNull,
              freezeLimit: _freezeLimit,
              onRun: () => _run(m),
            ),
            const Gap(10),
          ],
          const Gap(16),
          Text('Çalışma sırası (event loop)', style: t.titleLarge),
          const Gap(4),
          Text(
            'Satırlar kodda bu sırayla yazıldı; çıktıdaki numaralar '
            'çalıştıkları sıradır.',
            style: t.bodyMedium,
          ),
          const Gap(10),
          const _CodeBox(kOrderDemoCode),
          const Gap(10),
          FilledButton.tonal(
            key: const Key('syncAsync_order'),
            onPressed: _runOrder,
            child: const Text('Sırayı göster'),
          ),
          const Gap(8),
          for (final (i, step) in _order.indexed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text(
                step,
                key: Key('syncAsync_step_$i'),
                style: t.bodyMedium?.copyWith(color: MfColors.slate900),
              ),
            ),
          const Gap(24),
          Text('Depolamada sync / async', style: t.titleLarge),
          const Gap(10),
          const _StorageTable(),
        ],
      ),
    );
  }

  Widget _heartbeat(TextTheme t) {
    final busy = _running != null;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MfColors.slate50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MfColors.slate200),
      ),
      child: Row(
        children: [
          RotationTransition(
            turns: _spin,
            child: const Icon(
              Icons.settings_rounded,
              size: 56,
              color: MfColors.blue600,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ana iş parçacığının nabzı', style: t.titleSmall),
                const SizedBox(height: 4),
                ValueListenableBuilder<int>(
                  valueListenable: _frames,
                  builder: (context, frames, _) => Text(
                    'Çizilen kare: $frames',
                    key: const Key('syncAsync_frames'),
                    style: t.titleMedium?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  busy ? 'Çalışıyor: ${_running!.label}…' : 'Boşta',
                  style: t.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.mode,
    required this.running,
    required this.enabled,
    required this.result,
    required this.freezeLimit,
    required this.onRun,
  });

  final WorkMode mode;
  final bool running;
  final bool enabled;
  final _RunResult? result;
  final Duration freezeLimit;
  final VoidCallback onRun;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final r = result;
    final froze = r != null && r.longestFreeze > freezeLimit;
    return Material(
      key: Key('syncAsync_mode_${mode.name}'),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: MfColors.slate200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(mode.label, style: t.titleMedium),
            const Gap(6),
            _CodeBox(mode.code),
            const Gap(6),
            Text(mode.explanation, style: t.bodyMedium),
            const Gap(10),
            Row(
              children: [
                FilledButton(
                  key: Key('syncAsync_run_${mode.name}'),
                  onPressed: enabled ? onRun : null,
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                  child: Text(running ? 'Çalışıyor…' : 'Çalıştır'),
                ),
                const SizedBox(width: 10),
                if (r != null)
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        Eyebrow(
                          froze ? 'Ekran DONDU' : 'Ekran AKTI',
                          key: Key('syncAsync_verdict_${mode.name}'),
                          color: froze ? MfColors.red600 : MfColors.emerald500,
                          background:
                              (froze ? MfColors.red600 : MfColors.emerald500)
                                  .withValues(alpha: 0.1),
                        ),
                        Eyebrow(
                          'donma ${r.longestFreeze.inMilliseconds} ms',
                          color: MfColors.slate600,
                          background: MfColors.slate100,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CodeBox extends StatelessWidget {
  const _CodeBox(this.code);

  final String code;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: MfColors.terminal,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        code,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          height: 1.45,
          color: Color(0xFFA5F3FC),
        ),
      ),
    );
  }
}

class _StorageTable extends StatelessWidget {
  const _StorageTable();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    const rows = [
      (
        'SharedPreferences',
        'getInstance() async',
        'getString() sync — açılışta hepsi belleğe okunur',
      ),
      (
        'Hive',
        'openBox() async',
        'box.get() sync — kutu bellekte, yazma diske arkadan',
      ),
      (
        'sqflite',
        'openDatabase() async',
        'query() async — her okuma diske SQL sorgusu',
      ),
    ];
    return Column(
      children: [
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: MfColors.slate200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.$1, style: t.titleSmall),
                  const SizedBox(height: 4),
                  Text('Açma: ${r.$2}', style: t.bodyMedium),
                  Text('Okuma: ${r.$3}', style: t.bodyMedium),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
