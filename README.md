# Flutter Lessons

Ders ders ilerleyen bir Flutter çalışması. Temeli, harcamaları telefon
hafızasına kaydeden bir uygulama ("Harcama Takibim"); her ders bu uygulamaya
yeni bir örnek ekran ekler. Yapı
[masterfabric-flutter-duo](https://github.com/masterfabric/masterfabric-flutter-duo)
standardını izler (masterfabric_core konvansiyonları: `BaseViewModelCubit`,
Equatable state, get_it, `view_<ad>/` klasörleri, sıkı lint); Cubit kullanımı
[bloclibrary sayaç eğitimine](https://bloclibrary.dev/tutorials/flutter-counter/) dayanır.

**Gereken:** Flutter 3.47 (Dart 3.13). Ana hedef Android ve iOS; GPS,
sensörler, sqflite, cihaz/ağ bilgisi gibi ekranlar web'de çalışmaz.

## Yapı

```
lib/
├── main.dart                     # Firebase, observer, DI, Crashlytics, runApp
├── firebase_options.dart         # flutterfire configure çıktısı
└── app/
    ├── app.dart                  # HarcamaApp: Remote Config teması, router, ağ banner'ı
    ├── core/
    │   ├── ai/                   # Ders 20: persona, araçlar, Gemini oturumu, kullanım sınırı
    │   ├── background/           # Ders 19: arka plan servisi, durum takibi, bildirim çizelgesi
    │   ├── analytics/            # olay kataloğu (AppEvent, AppScreen), ekran gözlemcisi
    │   ├── firebase/             # Remote Config, oturum, Crashlytics, App Check, Firestore
    │   ├── base/                 # ViewModel tabanları: Cubit, Bloc, ChangeNotifier
    │   ├── cache/                # sürüme bağlı görsel önbelleği, bellek denetleyicisi
    │   ├── bloc/                 # AppBlocObserver (geçişleri konsola yazar)
    │   ├── device/               # GPS, sensörler, cihaz bilgisi kaynakları
    │   ├── di/injection.dart     # get_it kayıtları (tüm depolar ve ViewModel'ler)
    │   ├── network/              # retrofit servisleri, ortak Dio, kayıt interceptor'u
    │   ├── repository/           # Model katmanı: harcama, örnek veri, kur, haber,
    │   │                         # ağ, uygulama bilgisi, not depoları (prefs/Hive/sqflite)
    │   └── router/               # auto_route tablosu, deep link beyaz listesi, geçişler
    ├── helper/                   # para/tarih/ölçü biçimleri, ağ kontrolü, sahte socket
    ├── models/                   # Expense, belgeler, Lottie, kur, haber, trace ...
    ├── theme/                    # MfColors + AppTheme, kategori renkleri
    ├── widgets/                  # ortak parçalar; app_gate: güncelleme → giriş → uygulama
    └── views/
        ├── view_expenses/        # ana sayfa: özet, kategoriler, ay → hafta kartlı liste, Dersler girişi
        ├── view_lessons/         # Dersler ekranı: konu süzgeci, arama, ders kataloğu
        ├── view_new_expense/     # yeni harcama formu (alttan açılır)
        ├── view_expense_detail/  # harcama ayrıntısı
        ├── view_category/        # kategoriye göre harcamalar
        ├── view_documents/ view_image_viewer/ view_pdf_viewer/ view_audio_player/  # Ders 5
        ├── view_animations/      # Ders 6
        ├── view_paged_list/ view_paged_grid/                                       # Ders 7
        ├── view_animation_control/                                                 # Ders 8
        ├── view_lottie/                                                            # Ders 9
        ├── view_sync_async/ view_storage/                                          # Ders 10
        ├── view_network/                                                           # Ders 11
        ├── view_device/                                                            # Ders 12
        ├── view_bloc_demo/                                                         # Ders 13
        ├── view_device_info/ view_app_network/                                     # Ders 14
        ├── view_currency/                                                          # Ders 15
        ├── view_retrofit/                                                          # Ders 16
        ├── view_image_cache/                                                       # Ders 17
        ├── view_auth/ view_update/ view_firebase/                                  # Ders 18
        ├── view_background/                                                        # Ders 19
        └── view_assistant/       # Ders 20: tam ekran sohbet + her ekrandaki balon
assets/
├── belgeler/                     # Ders 5: örnek PDF, görsel, ses
├── data/                         # Ders 7: 500 örnek harcama · 13: tasarruf ipuçları · 17: base64 görseller · 18: Firestore seed
└── lottie/                       # Ders 9: beş Lottie animasyonu
firestore.rules                   # Ders 18: kullanıcıya özel, alan ve ilişki denetimli kurallar
remoteconfig.template.json        # Ders 18: Remote Config şablonu (yayın + uygulama varsayılanı)
tool/firestore_seed_uret.py       # Ders 18: 520 harcamalık ilişkili örnek veri üretici
test/                             # her ders için birim, Bloc/ViewModel ve ekran testleri
```

Her ekran klasörü aynı düzende: `*_view.dart` (View), `cubit/`, `bloc/` ya
da `view_model/` (ViewModel), `widgets/` (ekranın parçaları).

## Veri akışı

```
Ekran (View) ──çağırır──▶ ExpensesCubit ──kaydeder──▶ ExpenseRepository ──▶ Firestore (Ders 18'den beri)
     ▲                         │
     └────yeni state───────────┘
```

Ekranlar veriye yalnızca ViewModel üzerinden ulaşır; ViewModel'ler depo
arayüzlerini (`ExpenseRepository`, `CurrencyRepository` ...) bilir, nasıl
çalıştıklarını bilmez. Testler bu arayüzlere sahte depolar verir.

## Dersler

Ders 1–3 (Navigator push/pop, Navigation 2.0 RouterDelegate, elle yazılmış
deep link parser) bu reponun ilk commit'indedir (`b8b3616`). Ders 4'ten
itibaren uygulamanın tüm yönlendirmesi **auto_route** ile yapılır; ekranlar
ve veri katmanı aynı kalır. Her ders ayrı bir commit'tir (Ders 19 ve 20
birlikte): `git log --oneline`.

Ders ekranlarına ana sayfadaki **Dersler** kartından ya da üst çubuktaki
kep simgesinden ulaşılır (`views/view_lessons/`). Dersler konuya göre
gruplanır; üstteki süzgeç tek konuyu bırakır, arama ada, açıklamaya ve ders
numarasına bakar ("bloc", "14"). Katalog `lesson_catalog.dart`'tadır: yeni
bir ders eklemek bu listeye bir satır eklemektir.

| Ders | Konu | Dersler ekranındaki kart |
|---|---|---|
| 4 | auto_route, tipli rotalar, deep link beyaz listesi | — |
| 5 | Assets: PDF, görsel, ses | Belgeler |
| 6 | Rota geçiş animasyonları | Geçiş animasyonları |
| 7 | Sayfalama, `ListView.builder` / `GridView`, iskelet yükleme | Sayfalı liste, Sayfalı ızgara |
| 8 | AnimationController, 3B nesne, nabız efektleri | Animasyon kontrolü |
| 9 | Lottie: JSON'dan animasyon | Lottie animasyonları |
| 10 | Sync/async; SharedPreferences, Hive, sqflite | Sync / Async, Yerel depolama |
| 11 | Future/StreamBuilder, MaterialBanner, sahte WebSocket | Ağ kontrolü |
| 12 | GPS ve hareket sensörleri | Konum ve sensörler |
| 13 | Bloc: servis, canlı akış, asset | Bloc ile veri |
| 14 | Cihaz, uygulama ve ağ bilgisi (Bloc, Cloudflare trace) | Cihaz bilgisi, Uygulama ve ağ |
| 15 | MVVM: ChangeNotifier + provider, döviz yönetimi | Döviz yönetimi |
| 16 | retrofit: tüm anotasyonlar, interceptor, CallAdapter | Retrofit ile ağ |
| 17 | Sürüme bağlı görsel önbelleği, bellek denetimi; base64, S3, SFTP | Görsel önbelleği |
| 18 | Firebase: Google ile giriş, Remote Config, zorunlu güncelleme, Crashlytics, App Check, Analytics, Firestore | Firebase |
| 19 | Ön plan servisi: uygulama durumu, 3 sn'de bir GPS, görselli ve düğmeli bildirimler | Arka plan ve bildirimler |
| 20 | Firebase AI (Gemini): personalı harcama asistanı, function calling, her ekranda balon | Harcama asistanı (Firebase AI) |

**Kullanılan dış servisler** (hepsi ücretsiz, anahtar istemez, isteğe kişisel
veri eklenmez): Frankfurter (Ders 13), Cloudflare trace (Ders 14),
currency-api (Ders 15), Anadolu Ajansı ve TRT Haber RSS (Ders 15),
jsonplaceholder ve httpbin (Ders 16), AWS Open Data S3 ve Rebex SFTP test
sunucusu (Ders 17), Firebase (Ders 18; Analytics'e yalnızca ekran ve eylem
adı gider, tutar, not ya da e-posta gitmez), Firebase AI Logic / Gemini
Developer API (Ders 20; yalnız asistana yazılan mesaj gider, bkz. Güvenlik).

**İzinler:** internet; konum (Ders 12 GPS, Ders 14 Wi-Fi adı, Ders 19 arka
plan); bildirim ve "location" tipli ön plan servisi (Ders 19). Konum, IP ve
Wi-Fi bilgileri hiçbir yere gönderilmez, konsola yazılmaz. Tek istisna Ders
19: arka planda alınan konumlar, ders gereği, telefonda uygulamanın kendi
klasöründe saklanır ve ekrandan silinebilir.

### Ders 4 — auto_route

auto_route, Navigation 2.0'ı (RouterDelegate + parser) sizin yerinize kurar.
Sayfalar `@RoutePage()` ile işaretlenir, `build_runner` her sayfa için **tipli
bir rota sınıfı** üretir:

| Sayfa | Üretilen rota | Yol |
|---|---|---|
| `ExpensesView` | `ExpensesRoute()` | `/` |
| `CategoryExpensesView` | `CategoryExpensesRoute(slug: 'yemek')` | `/kategori/:slug` |
| `ExpenseDetailView` | `ExpenseDetailRoute(expense: e)` | dışarıya kapalı |
| `NewExpenseView` | `NewExpenseRoute()` | `/yeni` (bottom sheet) |

```dart
// Aç ve sonucu bekle (Navigator.push gibi, ama tipli rota ile)
final result = await context.router.push<ExpenseDetailResult>(
  ExpenseDetailRoute(expense: expense),
);
// Kapat ve sonuç döndür
context.router.maybePop(const ExpenseDetailDeleted());
```

| Ne | Nerede |
|---|---|
| Rota tablosu (`@AutoRouterConfig`, `RootStackRouter`) | `core/router/app_router.dart` |
| Üretilen rota sınıfları (elle düzenlenmez) | `core/router/app_router.gr.dart` |
| `MaterialApp.router(routerConfig: _router.config(...))` | `app.dart` |
| Deep link beyaz listesi (`deepLinkTransformer`) | `core/router/app_deep_links.dart` |
| `@PathParam('slug')` | `views/view_category/category_expenses_view.dart` |
| Testler | `test/deep_link_test.dart`, `test/widget_test.dart` |

Rota tablosu ya da bir `@RoutePage()` sayfanın parametreleri değişince:

```bash
dart run build_runner build
```

Deep link: `harcamatakibim://app/kategori/<ad>` ve `harcamatakibim://app/yeni`.
auto_route linki rota tablosuyla
eşlemeden önce `AppDeepLinks.transform` çalışır: yalnızca bu iki biçim geçer,
sorgu parametreleri atılır, başka her şey `/` olur. Detay ekranı nesne
istediği için dışarıdan açılamaz.

### Ders 5 — Assets (PDF, görsel, ses) + auto_route

Dosyalar uygulamanın içine gömülüdür (`assets/belgeler/`) ve
`pubspec.yaml`'daki `assets:` bölümüyle tanıtılır. Kaynak: Wikimedia Commons,
hepsi kamu malı.

| Ne | Nerede |
|---|---|
| Dosyalar | `assets/belgeler/` |
| `pubspec.yaml` → `flutter: assets: - assets/belgeler/` | `pubspec.yaml` |
| Belge listesi (`kDocuments`) | `models/document_item.dart` |
| Liste sayfası `/belgeler` | `views/view_documents/documents_view.dart` |
| Görsel: `Image.asset` + `InteractiveViewer` | `views/view_image_viewer/` |
| PDF: `PdfViewer.asset` (pdfrx) | `views/view_pdf_viewer/` |
| Ses: `AudioPlayer().setAsset` (just_audio) | `views/view_audio_player/` |
| Testler | `test/documents_test.dart` |

Görüntüleyiciler `DocumentItem` nesnesi ister (`PdfViewerRoute(document: d)`),
bu yüzden dışarıdan yalnızca liste açılabilir: `harcamatakibim://app/belgeler`.

Not: `@AutoRouterConfig(replaceInRouteName: 'View,Route')` kuralı
`ImageViewerView` içindeki "View" parçasını da değiştirip `ImageRouteerRoute`
üretir; bu yüzden bu sayfalarda ad elle verilir:
`@RoutePage(name: 'ImageViewerRoute')`.

### Ders 6 — Rota geçiş animasyonları

Sayfa açılırken Flutter `animation` değerini 0'dan 1'e götürür (kapanırken
tersine). Geçiş, bu değeri bir `*Transition` widget'ına bağlamaktır:
`FadeTransition` (solma), `SlideTransition` (kayma), `ScaleTransition`
(büyüme), `RotationTransition`, `SizeTransition`, ya da `AnimatedBuilder` ile
kendi efektin (3B çevirme, dairesel açılma, bulanıklık).

auto_route'ta geçiş rota tablosunda verilir:

```dart
CustomRoute(page: X.page, path: '/x',
  transitionsBuilder: RouteAnimation.slideFromRight.transitionsBuilder,
  duration: const Duration(milliseconds: 400))
```

**20 senaryo** (`core/router/route_transitions.dart` → `RouteAnimation`):
solma, sağdan/soldan/alttan/üstten kayma, büyüme, küçülerek yerleşme, dönme,
solup yükselme, perde, dairesel açılma, dikey/yatay kart çevirme, elastik,
zıplama, netleşme, Hero (ortak öğe), iOS tarzı, Android tarzı, animasyonsuz.

**Mevcut sayfalar:** kategori ve belgeler sağdan kayar, harcama detayı solup
yükselir, görsel küçülerek yerleşir, PDF alttan gelir, ses dairesel açılır.

**Vitrin:** ana sayfa → *Geçiş animasyonları*. Tek bir demo rotası
(`/animasyon/:senaryo`) 20 senaryoyu gösterir; `customRouteBuilder`,
gönderilen senaryoya bakıp animasyonu seçer. *Yavaş çekim* anahtarı
`timeDilation = 5` ile tüm animasyonları 5 kat yavaşlatır.

Not: auto_route rotaları varsayılan olarak **adıyla** tanır. Aynı adı taşıyan
rotalar (20 senaryonun hepsi `AnimationDemoRoute`) tek sayfa sayılır ve üst
üste açılamaz; bu yüzden demo rotası `usesPathAsKey: true` ile **yoluyla**
tanınır.

### Ders 7 — Sayfalama + ListView.builder

Ana sayfa → *Sayfalı liste*: 500 örnek harcama 20'şer (25 sayfa) yüklenir.

| Katman | Dosya |
|---|---|
| Depo (arayüz) | `core/repository/sample_expense_repository.dart` → `fetchPage(page, pageSize)` |
| Veri dosyası | `assets/data/ornek_harcamalar.json` — 500 kayıt (pubspec → `assets/data/`) |
| Depo (JSON) | `core/repository/json_sample_expense_repository.dart` — `rootBundle.loadString` → `jsonDecode` → `Expense.fromJson`; dosya bir kez okunur, sayfa başı 0,6 sn bekleme |
| Durum | `views/view_paged_list/cubit/paged_list_state.dart` — `status`, `items`, `page`, `hasMore`, `total` |
| View model | `views/view_paged_list/cubit/paged_list_cubit.dart` — `loadFirstPage`, `loadNextPage`, `refresh`, `retry` |
| Ekran | `views/view_paged_list/paged_list_view.dart` |

- `ListView(children: [...])` 500 satırın hepsini baştan oluşturur;
  `ListView.builder` yalnızca ekranda görünenleri oluşturur.
- `ScrollController` listenin sonuna 300 px kala `loadNextPage()` çağırır.
  Cubit aynı anda tek istek atar, kayıtlar bitince istek atmaz.
- `itemCount = kayıt + 1`: son satır *yükleniyor / tekrar dene / hepsi bu kadar*.
- Aşağı çekince (`RefreshIndicator`) 1. sayfaya döner.
- Örnek kayıtlar yalnızca okunur; gerçek harcamalara yazılmaz. Rota deep
  link beyaz listesinde yok.

**2. ekran — Sayfalı ızgara** (ana sayfa → *Sayfalı ızgara*,
`views/view_paged_grid/`): aynı depo ve aynı `PagedListCubit`, yalnızca
görünüm farklı. Kartlar en fazla 200 px genişlikte
(`SliverGridDelegateWithMaxCrossAxisExtent`): telefonda 2 sütun, geniş
ekranda daha fazla. Alttaki "yükleniyor / hepsi bu kadar" satırı tek hücreye
sığmayacağı için `CustomScrollView` içinde `SliverGrid.builder` +
`SliverToBoxAdapter` kullanılır (`GridView.builder` da içeride aynı
`SliverGrid`'i kurar). Sayaç ve alt satır iki ekranda ortaktır:
`view_paged_list/widgets/paged_status_widgets.dart`.

**Lazy loading — iki sekme** (liste ve ızgarada *Standart* / *İskelet*):
her sekmenin kendi cubit'i var, birbirinden bağımsız sayfalanır
(`view_paged_list/widgets/paged_tab.dart`, `AutomaticKeepAliveClientMixin`
ile sekme değişince içerik korunur).

| | Standart | İskelet |
|---|---|---|
| Açılışta | ortada dönen gösterge | 8 iskelet satır/kart |
| Sonraki sayfa beklenirken | en altta dönen gösterge | listenin sonunda 3 satır / 4 kart iskelet |

İskelet paket kullanmadan yazıldı (`widgets/skeleton.dart`): `SkeletonBox`
gri kutular, `Shimmer` ise `ShaderMask` + kayan `LinearGradient` ile
üstlerinden parıltı geçirir. Sistemde "animasyonları azalt" açıksa parıltı
oynamaz.

### Ders 8 — AnimationController

Ana sayfa → *Animasyon kontrolü* (`views/view_animation_control/`), iki sekme.

`AnimationController` bir saattir: her karede `value`'yu 0.0 → 1.0 ilerletir.
`vsync` için State'e `SingleTickerProviderStateMixin` eklenir; sayfa
kapanınca `dispose()` ile mutlaka kapatılır.

| Komut | Ne yapar |
|---|---|
| `forward()` / `reverse()` | ileri / geri oynat |
| `stop()` / `reset()` | olduğu yerde dur / başa (0.0) dön |
| `repeat()` / `repeat(reverse: true)` | sürekli tekrar / gidip gel |
| `value = x` | elle istenen yere getir (ilerleme kaydırıcısı) |
| `duration = ...` | hız (kaydırıcı; 0.25x–3x) |

**3B obje:** paketsiz 3B kutu (`widgets/box_3d.dart`): altı yüz `Matrix4`
ile yerine döndürülür, arkadakiler önce çizilir. Küp / Kart / Kule.
- `CurvedAnimation` + `Curves` → doğrusal, yumuşak, yavaşlayan, geri
  yaylanma, elastik, zıplama (`widgets/curve_option.dart`)
- `AnimatedSwitcher` → obje değişirken eskisi söner, yenisi büyür
- `AnimatedContainer` → sahnenin rengi (gece) ve yüksekliği (büyük sahne)
- Durum yazısı `AnimationStatus`'u gösterir (ileri / geri / bitti / başta)

**Nabız:** 8 efekt (`widgets/pulse_effects.dart`), her biri kendi
controller'ıyla (`widgets/pulse_card.dart`): kalp atışı (`TweenSequence`),
dalga halkaları, nefes, EKG çizgisi (`CustomPainter` + `extractPath`),
radar (`SweepGradient`), zil sallanması, "yazıyor..." noktaları, bpm ile
hızı ayarlanan nabız. Her kartta Oynat/Durdur ve eğri seçimi var.

### Ders 9 — Lottie: JSON'dan animasyon

Ana sayfa → *Lottie animasyonları* (`views/view_lottie/`), paket: `lottie`.

1. Tasarımcı animasyonu After Effects'te vektörle çizer.
2. Bodymovin eklentisi onu **JSON**'a aktarır: katmanlar, şekiller ve
   "şu karede şu değer" listeleri.
3. `Lottie.asset('assets/lottie/x.json')` dosyayı okur ve her karede
   şekilleri yeniden çizer. Video değil veridir: birkaç KB, her boyutta net,
   rengi çalışırken değiştirilebilir (`LottieDelegates`).

JSON'un kökündeki anahtarlar (`models/lottie_json_info.dart` okur):
`v` sürüm, `fr` saniyedeki kare, `ip`/`op` ilk/son kare, `w`/`h` tuval,
`layers` katmanlar. Süre = (op − ip) / fr.

Oynatıcı, Ders 8'deki `AnimationController` ile yönetilir: oynat/durdur,
istenen kareye git (`value`), hız (`duration`). Controller verilmezse Lottie
kendi saatini kurar ve sürekli tekrar eder.

**Kaynak:** [lottiefiles.com/free-animations](https://lottiefiles.com/free-animations/json),
Lottie Simple License. Dosyalar `.lottie` (zip) olarak indirildi, içlerindeki
JSON `assets/lottie/` altına çıkarıldı:

| Dosya | LottieFiles |
|---|---|
| `heartbeat.json` | [Heartbeat](https://lottiefiles.com/free-animation/heartbeat-lottie-animation-Sph5eoJytj) |
| `loading.json` | [Loading animation](https://lottiefiles.com/free-animation/loading-animation-0yMJ1aysad) |
| `celebration.json` | [Party celebration](https://lottiefiles.com/free-animation/party-celebration-Ei80CjLJQC) |
| `clock.json` | [Clock](https://lottiefiles.com/free-animation/clock-lottie-animation-K2sPMoyo0P) |
| `idea.json` | [Idea](https://lottiefiles.com/free-animation/idea-2xuoUIZh6Z) |

### Ders 10 — Sync / async ve yerel depolama

**Sync / Async** (ana sayfa → *Sync / Async*, `views/view_sync_async/`,
`helper/sync_async_demo.dart`). Dart tek iş parçacığında çalışır; ekranı
çizen ile düğmenin kodu aynı sıradadır. Sayfadaki çark ve kare sayacı her
karede ilerler, kareler arasındaki en uzun boşluk "donma" olarak ölçülür.

| Aynı 2 sn'lik iş | Sonuç |
|---|---|
| `busyWork(2000)` (senkron) | ekran donar |
| `await Future.delayed(2 sn)` | ekran akar (bekleme, iş yok) |
| `await Future(() => busyWork(2000))` | yine donar: async ≠ paralel |
| `await Isolate.run(() => busyWork(2000))` | ekran akar: başka çekirdek |

Event loop sırası: önce senkron kod, sonra microtask'lar, sonra olay
kuyruğu (`Future()`, `Timer`). async fonksiyon ilk `await`'e kadar senkron
çalışır.

**Yerel depolama** (ana sayfa → *Yerel depolama*, `views/view_storage/`).
Aynı kayıt (`StorageNote`) üç yolla, üç ayrı ekranda; hepsi `NoteStore`
arayüzünü ve aynı `StorageDemoCubit`'i kullanır
(`core/repository/note_stores/`):

| | SharedPreferences | Hive (hive_ce) | sqflite |
|---|---|---|---|
| Model | anahtar → değer | NoSQL, anahtar → nesne | SQL tablo, satır |
| Liste nasıl saklanır | tek anahtarda JSON metni | kutuda nesneler (TypeAdapter) | tabloda satırlar |
| Okuma | sync (bellekten) | sync (`box.get`) | async (SQL) |
| Sorgu | yok | kodda elle | `WHERE`, `ORDER BY`, `SUM` |
| En uygun | ayarlar, birkaç değer | nesneler, hızlı önbellek | çok kayıt, sorgu, ilişki |

Her ekranda kayıt ekle / sil, 1000 kayıtla yazma-okuma ölçümü ve verinin
diskte nasıl durduğunu gösteren ham görünüm var. Bu dersin verisi ayrı
anahtar (`ders10_notes`), kutu ve veritabanında (`ders10.db`) durur; gerçek
harcamalara dokunulmaz. Testlerde Hive geçici klasörde, sqflite
`sqflite_common_ffi` ile bellekte çalışır.

### Ders 11 — Ağ kontrolü: Future, Stream ve WebSocket

Ana sayfa → *Ağ kontrolü* (`views/view_network/`).

**Helper** (`helper/network_checker.dart`): `example.com` adresini DNS ile
çözmeyi dener (Wi-Fi'ye bağlı olmak internete çıkabilmek demek değildir).

| | Ne döner | Ekranda |
|---|---|---|
| `check()` | `Future<NetworkResult>`: tek cevap | `FutureBuilder` |
| `watch(every:)` | `Stream<NetworkResult>`: her N saniyede bir | `StreamBuilder` |
| `refresh()` | dinleyenlere hemen yeni kontrol | "Tekrar dene" |

`ConnectionState`: `none` (başlamadı) → `waiting` (bekleniyor) → `active`
(akış veri veriyor) → `done` (bitti). Future/Stream `build` içinde değil,
`State`'te bir kez oluşturulur; yoksa her çizimde yeniden başlar.

**MaterialBanner:** `app.dart` uygulama açılınca `watch()`'u dinler;
bağlantı yoksa `ScaffoldMessenger` ile her sayfanın üstünde
"İnternet bağlantısı yok" uyarısı çıkar, gelince kalkar ve kısa bir
bildirim gösterilir. Sayfadaki *Çevrimdışı gibi davran* anahtarı Wi-Fi'yi
kapatmadan bunu gösterir.

**Sahte WebSocket** (`helper/mock_socket.dart`): paket ve kurulum
gerektirmez. `HttpServer` telefonun içinde, yalnızca telefondan erişilen
`127.0.0.1` adresinde açılır; her saniye sahte döviz kuru gönderir,
yazılan mesajı geri yollar. İstemci gerçek bir `WebSocket`'tir;
`StreamBuilder` gelen mesajları canlı gösterir.

Android'de yayın (release) sürümünün internete çıkması için ana manifestte
`INTERNET` izni gerekir; debug sürümünde Flutter bunu kendisi ekler.

### Ders 12 — GPS ve sensörler: donanımdan canlı veri

Ana sayfa → *Konum ve sensörler* (`views/view_device/`), iki sekme.
Donanım ölçtükçe bir `Stream`'e yeni değer koyar; ekran `StreamBuilder` ile
her değerde yeniden çizilir (Ders 11'deki fikir).

**GPS** (`core/device/location_source.dart`, paket `geolocator`):
1. İzin (`Future`): konum servisi açık mı, izin var mı? Yoksa ister;
   kalıcı reddedilmişse "Ayarları aç" gösterilir.
2. Konum akışı (`Stream`): saniyede bir enlem, boylam, doğruluk (± m), hız,
   yön, yükseklik. Yürüdükçe iz çizilir, mesafe haversine formülüyle
   toplanır; doğruluk yarıçapından küçük "titreme" adımları sayılmaz.
Konum yalnızca ekranda gösterilir: kaydedilmez, gönderilmez.
İzinler: Android `ACCESS_FINE/COARSE_LOCATION`, iOS
`NSLocationWhenInUseUsageDescription`.

**Sensörler** (`core/device/sensor_source.dart`, paket `sensors_plus`).
Eksenler telefona göre: x sağ, y üst, z ekrandan size.

| Sensör | Birim | Ekranda |
|---|---|---|
| İvmeölçer (yerçekimi dahil) | m/s² | su terazisi, eğim açıları, canlı x/y/z grafiği |
| Manyetometre | µT | yaklaşık pusula (telefon düzken), alan şiddeti |
| Jiroskop | rad/s | eksenlerde dönüş hızı |
| Kullanıcı ivmesi (yerçekimi hariç) | m/s² | sallama sayacı (12 m/s² üstü) |

Her kartta saniyedeki ölçüm sayısı (Hz) ve `ConnectionState` görünür.
Donanım `LocationSource` / `SensorSource` arayüzlerinin arkasında; testte
sahte akışlar verilir.

Not: Bu iki sayfada ve ağ sayfasında tembel `ListView` yerine
`SingleChildScrollView` kullanılır: ekrandan çıkan kart yok edilirse,
yeniden kurulan `StreamBuilder` aynı akışı ikinci kez dinleyemez.

### Ders 13 — Bloc ile durum yönetimi

Ana sayfa → *Bloc ile veri* (`views/view_bloc_demo/`), üç sekme.

```
Ekran ──add(Olay)──▶ Bloc ──on<Olay>──▶ emit(Durum) ──▶ Ekran çizer
```

Cubit'te ekran metot çağırır (`cubit.load()`); Bloc'ta **olay** gönderir
(`bloc.add(RatesRequested())`). React'teki `useReducer` + `dispatch` gibi.
Her Bloc `core/base/base_view_model_bloc.dart`'tan türer
(masterfabric_core'daki `BaseViewModelBloc`); `AppBlocObserver.onTransition`
her geçişi "olay → durum" olarak kayda yazar.

| Sekme | Kaynak | Bloc | Teknik |
|---|---|---|---|
| Servis | Frankfurter API (`dio`) | `RatesBloc` | `sealed` durumlar + `switch`; `droppable()`: istek sürerken "Yenile" yok sayılır |
| Canlı | Sahte WebSocket (Ders 11) | `LiveRatesBloc` | `emit.forEach(akış)`: her mesaj yeni durum |
| Asset | `assets/data/tasarruf_ipuclari.json` | `TipsBloc` | `restartable()` + 300 ms bekleme: yalnızca son arama |

Ekranda: `MultiBlocProvider` (üç Bloc sayfa seviyesinde), `BlocBuilder`
(çizim), `BlocListener` (hata olunca bildirim), `BlocSelector` (durumun bir
parçası değişince çizim).

**Servis:** `GET https://api.frankfurter.dev/v1/latest?base=TRY&symbols=...`
Avrupa Merkez Bankası'nın günlük kurları; ücretsiz, anahtar istemez, isteğe
kişisel veri eklenmez. `dio` hataları Türkçe `RatesFailure`'a çevrilir.

**Katmanlar:** `core/repository/` → `rates_repository.dart`,
`live_rates_repository.dart`, `tips_repository.dart`. Testler
(`test/bloc_demo_test.dart`, `bloc_test`) gerçek ağa çıkmaz: dio'ya sahte
bağdaştırıcı, Bloc'lara sahte depolar verilir.

### Ders 14 — Cihaz, uygulama ve ağ bilgisi (Bloc)

Ana sayfa → *Cihaz bilgisi* (`views/view_device_info/`) ve *Uygulama ve ağ*
(`views/view_app_network/`, iki sekme). Üç Bloc, aynı kalıp:
olay → kaynak → `emit(durum)`.

| Ekran | Kaynak | Bloc | Neler |
|---|---|---|---|
| Cihaz bilgisi | `device_info_plus`, `dart:io` | `DeviceInfoBloc` | Marka, model, Android/API, güvenlik yaması, derleme, yonga, ABI, RAM, disk, sistem özellikleri, ham veri |
| (aynı ekran) | `MediaQuery`, `View` | — | Çözünürlük, dpr, Hz, güvenli alan, yazı ölçeği, tema. Telefon dönünce değişir; Bloc'a değil ekrana ait |
| Uygulama | `package_info_plus`, `FlutterVersion` | `AppInfoBloc` | Sürüm, paket adı, kurulum zamanı, imza, derleme modu, Flutter/Dart sürümü |
| Ağ | `connectivity_plus`, `network_info_plus`, `dart:io` | `NetworkInfoBloc` | Bağlantı türü, VPN, Wi-Fi adı/BSSID, yerel IP, ağ geçidi, maske, arayüzler |
| Ağ | `GET https://1.1.1.1/cdn-cgi/trace` (`dio`) | `NetworkInfoBloc` | Genel IP, ülke, Cloudflare veri merkezi, TLS, HTTP sürümü, sunucu saati, gidiş-dönüş süresi |

**Genel IP neden cihazdan okunmaz?** Telefon modemin / operatörün arkasında
(NAT); kendi bildiği adres yerel adrestir. İnternete hangi adresle çıktığını
yalnızca dışarıdaki bir sunucu söyleyebilir. Trace cevabı JSON değil düz
metin (`anahtar=değer` satırları); `CloudflareTrace.parse` ayrıştırır.

**Bloc teknikleri:** iki parça (cihaz içi + trace) aynı anda başlar, hangisi
önce biterse o önce ekrana gelir; "Yenile" `droppable()`; bağlantı değişince
(`onConnectivityChanged` akışı) Bloc kendine olay gönderir, `restartable()`
ile yalnızca sonuncusu işlenir.

**Gizlilik:** IP, Wi-Fi adı, BSSID ve ağ geçidi ekranda gizli başlar,
dokununca görünür. Hiçbir bilgi kaydedilmez; durumların `toString`'i bu
değerleri içermez, yani `AppBlocObserver` konsola yazmaz. Wi-Fi adı için
Android konum izni ister (Ders 12'deki izin); izin yoksa ad "—" görünür.
Bu iki ekran deep link beyaz listesinde yok.

### Ders 15 — MVVM: ChangeNotifier ile döviz yönetimi

Ana sayfa → *Döviz yönetimi* (`views/view_currency/`). Tek ekran, tek üst
ViewModel, üç alt ViewModel; ekrana `provider` paketiyle bağlanır.

```
views/view_currency/
├── currency_view.dart              View: sayfa iskeleti
├── view_model/
│   ├── currency_view_model.dart    üst: ilk yükleme, hepsini yenile, koordinasyon
│   ├── rates_view_model.dart       1. bölüm: 10 para birimi
│   ├── history_view_model.dart     2. bölüm: haftalık / aylık / 3 aylık
│   └── news_view_model.dart        3. bölüm: haberler, süzgeç, okundu
└── widgets/                        her bölümün görünümü + haber modalı
Model: models/currency/*, core/repository/{currency,news}_repository.dart
Taban: core/base/base_change_notifier_view_model.dart
```

| Katman | Görevi | Bu ekranda |
|---|---|---|
| View | Çizer, kullanıcı hareketini ViewModel'e iletir | `RatesSection`, `HistorySection`, `NewsSection`, `NewsDetailSheet` |
| ViewModel | Ekrana gidecek veriyi hazırlar ve sınırlar; alanları dışarıdan değiştirilemez | `CurrencyViewModel` → `Rates` / `History` / `News` ViewModel |
| Model | Veriyi getirir, ekranı tanımaz | `CurrencyApiRepository`, `RssNewsRepository` |

**Neden alt ViewModel?** Her bölüm yalnızca kendi ViewModel'ini dinler
(`context.watch<NewsViewModel>()`): haber süzgeci değişince kur listesi
yeniden çizilmez. Bölümler birbirini tanımaz; "USD'ye dokunuldu, grafiği
USD'ye çevir" kararını üst ViewModel verir (`selectCurrency`).

**ChangeNotifier ve Cubit farkı:** Cubit'te durum tek, değişmez bir nesnedir
(`emit(yeniDurum)`). ChangeNotifier'da durum ViewModel'in kendi alanlarıdır;
alan değişince `notifyListeners()` çağrılır. C#'taki `INotifyPropertyChanged`
ile aynı fikir. `provider` karşılıkları: `ChangeNotifierProvider` (kur ve
dispose et), `.value` (var olanı aşağı ver), `watch`, `select`, `read`.

**Veri:**
- Kurlar: [currency-api](https://github.com/fawazahmed0/exchange-api).
  Ücretsiz, anahtar istemez, her gün ayrı dosya. Önce jsDelivr
  (`cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@2026.11.3/...`), açılmazsa
  `{gün}.currency-api.pages.dev` denenir: bazı mobil operatörler pages.dev'i
  engelliyor.
- Geçmiş: haftalık her gün (8 nokta), aylık iki günde bir (16), 3 aylık
  haftada bir (14). Günler önbellekte tutulur; aralık değişince eski günler
  yeniden indirilmez. Hızlı değiştirince yalnızca son isteğin sonucu yazılır.
- Haberler: Anadolu Ajansı ve TRT Haber ekonomi RSS beslemeleri, `xml`
  paketiyle. Biri çökerse diğeri gösterilir. Modaldaki "sitesinde oku"
  yalnızca `aa.com.tr` ve `trthaber.com` adreslerini açar (`url_launcher`).

### Ders 16 — retrofit ile ağ katmanı

Ana sayfa → *Retrofit ile ağ* (`views/view_retrofit/`). Paketler: `retrofit`,
`json_annotation`; geliştirme: `retrofit_generator`, `json_serializable`.

REST servisi bir Dart **arayüzü** olarak yazılır; isteği atan sınıfı
`build_runner` üretir (C#'taki Refit, Android'deki Retrofit gibi):

```dart
@RestApi(baseUrl: 'https://jsonplaceholder.typicode.com')
abstract class PostsApi {
  factory PostsApi(Dio dio) = _PostsApi;      // posts_api.g.dart

  @GET('/posts/{id}')
  Future<Post> getPost(@Path('id') int id);   // JSON → Post.fromJson
}
```

| Katman | Dosya |
|---|---|
| Servis arayüzleri | `core/network/posts_api.dart` (jsonplaceholder), `core/network/echo_api.dart` (httpbin) |
| Üretilen kod | `*.g.dart` (`dart run build_runner build`) |
| Model (`@JsonSerializable`) | `models/post.dart` → `Post`, `PostDraft`, `Comment` |
| Ortak Dio + kayıt | `core/network/retrofit_client.dart`, `core/network/recording_interceptor.dart` |
| CallAdapter | `core/network/api_result.dart` → `ApiResult`, `ResultCallAdapter` |
| Denemeler ve view model | `views/view_retrofit/cubit/` → `kRetrofitDemos`, `RetrofitLabCubit` |

Ekranda 23 canlı deneme, beş grupta. Her kartta anotasyon, arayüzdeki tanım,
değiştirilebilen girdiler ve *Gönder* var; sonuçta retrofit'in döndürdüğü
Dart nesnesi ve ağdan gerçekten geçen istek/cevap (başlıklar, gövde, süre)
yan yana görünür. Sağ üstteki *Ağ kaydı* tüm istekleri listeler.

| Grup | Anotasyonlar |
|---|---|
| HTTP metotları | `@GET` `@POST` `@PUT` `@PATCH` `@DELETE` `@HEAD` `@OPTIONS` |
| Parametreler | `@Path` `@Query` `@Queries` `@Headers` `@Header` |
| Gövde türleri | `@Body` `@BodyExtra` `@FormUrlEncoded` + `@Field` `@MultiPart` + `@Part` `@NoBody` `@PreventNullToAbsent` |
| Dio özellikleri | `@CancelRequest` `@SendProgress` `@ReceiveProgress` `@DioResponseType` `@Extra` `@Extras` `@DioOptions` `@CacheControl` |
| Cevap ve hata | `HttpResponse<T>` `@UseCallAdapter` `DioException` |

**İstek hangi denemeden geldi?** Cubit her denemeyi
`runZoned(..., zoneValues: {zoneKey: id})` içinde çalıştırır;
`RecordingInterceptor` isteği kaydederken `Zone.current[zoneKey]`'i okur.
Retrofit metotlarının imzasına dokunmadan her istek kendi kartına düşer.

**Notlar:**
- Ham JSON dönen metotlarda dönüş tipi `Map<String, Object?>`:
  `retrofit_generator` 10.3, `Map<String, dynamic>` için derlenmeyen kod
  (`dynamic.fromJson`) üretir.
- `@PartMap` bu üretici sürümünde gövdeye yazılmıyor (üretilen kodda gövde
  `null`); birden çok multipart alanı için `@Part` kullanılır.
- `dio` ile `retrofit`'te aynı adlı `Headers` sınıfı var; servis dosyasında
  `import 'package:dio/dio.dart' hide Headers;`.
- jsonplaceholder sahte bir REST sunucusudur: yazma istekleri gerçekçi cevap
  döner ama hiçbir şey kaydedilmez. httpbin gelen isteği olduğu gibi geri
  yansıtır.

### Ders 17 — Sürüme bağlı görsel önbelleği

Ana sayfa → *Görsel önbelleği* (`views/view_image_cache/`). Çekirdek
`core/cache/` altında; paketler: `path_provider`, `crypto`, `dartssh2`.

**Sorun:** Görseller diskte önbelleğe alınır. Yeni sürümde aynı adresteki
görsel (logo, banner, kampanya) değişmişse uygulama eskisini göstermeye devam
eder. Ağ yavaşsa ya da bellek dolarsa görseller yarım, parçalı ya da
titreyerek çizilir.

**Sürüm denetimi** (`AppImageCache.ensureReady`, `main.dart`'ta açılışta):
kayıtlı sürüm (`SharedPreferences`) ile `package_info_plus`'tan okunan
`sürüm+derleme` karşılaştırılır. Farklıysa eski sürümün disk klasörü silinir,
Flutter'ın bellek önbelleği (`ImageCache`) boşaltılır. Disk düzeni:
`<uygulama>/image_cache/<sürüm>/<sha1(kaynak)>.img`.

**Bütünlük: yarım görsel ekrana gelmez**

| Adım | Ne yapar |
|---|---|
| Boyut denetimi | HTTP'de `content-length`, SFTP'de `stat().size` gelen baytla karşılaştırılır |
| Bitiş işareti | PNG `IEND`, JPEG `FF D9`, GIF `3B`, WebP RIFF boyutu; Skia kısaltılmış PNG'yi bazen hatasız ama yarım çizer |
| Çözme denemesi | Baytlar diske yazılmadan önce bir kez çözülür (`instantiateImageCodec`) |
| Atomik yazma | Önce `.part` yazılır, bitince adı `.img` olur; yazarken kapanan uygulama yarım dosya bırakmaz |
| Diskten okurken | Aynı denetim; bozuk dosya silinip yeniden indirilir |
| Yeniden deneme | Eksik/bozuk gelen indirme beklemeli olarak 2 kez daha denenir |
| Ortak istek | Aynı görsel aynı anda iki yerden istenirse tek indirme yapılır |
| Ekranda | `gaplessPlayback`: yeni görsel gelene kadar eskisi kalır; `frameBuilder` ile yumuşak geçiş |

**Arka plan bellek denetleyicisi** (`ImageMemoryController`): çözülmüş bir
görsel bellekte genişlik × yükseklik × 4 bayt tutar. Bütçe cihaz RAM'inin
%2'si (48–256 MB, `device_info_plus`) olarak `ImageCache.maximumSizeBytes`'a
yazılır. Her 2 saniyede önbellek boyutu, görsel sayısı, ekrandaki görseller
ve uygulamanın belleği (RSS) ölçülür. Önbellek bütçenin %90'ını geçince, Android
"bellek az" dediğinde (`didHaveMemoryPressure`) ve uygulama arka plana
geçince ekranda olmayan görseller atılır. `ImageCache.clear()` ekranda
görünenlere dokunmadığı için boşaltma sırasında titreme olmaz.

**Üç kaynak** (`models/image_demo_sources.dart`):

| Kaynak | Nereden | Nasıl |
|---|---|---|
| Base64 | `assets/data/base64_gorseller.json` (API cevabı gibi) | `data:image/png;base64,...` → `base64Decode` |
| S3 | AWS Open Data, `elevation-tiles-prod` kovası (herkese açık PNG karolar) | `dio`, `ResponseType.bytes` |
| SFTP | `test.rebex.net` (herkese açık, salt okunur test sunucusu) | `dartssh2`; sunucu anahtarı sabitlenmiş |

**Neden FTP değil SFTP?** FTP (IIS FTP dahil) kullanıcı adını, şifreyi ve
dosyayı açık metin gönderir; pasif modda ek portlar açtığı için mobil
ağlarda ve güvenlik duvarlarında sık takılır. SFTP SSH üzerinden şifreli
çalışır, tek port (22) kullanır ve sunucunun kimliği anahtar parmak iziyle
doğrulanır: uygulama yalnızca bilinen anahtarlarla (`kSftpHostKeys`) konuşur,
araya giren sahte sunucuyu reddeder. Görseller bir mobil uygulamaya
dağıtılacaksa en iyi yol yine de HTTPS'tir (IIS'te statik site, S3 + CDN):
önbellek başlıkları, CDN ve sürüm adlı dosyalar (`logo.v42.png`) kullanılabilir.

Ekranda: her görselin nereden geldiği (bellek / disk / kaynak) ve süresi,
*Önceden yükle (precache)*, *Yük testi (24 karo)*, *Belleği boşalt*,
*Diski boşalt*, *Bir dosyayı boz* (bozuk dosyanın fark edilip yeniden
indirilmesi) ve *Yeni sürüm çıkmış gibi yap* (sürüm temizliği).

### Ders 18 — Firebase

Ana sayfa → Dersler → *Firebase* (`views/view_firebase/`). Çekirdek
`core/firebase/` ve `core/analytics/` altında. Kurulum `flutterfire configure`
ile yapıldı (`firebase_options.dart`, `google-services.json`).

**Açılış sırası** (`widgets/app_gate.dart`): önce sürüm denetimi, sonra giriş,
sonra uygulama. Hepsi aynı `MaterialApp.router` içinde, path kullanmadan.

| Parça | Ne yapar |
|---|---|
| Google ile giriş | `google_sign_in` 7 → `idToken` → `GoogleAuthProvider.credential` → Firebase Auth. İptal, ağ hatası, çok deneme gibi durumlar ayrı metinle gösterilir |
| Remote Config | `remoteconfig.template.json` tek kaynaktır: `firebase deploy --only remoteconfig` ile yayınlanır, aynı dosya uygulamada varsayılan olarak okunur. Renkler, köşe yarıçapı, yazı ölçeği (`tasarim`) ve TR/EN metinler (`dil_metinleri`) buradan gelir; `onConfigUpdated` ile uygulama yeniden başlamadan değişir |
| Zorunlu güncelleme | `min_surum` yüklü sürümden büyükse uygulama kapanır, yalnızca güncelleme ekranı kalır. `son_surum` büyükse kapatılabilir bir kart çıkar. Güncelleme adresi beyaz listedeki alan adlarından olmalıdır |
| Crashlytics | `FlutterError.onError` ve `PlatformDispatcher.onError` hataları yakalar; kullanıcı olarak yalnızca uid yazılır. Rapor bir sonraki açılışta gönderilir |
| App Check | Debug derlemede debug sağlayıcı (token CLI ile kaydedildi), yayında Play Integrity |
| Analytics | `AppEvent` kataloğunda her olayın sabit bir anahtarı vardır (`harcama_eklendi`, `ders_acildi` ...). Parametreler yalnızca `ekran` ve `secenek`; ekran açılışları rota gözlemcisiyle `screen_view` olur. Test, kataloğun tamamının kodda kullanıldığını ve harcama olaylarına kişisel veri girmediğini denetler |

**Firestore** (eur3, `kullanicilar/{uid}/...`): her kullanıcı yalnızca kendi
verisini okur ve yazar. Koleksiyonlar ilişkilidir: kategoriler, ödeme
yöntemleri ve etiketler referanstır; mağazalar, bütçeler ve harcamalar bunlara
kimlikle bağlanır. Kurallar (`firestore.rules`) alan adlarını ve türlerini
denetler, `exists()` ile bağlı kaydın gerçekten var olduğuna bakar.

Örnek veri `tool/firestore_seed_uret.py` ile üretilir (sabit tohum, her
seferinde aynı çıktı): 520 harcama (Haziran–Kasım 2026), 24 mağaza, 5 ödeme
yöntemi, 8 etiket, 30 aylık bütçe. Panelde *Örnek veriyi yeniden yaz* önce
referansları, sonra bağlı kayıtları 400'lük toplu yazmalarla gönderir
(Firestore sınırı 500); eski seed kayıtları silinir, kullanıcının kendi
eklediği harcamalara dokunulmaz. Ana sayfa giriş yapılınca harcamaları
Firestore'dan okur (`FirestoreExpenseRepository`).

Testlerde Firebase yoktur: `configureDependencies()` yerel karşılıkları verir
(`LocalAuthRepository`, `LocalConfigSource`, `MemoryFinanceStore` ...).

### Ders 19 — Arka plan servisi ve bildirimler

Ana sayfa → Dersler → *Arka plan ve bildirimler* (`views/view_background/`).
Çekirdek `core/background/` altında; paketler: `flutter_background_service`,
`flutter_local_notifications`.

**Ön plan servisi.** Android, uygulama penceresi kapalıyken çalışan işe
yalnızca bildirim çubuğunda görünür bir "ön plan servisi" olarak izin verir.
Servis kendi Dart isolate'inde çalışır; uygulamayla bellek paylaşmaz, yalnız
JSON mesajlaşır (`durum`, `nabiz`, `onizle`, `sessiz`, `temizle`, `durdur` →
servis; `rapor` → uygulama). Manifestte tipi `location` olduğu için,
uygulama açıkken başlatılınca "Uygulamayı kullanırken" izniyle arkada da konum
alabilir; "Her zaman" izni istenmez.

**Durum denetimi.** Uygulama `WidgetsBindingObserver` ile yaşam döngüsünü
servise bildirir: `resumed/inactive` → açık, `hidden/paused` → arka planda,
`detached` → kapalı. Görev listesinden kaydırınca Android her zaman haber
vermez; bu yüzden uygulama 3 saniyede bir nabız gönderir, nabız 10 saniye
kesilirse servis "kapalı" der.

**3 saniyede bir GPS.** Uygulama açıkken adım atlanır; arkadayken konum akışı
açık tutulur (GPS soğuk başlamasın) ve her adımda son ölçüm alınır. Konumlar
satır satır JSON olarak (`arka_plan/konumlar.jsonl`) telefona yazılır.
İstatistik: adım, başarılı / hatalı / atlanan / çakışan okuma, ortalama ve en
uzun okuma süresi, arkada kat edilen mesafe, açık / arka / kapalı süreleri,
durum geçişleri, gönderilen ve iptal edilen bildirimler, düğme sayıları.

**Bildirim simülasyonu.** Arka plana geçişte uygulamanın verisinden (bu ayın
toplamı, en çok harcanan kategori, son harcamalar) bir çizelge kurulur:

| An | Stil | Not |
|---|---|---|
| +5 sn | BigText | açılınca uzun metin |
| +15 sn | BigPicture | açılınca fiş görseli; Belgeleri aç / Harcama ekle / Sessize al |
| +30 sn | BigPicture (`showBigPictureWhenCollapsed`) | kapalıyken de görsel |
| +45 sn | Inbox | son 5 harcama |
| +60 sn | Progress | bu ay / geçen ay |
| +90 sn | Messaging | yanıt kutulu düğme |
| +120 sn | Grup özeti | hepsini tek grupta toplar |

Uygulama öne gelirse bekleyenler iptal edilir. Bildirime dokununca yalnız
dört hedef açılabilir (`NotificationTarget`: ana sayfa, belgeler, yeni
harcama, Ders 19); yük yol değil hedefin adıdır, açılış tipli rotayla olur.
Uygulamayı açmayan düğmeler (Sessize al, Yanıtla) ayrı bir isolate'te çalışır
ve sonucu `SharedPreferencesAsync`'e yazar; yanıt metni saklanmaz.

### Ders 20 — Firebase AI ile harcama asistanı

Her ekranın sağındaki turuncu balon ya da Dersler → *Harcama asistanı*
(`views/view_assistant/`). Çekirdek `core/ai/` altında; paket: `firebase_ai`
(Firebase AI Logic, Gemini Developer API).

**Persona.** Asistanın adı Kumbara; uzmanlık alanı harcama takibidir.
Sistem talimatı (`assistant_persona.dart`) kim olduğunu, kategori ipuçlarını
ve kuralları verir; bugünün tarihi de eklenir ki "dün" çözülebilsin. Konu
dışı her istekte (genel bilgi, kod, hava durumu, yatırım tavsiyesi, "önceki
talimatları unut" ...) model metin yazmaz, `konu_disi` aracını çağırır;
ekranda her zaman uygulamanın kendi sabit ret metni görünür.

**Function calling.** Model veriye dokunamaz, yalnız araç çağırır; aracı
uygulama çalıştırır (`expense_toolbox.dart`) ve sonucu modele geri yollar:

| Araç | Ne yapar | Denetim |
|---|---|---|
| `harcama_ekle` | tutar, kategori, not, tarih | 0 < tutar ≤ 1.000.000; bilinen kategori; gelecek ya da 2 yıldan eski tarih yok; not ≤ 80 karakter |
| `son_harcamayi_duzelt` | yalnız verilen alanlar | aynı denetimler |
| `son_harcamayi_sil` | bu sohbette dokunulan, yoksa en yeni kayıt | — |
| `harcama_ozeti` | dönem toplamı, kategori payları | modele not gitmez |
| `konu_disi` | ret | sabit metin |

Kayıt hemen oluşur; sohbette kart ve *Geri al* düğmesi çıkar. Bir mesajda en
çok 5 araç turu, mesaj en çok 500 karakter. Model adı Remote Config'teki
`asistan_modeli`'nden gelir (yalnız `gemini-…` biçimi kabul edilir).

**Her ekranda balon.** `MaterialApp.router(builder:)` içindeki her şey bütün
sayfaların üstünde durur; balon oradadır. Sohbet uygulama genelindeki tek
`AssistantChatCubit`'tedir, panel ile tam ekran aynı konuşmayı gösterir.
builder Navigator'ın dışında olduğundan panel kendi `Overlay`'ini taşır
(metin alanı menüsü bunu ister). Tam ekran açıkken balon gizlenir
(`TopRouteObserver`).

## Güvenlik: projenin Gemini kotasını başkası kullanmasın

Bu repo herkese açık. Firebase'in istemci ayarları
(`lib/firebase_options.dart`, `android/app/google-services.json`) bir API
anahtarı taşır. Bu anahtar yalnız projeyi tanıtır, tek başına yetki vermez;
ama repoda durursa onu bulan biri uygulamayı bu projeye bağlı derleyip
Firebase AI kotasını harcamaya çalışabilir. Bu yüzden:

- İki dosya **repoya girmez** (`.gitignore`); her geliştirici kendi Firebase
  projesiyle üretir (bkz. Kurulum).
- Anahtar git geçmişinden de temizlendi; GitHub'daki hiçbir commit'te yok.
  Ek olarak App Check zorunlu olduğundan AI Logic, resmi uygulama dışındaki
  istekleri reddeder (doğrulandı: belirteçsiz istek → 401).
- Gemini Developer API anahtarı uygulamada hiç durmaz; Firebase AI Logic'in
  sunucusunda kalır.

**Kodda alınan önlemler**

| Önlem | Nerede |
|---|---|
| Her AI isteği App Check belirteciyle gider; "limited use" belirteç tek kullanımlıktır, ele geçirilip tekrar oynatılamaz | `FirebaseAI.googleAI(useLimitedUseAppCheckTokens: true)` |
| Yayın derlemesinde Play Integrity; debug sağlayıcı yalnız `kDebugMode`'da, debug belirteci repoda değil, yalnız konsolda kayıtlı | `FirebaseAppCheckGuard` |
| Asistan yalnız Google ile giriş yapan kullanıcıya görünür | `AppGate` → balon |
| Uygulama içi sınır: dakikada 8, günde 100 mesaj | `AssistantQuota` |
| Yanıt en çok 512 token, mesaj en çok 500 karakter, mesaj başına en çok 5 araç turu | `assistant_chat.dart`, `expense_assistant.dart` |
| Model yalnız harcama araçlarını çağırabilir; değerler uygulamada denetlenir | `ExpenseToolbox` |
| Firestore kuralları: herkes yalnız kendi `kullanicilar/{uid}` verisine | `firestore.rules` |
| Model adı uzaktan değişir ama yalnız `gemini-…` biçiminde | `RemoteAppConfig` |

**Konsolda yapılması gerekenler** (asıl koruma bunlardır; istemci tarafındaki
sınırlar atlatılabilir, sunucu tarafındakiler atlatılamaz):

1. **App Check → APIs → Firebase AI Logic → Enforce.** Bundan sonra Play
   Integrity'den geçemeyen (resmi imzalı olmayan) ya da kayıtlı debug
   belirteci olmayan her istek reddedilir. Aynısı Cloud Firestore ve
   Authentication için de açılmalı.
2. **App Check → Apps → Android → Play Integrity**'ye yayın imzasının SHA-256
   parmak izi eklenmeli (debug parmak izi yalnız geliştirme içindir).
3. **AI Logic → Settings → Rate limits:** kullanıcı başına dakikalık istek
   sınırı düşürülmeli (ör. 10/dk).
4. **Google Cloud Console → APIs & Services → Credentials:** Android API
   anahtarı "Android apps" ile `com.ogzhner.flutter_ders` paket adı ve imza
   SHA-1'ine kısıtlanmalı; yalnız kullanılan API'lere izin verilmeli.
5. **Faturalandırma:** Blaze'e geçilirse Cloud Billing'de bütçe uyarısı
   kurulmalı. Spark planında ücretsiz kota dolunca istekler durur, fatura
   çıkmaz.

Debug belirteci bir kez sızarsa konsolda App Check → Debug belirteçleri'nden
silinip yenisi kaydedilir.

## Kurulum (kendi Firebase projenle)

Firebase ayar dosyaları repoda yok; derlemeden önce üretilir:

```bash
npm install -g firebase-tools        # ya da npm --prefix ~/.npm-global
dart pub global activate flutterfire_cli
firebase login
flutterfire configure --project=<firebase-proje-kimligin> --platforms=android
```

Bu komut `lib/firebase_options.dart` ve `android/app/google-services.json`
dosyalarını üretir (ikisi de `.gitignore`'da). Komut yerine örnek dosyalar da
kullanılabilir: `lib/firebase_options.example.dart` ve
`android/app/google-services.example.json` dosyalarını `.example` olmadan
kopyalayıp **kendi anahtarınızı koyunuz**. Proje sahibinin anahtarı yalnız
kendi bilgisayarındaki yerel derlemede durur, GitHub'da yoktur. Ardından konsolda: Google ile
giriş (Authentication), Firestore (`firebase deploy --only firestore`),
Remote Config (`firebase deploy --only remoteconfig`), App Check ve AI Logic
(Gemini Developer API) açılır; Güvenlik bölümündeki adımlar uygulanır.

## Komutlar

```bash
flutter pub get
dart run build_runner build     # rota tablosu değişince (app_router.gr.dart)
flutter analyze
flutter test
flutter run                     # bağlı Android/iOS cihaz ya da emülatör
python3 tool/firestore_seed_uret.py           # örnek veriyi yeniden üret
firebase deploy --only remoteconfig,firestore # şablon, kurallar, indeksler
```
