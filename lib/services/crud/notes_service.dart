import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:learningdart/services/crud/crud_exceptions.dart';
import 'package:path/path.dart' show join;
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';

class NotesService {
  Database? _db;

  Database _getDatabaseOrThrow() {
    final Database? db = _db;
    if (db == null) {
      throw DatabaseIsNotOpenException();
    }
    return db;
  }

  Future<void> deleteUser({required String email}) async {
    final Database db = _getDatabaseOrThrow();
    final deletedCount = await db.delete(
      userTable,
      where: '$emailColumn = ?',
      whereArgs: [email.toLowerCase()],
    );
    if (deletedCount == 0) {
      throw CouldNotDeleteUserException();
    }
  }

  Future<DatabaseUser> createUser({required String email}) async {
    final db = _getDatabaseOrThrow();
    final emailLower = email.toLowerCase();
    final result = await db.query(
      userTable,
      limit: 1,
      where: '$emailColumn = ?',
      whereArgs: [emailLower],
    );
    if (result.isNotEmpty) {
      throw UserAlreadyExistsException();
    }
    final userId = await db.insert(userTable, {emailColumn: emailLower});
    return DatabaseUser(id: userId, email: email);
  }

  Future<DatabaseUser> getUser({required String email}) async {
    final db = _getDatabaseOrThrow();
    final result = await db.query(
      userTable,
      limit: 1,
      where: '$emailColumn = ?',
      whereArgs: [email.toLowerCase()],
    );
    if (result.isEmpty) {
      throw UserNotFoundException();
    }
    return DatabaseUser.fromRow(result.first);
  }

  Future<DatabaseNote> createNote({required DatabaseUser owner}) async {
    final db = _getDatabaseOrThrow();

    final dbUser = await getUser(email: owner.email);

    if (dbUser.id != owner.id) {
      throw UserNotFoundException();
    }
    final text = '';
    final noteId = await db.insert(noteTable, {
      userIdColumn: owner.id,
      textColumn: text,
      isSyncedWithCloudColumn: 0,
    });
    return DatabaseNote(
      id: noteId,
      userId: owner.id,
      text: text,
      isSynced: false,
    );
  }

  Future<void> deleteNote({required int id}) async {
    final db = _getDatabaseOrThrow();
    final deletedCount = await db.delete(
      noteTable,
      where: '$idColumn = ?',
      whereArgs: [id],
    );
    if (deletedCount == 0) {
      throw CouldNotDeleteUserException();
    }
  }

  Future<Iterable<DatabaseNote>> getAllNotes() async {
    final db = _getDatabaseOrThrow();
    final notes = await db.query(noteTable);
    if (notes.isEmpty) {
      throw NoteNotFoundException();
    }
    return notes.map((note) => DatabaseNote.fromRow(note));
  }

  Future<DatabaseNote> updateNote({
    required DatabaseNote note,
    required String text,
  }) async {
    final db = _getDatabaseOrThrow();

    await getNote(id: note.id);

    final updatedCount = await db.update(
      noteTable,
      {textColumn: text, isSyncedWithCloudColumn: 0},
      where: '$idColumn = ?',
      whereArgs: [note.id],
    );
    if (updatedCount == 0) {
      throw CouldNotUpdateNoteException();
    }
    return await getNote(id: note.id);
  }

  Future<void> deleteAllNotes() async {
    final db = _getDatabaseOrThrow();
    await db.delete(noteTable);
  }

  Future<DatabaseNote> getNote({required int id}) async {
    final _db = _getDatabaseOrThrow();
    final notes = await _db.query(
      noteTable,
      limit: 1,
      where: '$idColumn = ?',
      whereArgs: [id],
    );
    if (notes.isEmpty) {
      throw NoteNotFoundException();
    }
    return DatabaseNote.fromRow(notes.first);
  }

  Future<void> open() async {
    if (_db != null) {
      throw DatabaseAlreadyOpenException();
    }
    try {
      final Directory docsPath = await getApplicationDocumentsDirectory();
      final String dbPath = join(docsPath.path, dbName);
      final Database db = await openDatabase(dbPath);
      _db = db;

      await db.execute(createUserTable);
      await db.execute(createNoteTable);
    } on MissingPlatformDirectoryException {
      throw UnableToGetDocumentsDirectoryException();
    } catch (e) {
      throw Exception('Error opening database: $e');
    }
  }

  Future<void> close() async {
    final Database? db = _db;
    if (db == null) {
      throw DatabaseIsNotOpenException();
    }
    await db.close();
    _db = null;
  }
}

@immutable
class DatabaseUser {
  final int id;
  final String email;

  const DatabaseUser({required this.id, required this.email});

  DatabaseUser.fromRow(Map<String, Object?> map)
    : id = map[idColumn] as int,
      email = map[emailColumn] as String;

  @override
  String toString() => 'DatabaseUser{id: $id, email: $email}';

  bool operator ==(covariant DatabaseUser other) => id == other.id;

  @override
  int get hashCode => id.hashCode;
}

@immutable
class DatabaseNote {
  final int id;
  final int userId;
  final String text;
  final bool isSynced;

  const DatabaseNote({
    required this.id,
    required this.userId,
    required this.text,
    required this.isSynced,
  });

  DatabaseNote.fromRow(Map<String, Object?> map)
    : id = map[idColumn] as int,
      userId = map[userIdColumn] as int,
      text = map[textColumn] as String,
      isSynced = (map[isSyncedWithCloudColumn] as int) == 1 ? true : false;

  @override
  String toString() =>
      'DatabaseNote{id: $id, userId=$userId, isSynced: $isSynced,  text: $text}';

  bool operator ==(covariant DatabaseNote other) => id == other.id;

  @override
  int get hashCode => id.hashCode;
}

const dbName = 'notes.db';
const noteTable = 'note';
const userTable = 'user';
const idColumn = 'id';
const emailColumn = 'email';
const textColumn = 'text';
const isSyncedWithCloudColumn = 'is_synced_with_cloud';
const userIdColumn = 'user_id';

const String createUserTable = '''
        CREATE TABLE IF NOT EXISTS $userTable (
          $idColumn INTEGER PRIMARY KEY AUTOINCREMENT,
          $emailColumn TEXT NOT NULL UNIQUE
        )
      ''';
const String createNoteTable = '''
        CREATE TABLE IF NOT EXISTS $noteTable (
          $idColumn INTEGER PRIMARY KEY AUTOINCREMENT,
          $userIdColumn INTEGER NOT NULL,
          $textColumn TEXT NOT NULL,
          $isSyncedWithCloudColumn INTEGER DEFAULT 0,
          FOREIGN KEY ($userIdColumn) REFERENCES $userTable ($idColumn)
        )
      ''';
