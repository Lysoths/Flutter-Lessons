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

## Komutlar

```bash
flutter pub get
flutter analyze
flutter test
flutter run -d chrome     # veya -d macos, iOS simülatörü, Android emülatörü
```
