import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

// ─────────────────────────────────────────────────────────────────────────
// DERS 11 — Sahte (mock) WebSocket sunucusu
//
// Gerçek bir sunucu kurmak yerine telefonun İÇİNDE, yalnızca telefondan
// erişilebilen bir adreste (127.0.0.1) küçük bir WebSocket sunucusu
// açıyoruz. Paket yok, hesap yok, internet gerekmez:
//   • Her saniye sahte bir döviz kuru gönderir (canlı veri akışı).
//   • Gönderdiğiniz mesajı geri yollar (echo).
// İstemci tarafı gerçek bir WebSocket'tir; sunucu adresi değişse uygulama
// kodu aynı kalır.
// ─────────────────────────────────────────────────────────────────────────

/// Sunucudan gelen mesajlar (detay ekranındaki sealed sonuç sınıfları gibi).
sealed class SocketMessage {
  const SocketMessage(this.at);

  /// JSON mesajını çözer.
  factory SocketMessage.fromJson(Map<String, Object?> json) {
    final at = DateTime.parse(json['at']! as String);
    return switch (json['type']) {
      'kur' => RateTick(
        usd: (json['usd']! as num).toDouble(),
        eur: (json['eur']! as num).toDouble(),
        at: at,
      ),
      _ => EchoReply(json['text']! as String, at),
    };
  }

  /// Sunucunun gönderdiği zaman.
  final DateTime at;
}

/// Sahte döviz kuru.
final class RateTick extends SocketMessage {
  /// Bir kur mesajı oluşturur.
  const RateTick({required this.usd, required this.eur, required DateTime at})
    : super(at);

  /// USD/TRY.
  final double usd;

  /// EUR/TRY.
  final double eur;
}

/// Gönderilen mesajın sunucudan dönüşü.
final class EchoReply extends SocketMessage {
  /// Bir yankı mesajı oluşturur.
  const EchoReply(this.text, DateTime at) : super(at);

  /// Gönderilen metin.
  final String text;
}

/// Telefonun içinde çalışan sahte WebSocket sunucusu.
class MockSocketServer {
  /// Sunucuyu oluşturur; [tick] aralığıyla kur gönderir.
  MockSocketServer({this.tick = const Duration(seconds: 1), Random? random})
    : _random = random ?? Random();

  /// Kur gönderme aralığı.
  final Duration tick;

  final Random _random;
  HttpServer? _server;
  final Set<Timer> _timers = {};

  /// Sunucunun adresi (başlamadıysa `null`).
  Uri? get uri {
    final s = _server;
    return s == null ? null : Uri.parse('ws://127.0.0.1:${s.port}');
  }

  /// Boş bir portta başlar ve adresini döndürür.
  Future<Uri> start() async {
    if (_server == null) {
      // Port 0 → işletim sistemi boş bir port seçer. loopback → yalnızca
      // bu telefon bağlanabilir, ağdaki başka cihazlar göremez.
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      _server = server;
      server.listen(_onRequest);
    }
    return uri!;
  }

  Future<void> _onRequest(HttpRequest request) async {
    if (!WebSocketTransformer.isUpgradeRequest(request)) {
      request.response.statusCode = HttpStatus.badRequest;
      await request.response.close();
      return;
    }
    final ws = await WebSocketTransformer.upgrade(request);
    var usd = 41.20;
    var eur = 47.80;
    String now() => DateTime.now().toIso8601String();

    final timer = Timer.periodic(tick, (_) {
      // Rastgele küçük adımlarla yürüyen sahte kur.
      usd += (_random.nextDouble() - 0.5) * 0.12;
      eur += (_random.nextDouble() - 0.5) * 0.14;
      ws.add(jsonEncode({'type': 'kur', 'usd': usd, 'eur': eur, 'at': now()}));
    });
    _timers.add(timer);
    ws.listen(
      (data) =>
          ws.add(jsonEncode({'type': 'echo', 'text': '$data', 'at': now()})),
      onDone: () {
        timer.cancel();
        _timers.remove(timer);
      },
    );
  }

  /// Sunucuyu ve açık bağlantıların zamanlayıcılarını kapatır.
  Future<void> stop() async {
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
    await _server?.close(force: true);
    _server = null;
  }
}

/// [uri] adresindeki WebSocket'e bağlanır; gelen JSON'ları
/// [SocketMessage] akışına çevirir.
class MockSocketClient {
  MockSocketClient._(this._socket);

  /// Bağlanır.
  static Future<MockSocketClient> connect(Uri uri) async =>
      MockSocketClient._(await WebSocket.connect(uri.toString()));

  final WebSocket _socket;

  /// Sunucudan gelen mesajlar: STREAM.
  late final Stream<SocketMessage> messages = _socket.map(
    (data) => SocketMessage.fromJson(
      jsonDecode(data as String) as Map<String, Object?>,
    ),
  );

  /// Sunucuya metin gönderir.
  void send(String text) => _socket.add(text);

  /// Bağlantıyı kapatır.
  Future<void> close() => _socket.close();
}
