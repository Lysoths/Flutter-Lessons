import 'dart:convert';

import 'package:flutter_ders/app/core/repository/note_store.dart';
import 'package:flutter_ders/app/models/storage_note.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// DERS 10 — SharedPreferences: anahtar → değer.
///
/// Tarayıcıdaki `localStorage.setItem('anahtar', 'yazı')` ile aynı fikir:
/// yalnızca basit türler (`String`, `int`, `double`, `bool`, `List<String>`)
/// saklanır. Liste saklamak için bütün listeyi JSON METNİNE çevirip TEK
/// anahtara yazarız. Bir kayıt değişse bile metnin tamamı yeniden yazılır;
/// bu yüzden ayarlar gibi küçük veriler için uygundur.
class PrefsNoteStore implements NoteStore {
  /// [prefs] üzerinde çalışan depo oluşturur.
  PrefsNoteStore(this._prefs);

  /// Bu dersin anahtarı (gerçek harcamalar 'expenses' anahtarında).
  static const storageKey = 'ders10_notes';

  final SharedPreferences _prefs;

  @override
  StorageKind get kind => StorageKind.sharedPreferences;

  @override
  Future<void> open() async {}

  List<StorageNote> _read() {
    // getString SENKRONDUR: getInstance() açılışta hepsini belleğe okudu.
    final raw = _prefs.getString(storageKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<Object?>;
    return [
      for (final m in list) StorageNote.fromMap(m! as Map<String, Object?>),
    ];
  }

  Future<void> _write(List<StorageNote> notes) => _prefs.setString(
    storageKey,
    jsonEncode([for (final n in notes) n.toMap()]),
  );

  @override
  Future<List<StorageNote>> getAll() async =>
      _read()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  Future<void> add(StorageNote note) => _write([..._read(), note]);

  @override
  Future<void> addAll(List<StorageNote> notes) =>
      _write([..._read(), ...notes]);

  @override
  Future<void> delete(String id) =>
      _write(_read()..removeWhere((n) => n.id == id));

  @override
  Future<void> clear() => _prefs.remove(storageKey);

  @override
  Future<String> rawView() async {
    final raw = _prefs.getString(storageKey);
    final keys = _prefs.getKeys().toList()..sort();
    final shown = raw == null
        ? '(boş)'
        : raw.length > 600
        ? '${raw.substring(0, 600)}… (${raw.length} karakter)'
        : raw;
    return 'Tüm anahtarlar: ${keys.join(', ')}\n\n'
        "prefs.getString('$storageKey') →\n$shown";
  }

  @override
  Future<StoreBenchmark> benchmark(List<StorageNote> notes) async {
    var json = '';
    String? raw;
    final encode = await measure(() {
      json = jsonEncode([for (final n in notes) n.toMap()]);
    });
    final write = await measure(() => _prefs.setString(storageKey, json));
    final memoryRead = await measure(() => raw = _prefs.getString(storageKey));
    final decode = await measure(() {
      final list = jsonDecode(raw!) as List<Object?>;
      for (final m in list) {
        StorageNote.fromMap(m! as Map<String, Object?>);
      }
    });
    final diskRead = await measure(_prefs.reload);
    return (
      steps: <BenchmarkStep>[
        (
          label: "JSON'a çevir",
          detail: 'jsonEncode: ${notes.length} nesne → tek bir metin',
          time: encode,
          isWrite: true,
        ),
        (
          label: 'Diske yaz',
          detail: 'setString: metnin TAMAMI ayar dosyasına yazılır',
          time: write,
          isWrite: true,
        ),
        (
          label: 'Bellekten oku',
          detail: 'getString: metin zaten bellekte, diske gidilmez',
          time: memoryRead,
          isWrite: false,
        ),
        (
          label: 'Metinden nesneye',
          detail: 'jsonDecode + fromMap: metin tekrar nesnelere çevrilir',
          time: decode,
          isWrite: false,
        ),
        (
          label: 'Diskten yeniden yükle',
          detail: 'reload: ayar dosyası diskten baştan okunur',
          time: diskRead,
          isWrite: false,
        ),
      ],
      bytes: utf8.encode(json).length,
    );
  }
}
