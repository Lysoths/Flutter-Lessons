import 'dart:async';
import 'dart:isolate';

// ─────────────────────────────────────────────────────────────────────────
// DERS 10 — Sync ve async
//
// Dart TEK bir iş parçacığında (main isolate) çalışır. Ekranı çizen de,
// düğmeye basınca çalışan kod da aynı sıradadır. Sıra şöyle döner
// (event loop):
//   1. Senkron kod sonuna kadar çalışır; araya hiçbir şey giremez.
//   2. Sonra microtask kuyruğu boşaltılır (scheduleMicrotask, await devamı).
//   3. Sonra olay kuyruğundan bir iş alınır (Future(), Timer, dokunma,
//      bir sonraki kare çizimi...).
//
// async/await işi PARALEL yapmaz; yalnızca "beklerken sırayı bırakır".
// Ağır hesap async fonksiyonda da olsa ana iş parçacığını kilitler.
// Gerçekten paralel çalışmak için ayrı bir isolate gerekir (Isolate.run).
// ─────────────────────────────────────────────────────────────────────────

/// İşlemciyi [ms] milisaniye boyunca bilerek meşgul eder (ağır hesap
/// yerine). Döngünün kaç tur döndüğünü verir.
int busyWork(int ms) {
  final watch = Stopwatch()..start();
  var turns = 0;
  while (watch.elapsedMilliseconds < ms) {
    turns++;
  }
  return turns;
}

/// Aynı süreli işi dört farklı biçimde çalıştırma yolu.
enum WorkMode {
  /// Doğrudan çağır: ana iş parçacığı iş bitene kadar kilitli.
  sync(
    'Senkron ağır iş',
    'busyWork(2000);',
    'İş bitene kadar başka hiçbir şey çalışamaz: çark durur, dokunmalar '
        'bekler, ekran donar.',
  ),

  /// Bekleme: işlemci boşta, sıra başkalarına verilir.
  asyncWait(
    'Async bekleme',
    'await Future.delayed(2 sn);',
    'Ağ / disk beklemesi gibi: işlemci boşta. await sırayı bırakır, ekran '
        'akmaya devam eder.',
  ),

  /// async fonksiyonda ağır iş: yine kilitler.
  asyncHeavy(
    'Async ama ağır iş',
    'await Future(() => busyWork(2000));',
    'async yazmak işi paralel yapmaz! İş olay kuyruğundan alınınca yine ana '
        'iş parçacığında çalışır ve ekran yine donar.',
  ),

  /// Ayrı isolate: gerçekten paralel.
  isolate(
    'Isolate (paralel)',
    'await Isolate.run(() => busyWork(2000));',
    'Hesap başka bir çekirdekte, kendi belleğiyle çalışır. Ana iş parçacığı '
        'yalnızca sonucu bekler; ekran akar.',
  );

  const WorkMode(this.label, this.code, this.explanation);

  /// Görünen ad.
  final String label;

  /// Örnek kod.
  final String code;

  /// Ne olduğunun açıklaması.
  final String explanation;

  /// [ms] milisaniyelik işi bu yolla çalıştırır.
  Future<void> run(int ms) async {
    switch (this) {
      case WorkMode.sync:
        busyWork(ms);
      case WorkMode.asyncWait:
        await Future<void>.delayed(Duration(milliseconds: ms));
      case WorkMode.asyncHeavy:
        await Future(() => busyWork(ms));
      case WorkMode.isolate:
        await Isolate.run(() => busyWork(ms));
    }
  }
}

/// Satırların YAZILDIĞI sıra; çıktıdaki numaralar ÇALIŞTIĞI sıradır.
const kOrderDemoCode = '''
log('1 senkron: başladı');
Future(() => log('5 Future()'));
Future.delayed(Duration.zero, () => log('6 Future.delayed(0)'));
scheduleMicrotask(() => log('4 microtask'));
final f = yavasDeger();   // içinde: log('2 ...'); await ...
log('3 senkron: son satır');
await f;
log('7 await sonrası');''';

/// Event loop sırasını gösteren örnek: [log] 1'den 7'ye sırayla çağrılır,
/// ama satırlar kodda bu sırada YAZILMAMIŞTIR (bkz. [kOrderDemoCode]).
Future<void> runOrderDemo(void Function(String step) log) async {
  log('1 · senkron: fonksiyon başladı');
  // unawaited: bilerek beklemiyoruz; olay kuyruğuna bırakıp devam ediyoruz.
  unawaited(Future(() => log('5 · Future(): olay kuyruğundan')));
  unawaited(
    Future<void>.delayed(
      Duration.zero,
      () => log('6 · Future.delayed(0): olay kuyruğundan'),
    ),
  );
  scheduleMicrotask(() => log('4 · microtask: senkron kod biter bitmez'));
  final pending = _slowValue(log);
  log('3 · senkron: fonksiyonun son satırı');
  await pending;
  log('7 · await sonrası: beklenen iş bitti');
}

Future<void> _slowValue(void Function(String step) log) async {
  log("2 · async fonksiyon: ilk await'e kadar SENKRON çalışır");
  await Future<void>.delayed(const Duration(milliseconds: 50));
}
