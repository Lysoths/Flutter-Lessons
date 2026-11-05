import 'package:flutter_ders/app/core/analytics/app_analytics.dart';
import 'package:flutter_ders/app/core/di/injection.dart';

// ─────────────────────────────────────────────────────────────────────────
// Firebase Analytics — özel olay kataloğu
//
// Her olayın tek bir anahtarı (Firebase'deki olay adı) ve ait olduğu ekran
// vardır. Olaylar yalnız buradan gönderilir; ekranlar ad yazmaz, katalogdan
// seçer:
//
//   track(AppEvent.currencySelected, 'USD');
//   → logEvent('doviz_secildi', {ekran: 'doviz', secenek: 'USD'})
//
// Parametreler yalnız ekran ve eylem bilgisidir. Tutar, not, konum, IP,
// e-posta gibi kişisel/hassas veri GÖNDERİLMEZ; `secenek` yalnız uygulamanın
// kendi sabit değerlerinden (kategori, sekme, demo adı…) gelir.
//
// Firebase kuralları: ad ≤ 40 karakter, harf ile başlar, yalnız [a-z0-9_];
// proje başına en çok 500 farklı olay. (test/analytics_test.dart denetler.)
// ─────────────────────────────────────────────────────────────────────────

/// Olayların ait olduğu ekranlar; [key] `ekran` parametresidir.
enum AppScreen {
  /// Harcama listesi (ana sayfa).
  expenses('harcamalar'),

  /// Ders dizini.
  lessons('dersler'),

  /// Harcama detayı ve düzenleme.
  expenseDetail('harcama_detay'),

  /// Yeni harcama formu.
  newExpense('yeni_harcama'),

  /// Kategori sayfası.
  category('kategori'),

  /// Belgeler, PDF, görsel ve ses.
  documents('belgeler'),

  /// Sayfa geçiş animasyonları.
  animations('animasyonlar'),

  /// Animasyon kontrolü (3B obje, nabız).
  animationControl('animasyon_kontrol'),

  /// Lottie.
  lottie('lottie'),

  /// Sync / async.
  syncAsync('sync_async'),

  /// Depolama (SharedPreferences, Hive, sqflite).
  storage('depolama'),

  /// Ağ ve soket.
  network('ag'),

  /// Konum ve sensörler.
  device('konum_sensor'),

  /// Bloc örnekleri.
  bloc('bloc'),

  /// Sayfalı liste.
  pagedList('ornek_liste'),

  /// Cihaz bilgisi.
  deviceInfo('cihaz_bilgisi'),

  /// Uygulama ve ağ bilgisi.
  appNetwork('uygulama_ag'),

  /// Döviz (MVVM).
  currency('doviz'),

  /// Retrofit.
  retrofit('retrofit'),

  /// Görsel önbelleği.
  imageCache('gorsel_onbellek'),

  /// Firebase dersi.
  firebase('firebase'),

  /// Google ile giriş.
  signIn('giris'),

  /// Güncelleme ekranı / kartı.
  update('guncelleme');

  const AppScreen(this.key);

  /// Firebase'e giden ekran adı.
  final String key;
}

/// Özel olaylar; [key] Firebase'deki olay adıdır.
enum AppEvent {
  // Harcamalar
  /// Yeni harcama kaydedildi (secenek: kategori).
  expenseAdded('harcama_eklendi', AppScreen.newExpense),

  /// Harcama düzenlendi (secenek: kategori).
  expenseEdited('harcama_duzenlendi', AppScreen.expenseDetail),

  /// Harcama silindi (secenek: kategori).
  expenseDeleted('harcama_silindi', AppScreen.expenses),

  /// Silme geri alındı.
  expenseRestored('harcama_geri_alindi', AppScreen.expenses),

  /// Kategori kısayolu açıldı (secenek: kategori).
  categoryOpened('kategori_acildi', AppScreen.expenses),

  // Ders dizini
  /// Ders ekranı açıldı (secenek: ders kimliği).
  lessonOpened('ders_acildi', AppScreen.lessons),

