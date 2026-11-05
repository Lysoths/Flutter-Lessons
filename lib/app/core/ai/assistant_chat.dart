import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter_ders/app/core/ai/assistant_persona.dart';
import 'package:flutter_ders/app/core/ai/expense_toolbox.dart';

// ─────────────────────────────────────────────────────────────────────────
// DERS 20 — Firebase AI Logic (Gemini Developer API)
//
//   FirebaseAI.googleAI()          Firebase projesi üzerinden Gemini; API
//                                  anahtarı uygulamada durmaz, istekler
//                                  App Check ve oturumla birlikte gider.
//   .generativeModel(              model adı Remote Config'ten gelir
//      systemInstruction: persona, tools: araçlar)
//   .startChat()                   geçmişi oturum kendisi tutar
//
// Bir tur: kullanıcı metni → model ya metin ya da araç çağrısı döner →
// araçlar çalışır → sonuçları modele gider → model metinle bitirir.
// ─────────────────────────────────────────────────────────────────────────

/// Modelin bir turdaki cevabı.
final class ModelTurn {
  /// Oluşturur.
  const ModelTurn({this.text, this.calls = const []});

  /// Metin.
  final String? text;

  /// Araç çağrıları.
  final List<ToolCall> calls;
}

/// Bir aracın modele dönen sonucu.
typedef ToolReply = ({ToolCall call, Map<String, Object?> response});

/// Sohbet oturumu; testte senaryolu sahtesi verilir.
abstract interface class AssistantChat {
  /// Kullanıcı mesajı.
  Future<ModelTurn> sendText(String text);

  /// Araç sonuçları.
  Future<ModelTurn> sendToolReplies(List<ToolReply> replies);
}

/// Yeni bir sohbet oturumu açar.
typedef AssistantChatFactory = AssistantChat Function();

/// Asistan hatası (ekranda kısa metin).
enum AssistantFailure {
  /// AI Logic projede açık değil.
  notEnabled('Firebase AI Logic bu projede açık değil.'),

  /// Kota doldu.
  quota('Ücretsiz kota doldu; biraz sonra yeniden dene.'),

  /// Bölge desteklenmiyor.
  location('Bu bölgede Gemini kullanılamıyor.'),

  /// Ağ yok ya da sunucu hatası.
  network('Asistana ulaşılamadı; bağlantını kontrol et.'),

  /// Yanıt engellendi.
  blocked('Bu mesaja yanıt verilemedi.'),

  /// App Check doğrulanamadı (uygulamanın resmi kopyası değil ya da
  /// debug belirteci kayıtlı değil).
  appCheck('Uygulama doğrulanamadı; asistan yalnız resmi uygulamada çalışır.'),

  /// Dakikalık sınır (uygulama içi).
  perMinute('Çok hızlı yazıyorsun; bir dakika sonra yeniden dene.'),

  /// Günlük sınır (uygulama içi).
  perDay('Bugünkü asistan hakkın doldu; yarın yeniden dene.'),

  /// Diğer.
  unknown('Beklenmeyen bir hata oldu.');

  const AssistantFailure(this.message);

  /// Ekranda.
  final String message;

  /// Hatanın kodu (Analytics seçeneği).
  String get code => name;

  /// İstisnadan çevirir.
  static AssistantFailure from(Object e) => switch (e) {
    ServiceApiNotEnabled() => notEnabled,
    QuotaExceeded() => quota,
    UnsupportedUserLocation() => location,
    FirebaseAIException(:final message)
        when message.contains('App Check') ||
            message.contains('app_check') ||
            message.contains('PERMISSION_DENIED') =>
      appCheck,
    ServerException() => network,
    FirebaseAIException(:final message)
        when message.toLowerCase().contains('block') =>
      blocked,
    FirebaseAIException(:final message)
        when message.toLowerCase().contains('socket') ||
            message.toLowerCase().contains('network') =>
      network,
    _ => unknown,
  };
}

