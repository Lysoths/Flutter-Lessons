import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_ders/app/core/analytics/app_events.dart';
import 'package:flutter_ders/app/core/firebase/finance_store.dart';

/// DERS 18 — Firestore panelinin durumu.
class FirestoreLabState extends Equatable {
  /// Oluşturur.
  const FirestoreLabState({this.busy = false, this.snapshot, this.error});

  /// İstek sürüyor mu?
  final bool busy;

  /// Son okunan veri.
  final FinanceSnapshot? snapshot;

  /// Son hata.
  final String? error;

  @override
  List<Object?> get props => [busy, snapshot, error];

  // Harcama notları ve tutarlar kayıtlara yazılmaz.
  @override
  String toString() =>
      'FirestoreLabState(busy: $busy, sayılar: ${snapshot?.counts}, '
      'hata: $error)';
}

/// DERS 18 — Seed yükleme, okuma ve temizleme.
class FirestoreLabCubit extends Cubit<FirestoreLabState> {
  /// Oluşturur; [uid] oturumdaki kullanıcıyı verir (yoksa null).
  FirestoreLabCubit({
    required this._store,
    required this._seedSource,
    required this._uid,
  }) : super(const FirestoreLabState());

  final FinanceStore _store;
  final Future<String> Function() _seedSource;
  final String? Function() _uid;

  Future<void> _run(Future<void> Function(String uid) work) async {
    final uid = _uid();
    if (uid == null || state.busy) return;
    emit(FirestoreLabState(busy: true, snapshot: state.snapshot));
    try {
      await work(uid);
      final snap = await _store.read(uid);
      if (!isClosed) emit(FirestoreLabState(snapshot: snap));
    } on Object catch (e) {
      if (!isClosed) {
        emit(FirestoreLabState(snapshot: state.snapshot, error: _short(e)));
      }
    }
  }

  /// Kullanıcının verisini okur.
  Future<void> load() => _run((_) async {});

  /// Seed verisini yazar.
  Future<void> seed() => _run((uid) async {
    track(AppEvent.firestoreSeeded);
    await _store.seed(uid, FinanceSeed.parse(await _seedSource()));
  });

  /// Kullanıcının bütün verisini siler.
  Future<void> clear() => _run((uid) async {
    track(AppEvent.firestoreCleared);
    await _store.clear(uid);
  });

  static String _short(Object e) {
    final s = '$e';
    return s.length > 200 ? '${s.substring(0, 200)}…' : s;
  }
}
