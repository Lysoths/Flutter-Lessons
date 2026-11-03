import 'dart:io';

import 'package:flutter_ders/app/core/repository/note_store.dart';
import 'package:flutter_ders/app/models/storage_note.dart';
import 'package:hive_ce/hive_ce.dart';

/// DERS 10 — Hive (hive_ce): NoSQL, nesne temelli.
///
/// Tablo yok, SQL yok. Veriler "kutu"larda (Box) anahtar → NESNE olarak
/// durur; MongoDB'deki koleksiyon / belge gibi. Nesneyi diske yazmak için
/// bir TypeAdapter gerekir: nesneyi ikili (binary) biçime çevirir ve
/// geri okur. Kutu açılınca içerik belleğe alınır, okumalar SENKRONDUR
/// (`box.get(id)`); yazmalar diske arkadan işlenir.
///
/// hive_ce: asıl Hive paketi güncellenmeyince topluluğun sürdürdüğü sürüm
/// ("community edition"). masterfabric_core da bunu kullanır.
class HiveNoteStore implements NoteStore {
  /// Depoyu oluşturur. [init], Hive'ın klasörünü hazırlar (uygulamada
  /// `Hive.initFlutter`, testte geçici bir klasör).
  HiveNoteStore({required this._init});

  /// Bu dersin kutusu.
  static const boxName = 'ders10_notes';

  final Future<void> Function() _init;
  Box<StorageNote>? _box;

  @override
  StorageKind get kind => StorageKind.hive;

  Box<StorageNote> get _opened {
    final box = _box;
    if (box == null) throw StateError('Önce open() çağrılmalı');
    return box;
  }

  @override
  Future<void> open() async {
    if (_box != null) return;
    await _init();
    if (!Hive.isAdapterRegistered(StorageNoteAdapter.id)) {
      Hive.registerAdapter(StorageNoteAdapter());
    }
    _box = await Hive.openBox<StorageNote>(boxName);
  }

  @override
  Future<List<StorageNote>> getAll() async =>
      _opened.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  Future<void> add(StorageNote note) => _opened.put(note.id, note);

  @override
  Future<void> addAll(List<StorageNote> notes) =>
      _opened.putAll({for (final n in notes) n.id: n});

  @override
  Future<void> delete(String id) => _opened.delete(id);

  @override
  Future<void> clear() => _opened.clear();

  @override
  Future<String> rawView() async {
    final box = _opened;
    final keys = box.keys.take(5).toList();
    final lines = [
      for (final k in keys)
        // box.get SENKRON: await yok.
        "box.get('$k') → ${_describe(box.get(k))}",
    ];
    return "Kutu: '${box.name}' · ${box.length} nesne\n"
        'Dosya: ${box.path ?? '(bellekte)'}\n\n'
        '${lines.isEmpty ? '(boş)' : lines.join('\n')}'
        '${box.length > keys.length ? '\n…' : ''}';
  }

  @override
  Future<StoreBenchmark> benchmark(List<StorageNote> notes) async {
    final box = _opened;
    var read = <StorageNote>[];
    final write = await measure(
      () => box.putAll({for (final n in notes) n.id: n}),
    );
    final flush = await measure(box.flush);
    final memoryRead = await measure(() => read = box.values.toList());
    // Kapatıp yeniden açmak, verinin diskten gerçekten okunmasını sağlar.
    await box.close();
    final diskRead = await measure(() async {
      _box = await Hive.openBox<StorageNote>(boxName);
    });
    final path = _opened.path;
    final file = path == null ? null : File(path);
    return (
      steps: <BenchmarkStep>[
        (
          label: 'Kutuya yaz',
          detail:
              'putAll: TypeAdapter ${notes.length} nesneyi ikili biçime '
              'çevirir, belleğe ve dosyaya ekler',
          time: write,
          isWrite: true,
        ),
        (
          label: 'Diske kesinleştir',
          detail: 'flush: bekleyen yazmalar dosyaya işlenir',
          time: flush,
          isWrite: true,
        ),
        (
          label: 'Bellekten oku',
          detail: 'box.values: ${read.length} nesne zaten bellekte (senkron)',
          time: memoryRead,
          isWrite: false,
        ),
        (
          label: 'Diskten yeniden aç',
          detail:
              'openBox: dosya baştan okunur, nesneler TypeAdapter ile '
              'çözülür',
          time: diskRead,
          isWrite: false,
        ),
      ],
      bytes: file != null && file.existsSync() ? await file.length() : null,
    );
  }

  static String _describe(StorageNote? n) => n == null
      ? 'null'
      : 'StorageNote(title: ${n.title}, amount: ${n.amount})';
}

/// [StorageNote] nesnesini Hive'ın ikili biçimine çevirir ve geri okur.
///
/// Alanlar YAZILDIĞI SIRAYLA okunur. Genelde `hive_ce_generator` bunu
/// kendisi üretir; derste ne yaptığı görünsün diye elle yazıldı.
class StorageNoteAdapter extends TypeAdapter<StorageNote> {
  /// Bu türün Hive'daki numarası (uygulamada tekil olmalı).
  static const id = 10;

  @override
  int get typeId => id;

  @override
  StorageNote read(BinaryReader reader) => StorageNote(
    id: reader.readString(),
    title: reader.readString(),
    amount: reader.readDouble(),
    createdAt: DateTime.fromMillisecondsSinceEpoch(reader.readInt()),
  );

  @override
  void write(BinaryWriter writer, StorageNote obj) {
    writer
      ..writeString(obj.id)
      ..writeString(obj.title)
      ..writeDouble(obj.amount)
      ..writeInt(obj.createdAt.millisecondsSinceEpoch);
  }
}
