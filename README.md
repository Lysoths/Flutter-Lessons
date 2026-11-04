# Harcama Takibi

Harcamaları telefon hafızasına kaydeden basit bir Flutter uygulaması.
Yapı [masterfabric-flutter-duo](https://github.com/masterfabric/masterfabric-flutter-duo)
standardını izler (masterfabric_core konvansiyonları: `BaseViewModelCubit`,
Equatable state, get_it, `view_<ad>/` klasörleri, sıkı lint) ve Cubit kullanımı
[bloclibrary sayaç eğitimine](https://bloclibrary.dev/tutorials/flutter-counter/) dayanır.

## Yapı

```
lib/
├── main.dart                               # observer + DI + runApp
└── app/
    ├── app.dart                            # HarcamaApp: tema + ilk ekran
    ├── core/
    │   ├── base/base_view_model_cubit.dart # tüm cubit'lerin temeli (stateChanger)
    │   ├── bloc/app_bloc_observer.dart     # durum değişikliklerini konsola yazar
    │   ├── router/app_router.dart          # Ders 4: auto_route rota tablosu
    │   ├── router/app_router.gr.dart       # build_runner'ın ürettiği rota sınıfları
    │   ├── router/app_deep_links.dart      # Ders 4: deep link beyaz listesi
    │   ├── router/route_transitions.dart   # Ders 6: 20 geçiş animasyonu (RouteAnimation)
    │   ├── di/injection.dart               # get_it kayıtları
    │   └── repository/
    │       ├── expense_repository.dart       # "veri nerede?" sözleşmesi
    │       └── local_expense_repository.dart # telefon hafızası (shared_preferences)
    ├── helper/money_format.dart            # 1.234,50 ₺, tarih, "Bugün/Dün", ay adı
    ├── models/expense.dart                 # Expense + ExpenseCategory
    ├── models/document_item.dart           # Ders 5: gömülü belge listesi (kDocuments)
    ├── theme/
    │   ├── app_theme.dart                  # MfColors + AppTheme (duo standardı)
    │   └── category_style.dart             # kategori renkleri
    ├── widgets/common.dart                 # Eyebrow, SectionHeader, IconBadge, Gap
    ├── views/view_category/
    │   └── category_expenses_view.dart     # /kategori/:slug
    ├── views/view_new_expense/
    │   └── new_expense_view.dart           # /yeni (alttan açılan form rotası)
    ├── views/view_documents/               # Ders 5: /belgeler listesi
    ├── views/view_image_viewer/            # Ders 5: görsel (Image.asset)
    ├── views/view_pdf_viewer/              # Ders 5: PDF (pdfrx)
    ├── views/view_audio_player/            # Ders 5: ses (just_audio)
    ├── views/view_animations/              # Ders 6: animasyon vitrini + demo sayfası
    ├── views/view_expense_detail/
    │   └── expense_detail_view.dart        # Ders 1: Navigation 1.0 ile açılan detay
    └── views/view_expenses/
        ├── expenses_view.dart              # özet + kategoriler + gruplu liste
        ├── cubit/{expenses_cubit,expenses_state}.dart
        └── widgets/
            ├── month_summary_card.dart       # bu ayın koyu özet kartı
            ├── category_breakdown_widget.dart# kategori dağılımı
            ├── expense_tile_widget.dart      # dokun: düzenle, kaydır: sil
            └── expense_form_sheet.dart       # ekleme/düzenleme formu
```

## Veri akışı

```
Ekran (View) ──çağırır──▶ ExpensesCubit ──kaydeder──▶ ExpenseRepository ──▶ telefon hafızası
     ▲                         │
     └────yeni state───────────┘
```

Google Sheets eklenecekse: `ExpenseRepository`'yi uygulayan yeni bir sınıf
yazılır ve `injection.dart`'ta `LocalExpenseRepository` yerine kaydedilir.

## Dersler

> **Bu dal: `auto-route`.** Ders 1–3 (Navigator push/pop, Navigation 2.0
> RouterDelegate, elle yazılmış deep link parser) `main` dalındadır:
> `git switch main`. Bu dalda aynı uygulamanın tüm yönlendirmesi
> **auto_route** ile yapılır; ekranlar ve veri katmanı aynıdır.

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

Deep link: `harcamatakibim://app/kategori/<ad>` ve `harcamatakibim://app/yeni`
(Android/iOS tanımları `main` ile aynı). auto_route linki rota tablosuyla
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

Not: auto_route rotaları varsayılan olarak **adıyla** tanır. 20 senaryo aynı
adı (`AnimationDemoRoute`) taşıdığı için "Sonraki" yeni sayfa açmıyordu;
demo rotası `usesPathAsKey: true` ile **yoluyla** tanınır.

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

Android: `INTERNET` izni ana manifeste eklendi (yayın sürümü için).

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
  engelliyor. Frankfurter'ın geçmiş kur servisi bu ders yazılırken 522 hatası
  veriyordu.
- Geçmiş: haftalık her gün (8 nokta), aylık iki günde bir (16), 3 aylık
  haftada bir (14). Günler önbellekte tutulur; aralık değişince eski günler
  yeniden indirilmez. Hızlı değiştirince yalnızca son isteğin sonucu yazılır.
- Haberler: Anadolu Ajansı ve TRT Haber ekonomi RSS beslemeleri, `xml`
  paketiyle. Biri çökerse diğeri gösterilir. Modaldaki "sitesinde oku"
  yalnızca `aa.com.tr` ve `trthaber.com` adreslerini açar (`url_launcher`).

## Komutlar

```bash
flutter pub get
flutter analyze
flutter test
flutter run -d chrome     # veya -d macos, iOS simülatörü, Android emülatörü
```
