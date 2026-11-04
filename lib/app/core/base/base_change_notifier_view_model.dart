import 'package:flutter/foundation.dart';

/// DERS 15 — Bir ViewModel'in yüklenme durumu.
enum ViewStatus {
  /// Henüz bir şey istenmedi.
  idle,

  /// İş sürüyor.
  busy,

  /// Veri hazır.
  ready,

  /// Son iş başarısız oldu.
  failure,
}

/// DERS 15 — MVVM: `ChangeNotifier` ile çalışan ViewModel'lerin temel sınıfı.
///
///   View  ──vm.metot()──▶  ViewModel  ──await──▶  Repository (Model)
///   View  ◀──notifyListeners()──┘
///
/// Cubit'ten farkı: durum tek bir değişmez nesne değil, ViewModel'in kendi
/// alanlarıdır. Alan değişince `notifyListeners()` çağrılır, dinleyen
/// widget'lar yeniden çizilir. C#'taki `INotifyPropertyChanged` ile aynı fikir.
///
/// View yalnızca okur (getter) ve metot çağırır; alanları değiştiremez.
abstract class BaseChangeNotifierViewModel extends ChangeNotifier {
  ViewStatus _status = ViewStatus.idle;
  String? _error;
  bool _disposed = false;

  /// Yüklenme durumu.
  ViewStatus get status => _status;

  /// Son hatanın açıklaması.
  String? get error => _error;

  /// İş sürüyor mu?
  bool get isBusy => _status == ViewStatus.busy;

  /// ViewModel kapatıldı mı (sayfadan çıkıldı mı)?
  bool get isDisposed => _disposed;

  /// [task]'ı çalıştırır: önce `busy`, bitince `ready` ya da `failure`.
  ///
  /// [task] fırlatırsa hata [describe] ile Türkçe açıklamaya çevrilir.
  @protected
  Future<void> runTask(
    Future<void> Function() task, {
    required String Function(Object error) describe,
  }) async {
    _status = ViewStatus.busy;
    _error = null;
    notifyListeners();
    try {
      await task();
      _status = ViewStatus.ready;
    } on Object catch (e) {
      _status = ViewStatus.failure;
      _error = describe(e);
    }
    notifyListeners();
  }

  /// Durumu elle değiştirir (birden çok isteği kendisi yöneten
  /// ViewModel'ler için).
  @protected
  void setStatus(ViewStatus status, {String? error}) {
    _status = status;
    _error = error;
    notifyListeners();
  }

  // Sayfa kapandıktan sonra gelen cevap çizim istemesin (hata verirdi).
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
