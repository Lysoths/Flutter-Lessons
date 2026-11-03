import 'package:equatable/equatable.dart';

/// DERS 9 — Uygulamaya gömülü bir Lottie animasyonu.
final class LottieItem extends Equatable {
  /// Bir animasyon kaydı oluşturur.
  const LottieItem({
    required this.id,
    required this.title,
    required this.useCase,
    required this.sourceUrl,
  });

  /// Dosya adı (uzantısız).
  final String id;

  /// Görünen ad.
  final String title;

  /// Uygulamada nerede kullanılabileceği.
  final String useCase;

  /// LottieFiles sayfası.
  final String sourceUrl;

  /// JSON dosyasının yolu.
  String get assetPath => 'assets/lottie/$id.json';

  @override
  List<Object?> get props => [id];
}

/// LottieFiles'tan indirilen ücretsiz animasyonlar (Lottie Simple License).
const kLottieAnimations = [
  LottieItem(
    id: 'heartbeat',
    title: 'Nabız',
    useCase: 'Ders 8\'deki elle yazdığımız nabzın Lottie hâli',
    sourceUrl: 'https://lottiefiles.com/free-animation/heartbeat-lottie-animation-Sph5eoJytj',
  ),
  LottieItem(
    id: 'loading',
    title: 'Yükleniyor',
    useCase: 'Veri beklerken',
    sourceUrl:
        'https://lottiefiles.com/free-animation/loading-animation-0yMJ1aysad',
  ),
  LottieItem(
    id: 'celebration',
    title: 'Kutlama',
    useCase: 'Harcama kaydedilince ya da bütçe tutunca',
    sourceUrl:
        'https://lottiefiles.com/free-animation/party-celebration-Ei80CjLJQC',
  ),
  LottieItem(
    id: 'clock',
    title: 'Saat',
    useCase: 'Yaklaşan fatura hatırlatması',
    sourceUrl: 'https://lottiefiles.com/free-animation/clock-lottie-animation-K2sPMoyo0P',
  ),
  LottieItem(
    id: 'idea',
    title: 'Fikir',
    useCase: 'Tasarruf ipucu',
    sourceUrl: 'https://lottiefiles.com/free-animation/idea-2xuoUIZh6Z',
  ),
];
