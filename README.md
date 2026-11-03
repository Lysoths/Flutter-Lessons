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
    │   ├── bloc/navigation/                # Ders 2: NavigationCubit + NavigationState
    │   ├── router/app_router_delegate.dart # Ders 2: durumdan sayfa listesi kurar
    │   ├── router/app_route_parser.dart    # Ders 3: link yolu ↔ durum (beyaz liste)
    │   ├── di/injection.dart               # get_it kayıtları
    │   └── repository/
    │       ├── expense_repository.dart       # "veri nerede?" sözleşmesi
    │       └── local_expense_repository.dart # telefon hafızası (shared_preferences)
    ├── helper/money_format.dart            # 1.234,50 ₺, tarih, "Bugün/Dün", ay adı
    ├── models/expense.dart                 # Expense + ExpenseCategory
    ├── theme/
    │   ├── app_theme.dart                  # MfColors + AppTheme (duo standardı)
    │   └── category_style.dart             # kategori renkleri
    ├── widgets/common.dart                 # Eyebrow, SectionHeader, IconBadge, Gap
    ├── views/view_category/
    │   └── category_expenses_view.dart     # Ders 2: Navigation 2.0 ile açılan kategori
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

Her ders uygulamaya gerçek bir özellik olarak eklenir. Kodda ilgili yerler
`DERS N` yorumlarıyla işaretlidir.

### Ders 1 — Navigation 1.0 (imperative)

Ekranlar üst üste konan kartlardır: `push` üste koyar, `pop` kaldırır ve
sonuç döndürür. Yalnızca **detay ekranında** kullanılır.

| Ne | Nerede |
|---|---|
| `Navigator.of(context).push(MaterialPageRoute(...))` | `views/view_expenses/expenses_view.dart` → `_openDetail` |
| `Navigator.of(context).pop(sonuç)` | `views/view_expense_detail/expense_detail_view.dart` |
| Tipli sonuç (`ExpenseDetailEdited`, `ExpenseDetailDeleted`) | `expense_detail_view.dart` başı |
| Testler | `test/widget_test.dart` → "DERS 1" |

Akış: listede bir harcamaya dokun → detay açılır (push) → **Düzenle** veya
**Sil** → detay kapanır (pop) ve sonucu listeye bırakır → liste cubit'i
günceller. Geri tuşu `null` döndürür, değişiklik olmaz. Veri ekrana yol/ID
yazısıyla değil, nesne olarak (constructor) gider.

### Ders 2 — Navigation 2.0 (declarative)

"Şu ekranı aç" yerine **durum** tanımlanır; ekran yığını bu durumdan kurulur.
Yalnızca **kategori ekranında** kullanılır (orada `push`/`pop` yok).

```
NavigationState(category: null)  → [Ana sayfa]
NavigationState(category: food)  → [Ana sayfa, Yemek]
```

| Ne | Nerede |
|---|---|
| Durum (`NavigationState`) ve değiştiren (`NavigationCubit`) | `core/bloc/navigation/` |
| Durumdan `pages` listesi kuran `RouterDelegate` | `core/router/app_router_delegate.dart` |
| `MaterialApp.router` + `RootBackButtonDispatcher` | `app.dart` |
| Kategoriye dokununca `openCategory(...)` | `views/view_expenses/expenses_view.dart` |
| Geri düğmesi `backToHome()` (pop değil) | `views/view_category/category_expenses_view.dart` |
| Testler | `test/navigation_cubit_test.dart`, `test/navigation2_test.dart` |

Akış: ana sayfada **Kategori sayfaları** kısayollarından ya da **Kategoriler**
kartından bir kategoriye dokun → cubit durumu
`category: food` olur → delegate sayfa listesine kategori sayfasını ekler.
Geri düğmesi durumu siler, sayfa listeden çıkar. Sistem geri tuşu sayfayı
kaldırırsa `onDidRemovePage` durumu eşitler. Ders 1'in detay ekranı (`push`)
bu Router'ın Navigator'ı üstünde çalışmaya devam eder.

### Ders 3 — Deep link

Telefon dışarıdan gelen bir linki uygulamaya iletir; Flutter linkin yolunu
Router'a verir. `AppRouteParser` yolu Ders 2'deki `NavigationState`'e çevirir,
`AppRouterDelegate` ekranları o duruma göre kurar.

| Link | Sonuç |
|---|---|
| `harcamatakibim://app/` | Ana sayfa |
| `harcamatakibim://app/kategori/<yemek\|ulasim\|fatura\|eglence\|diger>` | Kategori sayfası |
| `harcamatakibim://app/yeni` | Yeni harcama formu (yalnızca açar, kaydetmez) |
| Başka her şey | Ana sayfa |

| Ne | Nerede |
|---|---|
| Link → durum çevirmeni (beyaz liste) | `core/router/app_route_parser.dart` |
| Router'a bağlanması (`routeInformationParser`) | `app.dart` |
| `/yeni` isteğini formu açarak karşılama | `views/view_expenses/expenses_view.dart` → `_NewExpenseRequestListener` |
| Android link tanımı (intent-filter) | `android/app/src/main/AndroidManifest.xml` |
| iOS link tanımı (`CFBundleURLTypes`) | `ios/Runner/Info.plist` |
| Testler | `test/deep_link_test.dart` |

Telefonda denemek (telefon USB ile bağlıyken):

```bash
adb shell am start -a android.intent.action.VIEW -d "harcamatakibim://app/kategori/yemek" com.ogzhner.flutter_ders
```

Güvenlik: uygulama içinde geçişler yine nesne/durum ile yapılır; yol yazısı
yalnızca dışarıdan gelen linki karşılayan parser'da kullanılır. Yalnızca
listedeki yollar kabul edilir, linkte kimlik (ID) ya da tutar kabul edilmez,
sorgu parametreleri yok sayılır. Özel şema (`harcamatakibim://`) doğrulanmadığı
için başka bir uygulama da aynı şemayı tanımlayabilir; bu yüzden linkler hiçbir
zaman veri yazmaz. `https` App Links için `assetlinks.json` gerekir.

## Komutlar

```bash
flutter pub get
flutter analyze
flutter test
flutter run -d chrome     # veya -d macos, iOS simülatörü, Android emülatörü
```