  // Belgeler
  /// Belge açıldı (secenek: belge türü).
  documentOpened('belge_acildi', AppScreen.documents),

  /// Ses oynatıldı / durduruldu (secenek: oynat | durdur).
  audioToggled('ses_oynat_durdur', AppScreen.documents),

  // Animasyonlar
  /// Geçiş animasyonu denendi (secenek: animasyon).
  transitionOpened('gecis_denendi', AppScreen.animations),

  /// Yavaş çekim değişti (secenek: acik | kapali).
  slowMotionToggled('yavas_cekim', AppScreen.animations),

  /// 3B obje eğrisi seçildi (secenek: eğri).
  curveSelected('egri_secildi', AppScreen.animationControl),

  /// 3B obje şekli seçildi (secenek: şekil).
  shapeSelected('sekil_secildi', AppScreen.animationControl),

  /// Nabız efekti başlatıldı / durduruldu (secenek: efekt).
  pulseToggled('nabiz_oynat_durdur', AppScreen.animationControl),

  /// Lottie animasyonu seçildi (secenek: animasyon).
  lottieSelected('lottie_secildi', AppScreen.lottie),

  /// Lottie oynatıldı / durduruldu.
  lottieToggled('lottie_oynat_durdur', AppScreen.lottie),

  // Sync / async
  /// Çalışma sırası örneği çalıştırıldı.
  orderRun('sira_calistirildi', AppScreen.syncAsync),

  /// Sync/async örneği çalıştırıldı (secenek: örnek).
  syncAsyncRun('ornek_calistirildi', AppScreen.syncAsync),

  // Depolama
  /// Örnek kayıt eklendi (secenek: depo).
  storageAdded('depo_kayit_eklendi', AppScreen.storage),

  /// Kayıt silindi (secenek: depo).
  storageDeleted('depo_kayit_silindi', AppScreen.storage),

  /// Depo temizlendi (secenek: depo).
  storageCleared('depo_temizlendi', AppScreen.storage),

  /// Hız ölçümü yapıldı (secenek: depo).
  storageBenchmark('depo_olcum', AppScreen.storage),

  // Ağ
  /// İnternet kontrolü yapıldı.
  networkChecked('ag_kontrol', AppScreen.network),

  /// Soket bağlandı.
  socketConnected('soket_baglandi', AppScreen.network),

  /// Sokete mesaj gönderildi.
  socketMessage('soket_mesaj', AppScreen.network),

  // Konum / sensör
  /// Konum izleme başlatıldı.
  gpsStarted('konum_baslatildi', AppScreen.device),

  /// Konum izleme durduruldu.
  gpsStopped('konum_durduruldu', AppScreen.device),

  // Bloc
  /// Kurlar yenilendi.
  ratesRefreshed('kur_yenilendi', AppScreen.bloc),

  /// Canlı bağlantı açıldı / kapandı (secenek: baglan | kes).
  liveToggled('canli_baglanti', AppScreen.bloc),

  /// İpucu kategorisi seçildi (secenek: kategori).
  tipCategorySelected('ipucu_kategori', AppScreen.bloc),

  // Sayfalı liste
  /// Liste yenilendi.
  pagedRefreshed('liste_yenilendi', AppScreen.pagedList),

  /// Hata sonrası tekrar denendi.
  pagedRetried('liste_tekrar', AppScreen.pagedList),

  // Cihaz / uygulama / ağ bilgisi
  /// Cihaz bilgisi yenilendi.
  deviceInfoRefreshed('cihaz_bilgisi_yenilendi', AppScreen.deviceInfo),

  /// Ağ bilgisi yenilendi.
  networkInfoRefreshed('ag_bilgisi_yenilendi', AppScreen.appNetwork),

  /// Wi-Fi adı için izin istendi.
  wifiAccessRequested('wifi_izni_istendi', AppScreen.appNetwork),

  // Döviz
  /// Para birimi seçildi (secenek: kod).
  currencySelected('doviz_secildi', AppScreen.currency),

