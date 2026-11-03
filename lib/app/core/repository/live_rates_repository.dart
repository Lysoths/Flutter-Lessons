import 'package:flutter_ders/app/helper/mock_socket.dart';

/// DERS 13 — Canlı kur akışının nereden geldiğini Bloc'tan gizler.
abstract interface class LiveRatesRepository {
  /// Bağlanır ve sunucudan gelen mesajları akış olarak verir. Akış,
  /// [disconnect] çağrılınca ya da sunucu kapanınca biter.
  Stream<SocketMessage> connect();

  /// Sunucuya metin gönderir.
  void send(String text);

  /// Bağlantıyı kapatır.
  Future<void> disconnect();
}

/// Ders 11'deki sahte WebSocket sunucusunu (telefonun içinde, 127.0.0.1)
/// kullanır. Her saniye sahte kur gelir, gönderilen mesaj geri döner.
class MockLiveRatesRepository implements LiveRatesRepository {
  final MockSocketServer _server = MockSocketServer();
  MockSocketClient? _client;

  @override
  Stream<SocketMessage> connect() async* {
    final uri = await _server.start();
    final client = await MockSocketClient.connect(uri);
    _client = client;
    yield* client.messages;
  }

  @override
  void send(String text) => _client?.send(text);

  @override
  Future<void> disconnect() async {
    await _client?.close();
    _client = null;
    await _server.stop();
  }
}
