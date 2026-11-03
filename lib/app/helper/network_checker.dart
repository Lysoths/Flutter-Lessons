import 'dart:async';
import 'dart:io';

// ─────────────────────────────────────────────────────────────────────────
// DERS 11 — Ağ kontrolü: Future ve Stream
//
// Future = TEK cevap, ileride gelecek: "internet var mı?" → bir kez sorulur,
//          bir kez cevaplanır. Ekranda FutureBuilder ile gösterilir.
// Stream = cevaplar AKIŞI: "internet durumu değiştikçe haber ver" → her
//          birkaç saniyede bir yeni cevap. Ekranda StreamBuilder ile.
//
// Kontrol yöntemi: bir alan adını (example.com) DNS ile IP adresine
// çevirmeyi deneriz. Wi-Fi'ye bağlı olmak internete çıkabilmek demek
// değildir; gerçekten dışarıya ulaşabiliyor muyuz, ona bakarız.
// ─────────────────────────────────────────────────────────────────────────

/// Bir kontrolün sonucu.
typedef NetworkResult = ({
  bool online,
  Duration latency,
  DateTime checkedAt,
  String detail,
});

/// İnternete ulaşılıp ulaşılamadığını kontrol eden helper.
class NetworkChecker {
  /// Helper'ı oluşturur. [probe] testte gerçek ağ yerine kullanılır.
  NetworkChecker({
    this._probe,
    this.host = 'example.com',
    this.timeout = const Duration(seconds: 3),
  });

  /// Adresi çözülmeye çalışılan alan adı.
  final String host;

  /// Bu süre içinde cevap gelmezse çevrimdışı sayılır.
  final Duration timeout;

  final Future<bool> Function()? _probe;

  /// Akışı dinleyenlere "hemen yeniden kontrol et" diyen fonksiyonlar.
  final List<void Function()> _pokes = [];

  bool _simulateOffline = false;

  /// Derste Wi-Fi'yi kapatmadan çevrimdışını göstermek için.
  bool get simulateOffline => _simulateOffline;

  set simulateOffline(bool value) {
    _simulateOffline = value;
    refresh();
  }

  Future<bool> _lookup() async {
    final addresses = await InternetAddress.lookup(host).timeout(timeout);
    return addresses.isNotEmpty && addresses.first.rawAddress.isNotEmpty;
  }

  /// FUTURE: bir kez kontrol eder, bir kez cevap verir.
  Future<NetworkResult> check() async {
    final watch = Stopwatch()..start();
    NetworkResult result(bool online, String detail) => (
      online: online,
      latency: watch.elapsed,
      checkedAt: DateTime.now(),
      detail: detail,
    );

    if (_simulateOffline) {
      return result(false, 'Simülasyon: çevrimdışı gibi davranılıyor');
    }
    try {
      final ok = await (_probe ?? _lookup)();
      return result(ok, ok ? '$host adresine ulaşıldı' : '$host bulunamadı');
    } on TimeoutException {
      return result(false, 'Zaman aşımı (${timeout.inSeconds} sn)');
    } on SocketException catch (e) {
      return result(false, 'Ağ hatası: ${e.osError?.message ?? e.message}');
    }
  }

  /// STREAM: hemen bir kez, sonra her [every] sürede bir kontrol eder.
  /// Dinleyen kalmayınca zamanlayıcı durur.
  Stream<NetworkResult> watch({Duration every = const Duration(seconds: 5)}) {
    late final StreamController<NetworkResult> controller;
    Timer? timer;

    Future<void> tick() async {
      final r = await check();
      if (!controller.isClosed) controller.add(r);
    }

    void poke() => unawaited(tick());

    controller = StreamController<NetworkResult>(
      onListen: () {
        poke();
        timer = Timer.periodic(every, (_) => poke());
        _pokes.add(poke);
      },
      onCancel: () {
        timer?.cancel();
        _pokes.remove(poke);
        return controller.close();
      },
    );
    return controller.stream;
  }

  /// Akışı dinleyenlerin hepsine hemen yeni bir kontrol yaptırır.
  void refresh() {
    for (final poke in [..._pokes]) {
      poke();
    }
  }
}
