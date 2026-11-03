import 'dart:io';

import 'package:flutter_ders/app/core/repository/note_store.dart';
import 'package:flutter_ders/app/models/storage_note.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// DERS 10 — sqflite: telefondaki SQLite veritabanı.
///
/// Klasik veritabanı: önce TABLO tanımlanır (sütunlar ve türleri), her
/// kayıt bir SATIR olur, okuma / yazma SQL ile yapılır. Sıralama, filtre,
/// toplam gibi işleri veritabanı yapar (`ORDER BY`, `WHERE`, `SUM`).
/// Her işlem diske gider, bu yüzden hepsi ASENKRONDUR.
class SqfliteNoteStore implements NoteStore {
  /// Depoyu oluşturur. [factory] ve [path] testte bellekte çalışmak
  /// içindir; uygulamada telefonun veritabanı klasörü kullanılır.
  SqfliteNoteStore({DatabaseFactory? factory, this._path})
    : _factory = factory ?? databaseFactory;

  /// Tablo adı.
  static const table = 'notes';

  /// Tabloyu kuran SQL (yalnızca ilk açılışta çalışır).
  static const createSql = '''
CREATE TABLE notes (
  id         TEXT PRIMARY KEY,
  title      TEXT NOT NULL,
  amount     REAL NOT NULL,
  created_at INTEGER NOT NULL
)''';

  final DatabaseFactory _factory;
  final String? _path;
  Database? _db;

  /// Son çalışan SQL komutları (ekranda gösterilir).
  final List<String> sqlLog = [];

  @override
  StorageKind get kind => StorageKind.sqflite;

  Database get _opened {
    final db = _db;
    if (db == null) throw StateError('Önce open() çağrılmalı');
    return db;
  }

  void _log(String sql) {
    sqlLog.insert(0, sql);
    if (sqlLog.length > 6) sqlLog.removeLast();
  }

  @override
  Future<void> open() async {
    if (_db != null) return;
    final path =
        _path ?? p.join(await _factory.getDatabasesPath(), 'ders10.db');
    _db = await _factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) => db.execute(createSql),
      ),
    );
  }

  @override
  Future<List<StorageNote>> getAll() async {
    _log('SELECT * FROM notes ORDER BY created_at DESC');
    final rows = await _opened.query(table, orderBy: 'created_at DESC');
    return [for (final r in rows) StorageNote.fromMap(r)];
  }

  @override
  Future<void> add(StorageNote note) async {
    _log('INSERT INTO notes VALUES (?, ?, ?, ?)');
    await _opened.insert(table, note.toMap());
  }

  @override
  Future<void> addAll(List<StorageNote> notes) async {
    _log('BEGIN; INSERT × ${notes.length}; COMMIT');
    // Tek işlem (transaction) + toplu komut: her satır için ayrı disk
    // yazımı yerine hepsi bir kerede.
    await _opened.transaction((txn) async {
      final batch = txn.batch();
      for (final n in notes) {
        batch.insert(table, n.toMap());
      }
      await batch.commit(noResult: true);
    });
  }

  @override
  Future<void> delete(String id) async {
    _log('DELETE FROM notes WHERE id = ?');
    await _opened.delete(table, where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> clear() async {
    _log('DELETE FROM notes');
    await _opened.delete(table);
  }

  @override
  Future<String> rawView() async {
    final db = _opened;
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM notes'),
    );
    final sum = (await db.rawQuery('SELECT SUM(amount) AS s FROM notes'))
        .first['s'];
    final rows = await db.query(table, orderBy: 'created_at DESC', limit: 3);
    return '$createSql\n\n'
        'SELECT COUNT(*) → $count\n'
        'SELECT SUM(amount) → ${(sum as num?)?.toStringAsFixed(2) ?? 0}\n\n'
        'Son 3 satır:\n'
        '${rows.isEmpty ? '(boş)' : rows.map((r) => r.values.join(' | ')).join('\n')}\n\n'
        'Son SQL komutları:\n${sqlLog.join('\n')}';
  }

  @override
  Future<StoreBenchmark> benchmark(List<StorageNote> notes) async {
    final db = _opened;
    var rows = <Map<String, Object?>>[];
    var matched = 0;
    final write = await measure(() => addAll(notes));
    final query = await measure(() async {
      rows = await db.query(table, orderBy: 'created_at DESC');
    });
    final convert = await measure(() {
      for (final r in rows) {
        StorageNote.fromMap(r);
      }
    });
    final count = await measure(
      () => db.rawQuery('SELECT COUNT(*) FROM notes'),
    );
    final filter = await measure(() async {
      matched = (await db.query(
        table,
        where: 'amount > ?',
        whereArgs: [100],
      )).length;
    });
    final sum = await measure(
      () => db.rawQuery('SELECT SUM(amount) FROM notes'),
    );
    final file = db.path == inMemoryDatabasePath ? null : File(db.path);
    return (
      steps: <BenchmarkStep>[
        (
          label: 'Tabloya yaz',
          detail:
              'transaction + batch: ${notes.length} INSERT tek işlemde '
              'diske yazılır',
          time: write,
          isWrite: true,
        ),
        (
          label: 'SQL sorgusu',
          detail:
              'SELECT * ORDER BY created_at DESC: ${rows.length} satır, '
              'sıralamayı veritabanı yapar',
          time: query,
          isWrite: false,
        ),
        (
          label: 'Satırdan nesneye',
          detail: 'fromMap: her satır bir StorageNote olur',
          time: convert,
          isWrite: false,
        ),
        (
          label: 'Sayım',
          detail: 'SELECT COUNT(*): satırlar taşınmaz, tek sayı döner',
          time: count,
          isWrite: false,
        ),
        (
          label: 'Filtre',
          detail: 'WHERE amount > 100: yalnızca eşleşen $matched satır gelir',
          time: filter,
          isWrite: false,
        ),
        (
          label: 'Toplam',
          detail: 'SELECT SUM(amount): toplamı veritabanı hesaplar',
          time: sum,
          isWrite: false,
        ),
      ],
      bytes: file != null && file.existsSync() ? await file.length() : null,
    );
  }
}