  /// Geçmiş dönemi seçildi (secenek: dönem).
  periodSelected('donem_secildi', AppScreen.currency),

  /// Haberler süzüldü (secenek: kod | tumu).
  newsFiltered('haber_suzuldu', AppScreen.currency),

  /// Haber açıldı.
  newsOpened('haber_acildi', AppScreen.currency),

  /// Hepsi yenilendi.
  currencyRefreshed('doviz_yenilendi', AppScreen.currency),

  // Retrofit
  /// Demo çalıştırıldı (secenek: demo).
  retrofitRun('retrofit_denendi', AppScreen.retrofit),

  /// Demo iptal edildi (secenek: demo).
  retrofitCancelled('retrofit_iptal', AppScreen.retrofit),

  // Görsel önbelleği
  /// Kaynak önceden yüklendi (secenek: kaynak).
  precached('onbellek_yuklendi', AppScreen.imageCache),

  /// Yük testi.
  stressTest('onbellek_yuk_testi', AppScreen.imageCache),

  /// Bellek boşaltıldı.
  memoryCleared('onbellek_bellek_bosaltildi', AppScreen.imageCache),

  /// Disk boşaltıldı.
  diskCleared('onbellek_disk_bosaltildi', AppScreen.imageCache),

  /// Dosya bilerek bozuldu.
  fileCorrupted('onbellek_dosya_bozuldu', AppScreen.imageCache),

  /// Sürüm yükseltme benzetildi.
  upgradeSimulated('onbellek_surum_yukseltildi', AppScreen.imageCache),

  // Firebase
  /// App Check belirteci istendi (secenek: alindi | alinamadi).
  appCheckRequested('app_check_denendi', AppScreen.firebase),

  /// Crashlytics kaydı eklendi.
  crashLogAdded('crash_kayit', AppScreen.firebase),

  /// Yakalanan hata gönderildi.
  nonFatalSent('crash_yakalanan_hata', AppScreen.firebase),

  /// Test çökmesi.
  testCrash('crash_test_cokmesi', AppScreen.firebase),

  /// Remote Config elle çekildi.
  remoteConfigFetched('rc_cekildi', AppScreen.firebase),

  /// Firestore'a örnek veri yazıldı.
  firestoreSeeded('firestore_seed_yuklendi', AppScreen.firebase),

  /// Firestore'daki kullanıcı verisi silindi.
  firestoreCleared('firestore_temizlendi', AppScreen.firebase),

  /// Dil seçildi (secenek: tr | en | cihaz).
  languageSelected('dil_secildi', AppScreen.firebase),

  // Giriş
  /// Google ile giriş başarılı.
  signInSucceeded('giris_basarili', AppScreen.signIn),

  /// Giriş olmadı (secenek: hata anahtarı).
  signInFailed('giris_basarisiz', AppScreen.signIn),

  /// Çıkış yapıldı.
  signedOut('cikis_yapildi', AppScreen.firebase),

  // Güncelleme
  /// Güncelle düğmesi (secenek: zorunlu | istege_bagli).
  updateOpened('guncelleme_acildi', AppScreen.update),

  /// İsteğe bağlı güncelleme ertelendi.
  updatePostponed('guncelleme_ertelendi', AppScreen.update);

  const AppEvent(this.key, this.screen);

  /// Firebase'deki olay adı.
  final String key;

  /// Ait olduğu ekran.
  final AppScreen screen;

  /// Firebase'e giden parametreler.
  Map<String, Object> params([String? option]) => {
    'ekran': screen.key,
    if (option != null && option.isNotEmpty)
      'secenek': option.length > 100 ? option.substring(0, 100) : option,
  };
}

/// [event] olayını gönderir; Analytics kayıtlı değilse (ör. tek başına
/// kurulan cubit testleri) sessiz kalır. Gönderim beklenmez, hata yutulur.
void track(AppEvent event, [String? option]) {
  if (!getIt.isRegistered<AppAnalytics>()) return;
  getIt<AppAnalytics>().logEvent(event.key, event.params(option)).ignore();
}
