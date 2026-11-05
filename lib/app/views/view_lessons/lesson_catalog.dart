import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ders/app/core/router/app_router.dart';

/// Derslerin konu grupları; sıra ekrandaki sıradır.
enum LessonTopic {
  /// Arayüz, liste ve belgeler.
  ui('Arayüz ve listeler', Icons.dashboard_rounded, Color(0xFF2563EB)),

  /// Animasyonlar.
  motion('Animasyon', Icons.auto_awesome_rounded, Color(0xFF9333EA)),

  /// Yerel veri ve async.
  data('Veri ve depolama', Icons.storage_rounded, Color(0xFF0D9488)),

  /// Ağ.
  network('Ağ', Icons.wifi_rounded, Color(0xFF0284C7)),

  /// Cihaz.
  device('Cihaz', Icons.smartphone_rounded, Color(0xFFEA580C)),

  /// Bloc ve MVVM.
  architecture('Mimari', Icons.account_tree_rounded, Color(0xFF4F46E5)),

  /// Firebase.
  firebase('Firebase', Icons.local_fire_department_rounded, Color(0xFFF59E0B));

  const LessonTopic(this.label, this.icon, this.color);

  /// Başlık.
  final String label;

  /// Simge.
  final IconData icon;

  /// Vurgu rengi.
  final Color color;
}

/// Bir ders ekranı.
class Lesson {
  /// Oluşturur.
  const Lesson({
    required this.id,
    required this.number,
    required this.topic,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.route,
  });

  /// Kısa kimlik (test anahtarı: `lessons_<id>`).
  final String id;

  /// Ders numarası.
  final int number;

  /// Konu.
  final LessonTopic topic;

  /// Başlık.
  final String title;

  /// Açıklama.
  final String subtitle;

  /// Simge.
  final IconData icon;

  /// Tipli rota (path yok).
  final PageRouteInfo route;
}

/// Uygulamadaki bütün ders ekranları.
const kLessons = <Lesson>[
  Lesson(
    id: 'documents',
    number: 5,
    topic: LessonTopic.ui,
    title: 'Belgeler',
    subtitle: "Fatura PDF'leri, fiş görselleri ve sesler",
    icon: Icons.folder_open_rounded,
    route: DocumentsRoute(),
  ),
  Lesson(
    id: 'pagedList',
    number: 7,
    topic: LessonTopic.ui,
    title: 'Sayfalı liste',
    subtitle: "500 örnek harcama, 20'şer yüklenir",
    icon: Icons.view_list_rounded,
    route: PagedListRoute(),
  ),
  Lesson(
    id: 'pagedGrid',
    number: 7,
    topic: LessonTopic.ui,
    title: 'Sayfalı ızgara',
    subtitle: 'Aynı 500 kayıt, kartlar hâlinde',
    icon: Icons.grid_view_rounded,
    route: PagedGridRoute(),
  ),
  Lesson(
    id: 'imageCache',
    number: 17,
    topic: LessonTopic.ui,
    title: 'Görsel önbelleği',
    subtitle: 'Sürüme bağlı önbellek, bellek denetimi, base64 · S3 · SFTP',
    icon: Icons.photo_library_rounded,
    route: ImageCacheRoute(),
  ),
  Lesson(
    id: 'animations',
    number: 6,
    topic: LessonTopic.motion,
    title: 'Geçiş animasyonları',
    subtitle: '20 farklı sayfa geçişi senaryosu',
    icon: Icons.animation_rounded,
    route: AnimationsRoute(),
  ),
  Lesson(
    id: 'animationControl',
    number: 8,
    topic: LessonTopic.motion,
    title: 'Animasyon kontrolü',
    subtitle: '3B obje ve nabız efektleri',
    icon: Icons.view_in_ar_rounded,
    route: AnimationControlRoute(),
  ),
  Lesson(
    id: 'lottie',
    number: 9,
    topic: LessonTopic.motion,
    title: 'Lottie animasyonları',
    subtitle: 'JSON dosyasından çizilen animasyonlar',
    icon: Icons.movie_filter_rounded,
    route: LottieRoute(),
  ),
  Lesson(
    id: 'syncAsync',
    number: 10,
    topic: LessonTopic.data,
    title: 'Sync / Async',
    subtitle: 'Ekran neden donar? Farkı canlı gör',
    icon: Icons.sync_alt_rounded,
    route: SyncAsyncRoute(),
  ),
  Lesson(
    id: 'storage',
    number: 10,
    topic: LessonTopic.data,
    title: 'Yerel depolama',
    subtitle: 'SharedPreferences, Hive ve sqflite',
    icon: Icons.storage_rounded,
    route: StorageHubRoute(),
  ),
  Lesson(
    id: 'network',
    number: 11,
    topic: LessonTopic.network,
    title: 'Ağ kontrolü',
    subtitle: 'FutureBuilder, StreamBuilder ve WebSocket',
    icon: Icons.wifi_rounded,
    route: NetworkRoute(),
  ),
  Lesson(
    id: 'retrofit',
    number: 16,
    topic: LessonTopic.network,
    title: 'Retrofit ile ağ',
    subtitle: '23 canlı deneme: metotlar, gövdeler, iptal, ilerleme',
    icon: Icons.api_rounded,
    route: RetrofitRoute(),
  ),
  Lesson(
    id: 'device',
    number: 12,
    topic: LessonTopic.device,
    title: 'Konum ve sensörler',
    subtitle: 'Canlı GPS, su terazisi, pusula, sallama',
    icon: Icons.sensors_rounded,
    route: DeviceRoute(),
  ),
  Lesson(
    id: 'deviceInfo',
    number: 14,
    topic: LessonTopic.device,
    title: 'Cihaz bilgisi',
    subtitle: 'Model, Android, RAM, disk, ekran, özellikler',
    icon: Icons.perm_device_information_rounded,
    route: DeviceInfoRoute(),
  ),
  Lesson(
    id: 'appNetwork',
    number: 14,
    topic: LessonTopic.device,
    title: 'Uygulama ve ağ',
    subtitle: 'Sürüm, Wi-Fi, genel IP (Cloudflare trace)',
    icon: Icons.public_rounded,
    route: AppNetworkRoute(),
  ),
  Lesson(
    id: 'bloc',
    number: 13,
    topic: LessonTopic.architecture,
    title: 'Bloc ile veri',
    subtitle: 'Servis isteği, canlı akış ve asset',
    icon: Icons.account_tree_rounded,
    route: BlocDemoRoute(),
  ),
  Lesson(
    id: 'currency',
    number: 15,
    topic: LessonTopic.architecture,
    title: 'Döviz yönetimi (MVVM)',
    subtitle: '10 para birimi, geçmiş grafik, finans haberleri',
    icon: Icons.currency_exchange_rounded,
    route: CurrencyRoute(),
  ),
  Lesson(
    id: 'firebase',
    number: 18,
    topic: LessonTopic.firebase,
    title: 'Firebase',
    subtitle:
        'Google ile giriş · Firestore · Remote Config · Crashlytics · '
        'App Check',
    icon: Icons.local_fire_department_rounded,
    route: FirebaseRoute(),
  ),
];