/// Modelin gördüğü araç tanımları.
List<FunctionDeclaration> assistantFunctionDeclarations() => [
  FunctionDeclaration(
    AssistantTools.add,
    'Kullanıcının söylediği bir masrafı kaydeder.',
    parameters: {
      'tutar': Schema.number(description: 'Türk lirası tutar, ör. 249.90'),
      'kategori': Schema.enumString(
        enumValues: kAssistantCategories.keys.toList(),
        description: 'Masrafın kategorisi',
      ),
      'not': Schema.string(
        description: 'Kullanıcının sözünden kısa not (en çok 6 kelime)',
      ),
      'tarih': Schema.string(
        description: 'YYYY-AA-GG; kullanıcı gün söylemediyse boş bırak',
      ),
    },
    optionalParameters: ['not', 'tarih'],
  ),
  FunctionDeclaration(
    AssistantTools.edit,
    'Son kaydı (bu sohbette eklenen ya da en yeni harcama) düzeltir. '
    'Yalnız değişen alanları ver.',
    parameters: {
      'tutar': Schema.number(description: 'Yeni tutar'),
      'kategori': Schema.enumString(
        enumValues: kAssistantCategories.keys.toList(),
      ),
      'not': Schema.string(description: 'Yeni not'),
      'tarih': Schema.string(description: 'Yeni tarih, YYYY-AA-GG'),
    },
    optionalParameters: ['tutar', 'kategori', 'not', 'tarih'],
  ),
  FunctionDeclaration(
    AssistantTools.delete,
    'Son kaydı (bu sohbette eklenen ya da en yeni harcama) siler.',
    parameters: {},
  ),
  FunctionDeclaration(
    AssistantTools.summary,
    'Bir dönemin harcama özeti: toplam, adet, günlük ortalama ve kategori '
    'payları. Harcama soruları ve tasarruf önerileri için.',
    parameters: {'donem': Schema.enumString(enumValues: kSummaryPeriods)},
  ),
  FunctionDeclaration(
    AssistantTools.refuse,
    'Uygulamanın kullanım alanı (harcama takibi) dışındaki her isteği '
    'reddeder. Çağırınca başka metin yazma.',
    parameters: {
      'sebep': Schema.string(description: 'Kısa sebep, ör. "hava durumu"'),
    },
  ),
];

/// Firebase olmadan (testler): her mesaja aynı kısa yanıt.
class OfflineAssistantChat implements AssistantChat {
  @override
  Future<ModelTurn> sendText(String text) async =>
      const ModelTurn(text: 'Asistan bu derlemede çevrimdışı.');

  @override
  Future<ModelTurn> sendToolReplies(List<ToolReply> replies) async =>
      const ModelTurn();
}

/// Firebase AI Logic ile gerçek oturum.
class FirebaseAssistantChat implements AssistantChat {
  /// [model] Remote Config'teki `asistan_modeli`.
  FirebaseAssistantChat({required String model, DateTime Function()? now})
    // Güvenlik: istekler App Check belirteciyle gider. "Limited use"
    // belirteç tek kullanımlıktır; ele geçirilip tekrar oynatılamaz
    // (replay protection). Konsolda AI Logic için App Check zorunlu
    // kılınınca, resmi uygulama dışındaki istemciler reddedilir.
    : _chat = FirebaseAI.googleAI(useLimitedUseAppCheckTokens: true)
          .generativeModel(
            model: model,
            systemInstruction: Content.system(
              assistantSystemPrompt((now ?? DateTime.now)()),
            ),
            tools: [Tool.functionDeclarations(assistantFunctionDeclarations())],
            toolConfig: ToolConfig(
              functionCallingConfig: FunctionCallingConfig.auto(),
            ),
            // Yanıtlar kısa: maliyet ve kötüye kullanım sınırı.
            generationConfig: GenerationConfig(maxOutputTokens: 512),
          )
          .startChat();

  final ChatSession _chat;

  ModelTurn _turn(GenerateContentResponse r) {
    final calls = [
      for (final c in r.functionCalls) ToolCall(c.name, c.args, id: c.id),
    ];
    String? text;
    try {
      text = r.text;
    } on FirebaseAIException {
      if (calls.isEmpty) rethrow;
    }
    return ModelTurn(text: text, calls: calls);
  }

  @override
  Future<ModelTurn> sendText(String text) async =>
      _turn(await _chat.sendMessage(Content.text(text)));

  @override
  Future<ModelTurn> sendToolReplies(List<ToolReply> replies) async => _turn(
    await _chat.sendMessage(
      Content.functionResponses([
        for (final r in replies)
          FunctionResponse(r.call.name, r.response, id: r.call.id),
      ]),
    ),
  );
}
