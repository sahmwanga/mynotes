// import 'dart:async';
// import 'dart:io';

// import 'package:flutter/cupertino.dart';
// import 'package:learningdart/extensions/list/filter.dart';
// import 'package:learningdart/services/crud/crud_exceptions.dart';
// import 'package:path/path.dart' show join;
// import 'package:sqflite/sqflite.dart';
// import 'package:path_provider/path_provider.dart';

// class NotesService {
//   Database? _db;

//   List<DatabaseNote> _notes = [];

//   DatabaseUser? _user;

//   static final NotesService _shared = NotesService._sharedInstance();
//   NotesService._sharedInstance() {
//     _notesStreamController = StreamController<List<DatabaseNote>>.broadcast(
//       onListen: () {
//         _notesStreamController.sink.add(_notes);
//       },
//       onCancel: () => _notesStreamController.close(),
//     );
//   }
//   factory NotesService() => _shared;

//   late final StreamController<List<DatabaseNote>> _notesStreamController;

//   Stream<List<DatabaseNote>> get allNotes =>
//       _notesStreamController.stream.filter((note) {
//         final currentUser = _user;
//         if (currentUser != null) {
//           return note.userId == currentUser.id;
//         } else {
//           throw UserShouldBeSetBeforeReadingAllNotesException();
//         }
//       });

//   Future<void> _cacheNotes() async {
//     final allNotes = await getAllNotes();
//     _notes = allNotes.toList();
//     _notesStreamController.add(_notes);
//   }

//   Database _getDatabaseOrThrow() {
//     final Database? db = _db;
//     if (db == null) {
//       throw DatabaseIsNotOpenException();
//     }
//     return db;
//   }

//   Future<void> deleteUser({required String email}) async {
//     await _ensureDbIsOpen();
//     final Database db = _getDatabaseOrThrow();
//     final deletedCount = await db.delete(
//       userTable,
//       where: '$emailColumn = ?',
//       whereArgs: [email.toLowerCase()],
//     );
//     if (deletedCount == 0) {
//       throw CouldNotDeleteUserException();
//     }
//   }

//   Future<DatabaseUser> createUser({required String email}) async {
//     await _ensureDbIsOpen();
//     final db = _getDatabaseOrThrow();
//     final emailLower = email.toLowerCase();
//     final result = await db.query(
//       userTable,
//       limit: 1,
//       where: '$emailColumn = ?',
//       whereArgs: [emailLower],
//     );
//     if (result.isNotEmpty) {
//       throw UserAlreadyExistsException();
//     }
//     final userId = await db.insert(userTable, {emailColumn: emailLower});
//     return DatabaseUser(id: userId, email: email);
//   }

//   Future<DatabaseUser> getOrCreateUser({
//     required String email,
//     bool setAsCurrentUser = true,
//   }) async {
//     try {
//       await _ensureDbIsOpen();
//       final user = await getUser(email: email);
//       if (setAsCurrentUser) {
//         _user = user;
//       }
//       print('user $user');
//       return user;
//     } on UserNotFoundException {
//       final user = await createUser(email: email);
//       if (setAsCurrentUser) {
//         _user = user;
//       }
//       return user;
//     } catch (e) {
//       rethrow;
//     }
//   }

//   Future<DatabaseUser> getUser({required String email}) async {
//     await _ensureDbIsOpen();
//     final db = _getDatabaseOrThrow();
//     final result = await db.query(
//       userTable,
//       limit: 1,
//       where: '$emailColumn = ?',
//       whereArgs: [email.toLowerCase()],
//     );
//     if (result.isEmpty) {
//       throw UserNotFoundException();
//     }
//     return DatabaseUser.fromRow(result.first);
//   }

//   Future<DatabaseNote> createNote({required DatabaseUser owner}) async {
//     await _ensureDbIsOpen();

//     final db = _getDatabaseOrThrow();

//     final dbUser = await getUser(email: owner.email);

//     if (dbUser.id != owner.id) {
//       throw UserNotFoundException();
//     }
//     final text = '';
//     final noteId = await db.insert(noteTable, {
//       userIdColumn: owner.id,
//       textColumn: text,
//       isSyncedWithCloudColumn: 0,
//     });

//     final note = DatabaseNote(
//       id: noteId,
//       userId: owner.id,
//       text: text,
//       isSynced: false,
//     );

//     _notes.add(note);
//     _notesStreamController.add(_notes);

//     return note;
//   }

//   Future<void> deleteNote({required int id}) async {
//     await _ensureDbIsOpen();
//     final db = _getDatabaseOrThrow();
//     final deletedCount = await db.delete(
//       noteTable,
//       where: '$idColumn = ?',
//       whereArgs: [id],
//     );
//     if (deletedCount == 0) {
//       throw CouldNotDeleteNoteException();
//     }
//     _notes.removeWhere((note) => note.id == id);
//     _notesStreamController.add(_notes);
//   }

//   Future<Iterable<DatabaseNote>> getAllNotes() async {
//     await _ensureDbIsOpen();
//     final db = _getDatabaseOrThrow();
//     final notes = await db.query(noteTable);
//     if (notes.isEmpty) {
//       throw NoteNotFoundException();
//     }
//     return notes.map((note) => DatabaseNote.fromRow(note));
//   }

//   Future<DatabaseNote> updateNote({
//     required DatabaseNote note,
//     required String text,
//   }) async {
//     await _ensureDbIsOpen();
//     final db = _getDatabaseOrThrow();

//     // Check if the note exists
//     await getNote(id: note.id);

//     // update db
//     final updatedCount = await db.update(
//       noteTable,
//       {textColumn: text, isSyncedWithCloudColumn: 0},
//       where: '$idColumn = ?',
//       whereArgs: [note.id],
//     );
//     if (updatedCount == 0) {
//       throw CouldNotUpdateNoteException();
//     }
//     final updatedNote = await getNote(id: note.id);
//     _notes.removeWhere((note) => note.id == note.id);
//     _notes.add(updatedNote);
//     _notesStreamController.add(_notes);
//     return updatedNote;
//   }

//   Future<int> deleteAllNotes() async {
//     await _ensureDbIsOpen();

//     final db = _getDatabaseOrThrow();
//     final numberOfDeletions = await db.delete(noteTable);

//     _notes = [];
//     _notesStreamController.add(_notes);
//     return numberOfDeletions;
//   }

//   Future<DatabaseNote> getNote({required int id}) async {
//     await _ensureDbIsOpen();

//     final _db = _getDatabaseOrThrow();
//     final notes = await _db.query(
//       noteTable,
//       limit: 1,
//       where: '$idColumn = ?',
//       whereArgs: [id],
//     );
//     if (notes.isEmpty) {
//       throw NoteNotFoundException();
//     }
//     final note = DatabaseNote.fromRow(notes.first);
//     _notes.removeWhere((note) => note.id == id);
//     _notes.add(note);
//     _notesStreamController.add(_notes);
//     return note;
//   }

//   Future<void> _ensureDbIsOpen() async {
//     try {
//       await open();
//     } on DatabaseAlreadyOpenException {}
//   }

//   Future<void> open() async {
//     if (_db != null) {
//       throw DatabaseAlreadyOpenException();
//     }
//     try {
//       final Directory docsPath = await getApplicationDocumentsDirectory();
//       final String dbPath = join(docsPath.path, dbName);
//       final Database db = await openDatabase(dbPath);
//       _db = db;

//       await db.execute(createUserTable);
//       await db.execute(createNoteTable);

//       await _cacheNotes();
//     } on MissingPlatformDirectoryException {
//       throw UnableToGetDocumentsDirectoryException();
//     } catch (e) {
//       throw Exception('Error opening database: $e');
//     }
//   }

//   Future<void> close() async {
//     final Database? db = _db;
//     if (db == null) {
//       throw DatabaseIsNotOpenException();
//     }
//     await db.close();
//     _db = null;
//   }
// }

// @immutable
// class DatabaseUser {
//   final int id;
//   final String email;

//   const DatabaseUser({required this.id, required this.email});

//   DatabaseUser.fromRow(Map<String, Object?> map)
//     : id = map[idColumn] as int,
//       email = map[emailColumn] as String;

//   @override
//   String toString() => 'DatabaseUser{id: $id, email: $email}';

//   bool operator ==(covariant DatabaseUser other) => id == other.id;

//   @override
//   int get hashCode => id.hashCode;
// }

// @immutable
// class DatabaseNote {
//   final int id;
//   final int userId;
//   final String text;
//   final bool isSynced;

//   const DatabaseNote({
//     required this.id,
//     required this.userId,
//     required this.text,
//     required this.isSynced,
//   });

//   DatabaseNote.fromRow(Map<String, Object?> map)
//     : id = map[idColumn] as int,
//       userId = map[userIdColumn] as int,
//       text = map[textColumn] as String,
//       isSynced = (map[isSyncedWithCloudColumn] as int) == 1 ? true : false;

//   @override
//   String toString() =>
//       'DatabaseNote{id: $id, userId=$userId, isSynced: $isSynced,  text: $text}';

//   bool operator ==(covariant DatabaseNote other) => id == other.id;

//   @override
//   int get hashCode => id.hashCode;
// }

// const dbName = 'notes.db';
// const noteTable = 'note';
// const userTable = 'user';
// const idColumn = 'id';
// const emailColumn = 'email';
// const textColumn = 'text';
// const isSyncedWithCloudColumn = 'is_synced_with_cloud';
// const userIdColumn = 'user_id';

// const String createUserTable = '''
//         CREATE TABLE IF NOT EXISTS $userTable (
//           $idColumn INTEGER PRIMARY KEY AUTOINCREMENT,
//           $emailColumn TEXT NOT NULL UNIQUE
//         )
//       ''';
// const String createNoteTable = '''
//         CREATE TABLE IF NOT EXISTS $noteTable (
//           $idColumn INTEGER PRIMARY KEY AUTOINCREMENT,
//           $userIdColumn INTEGER NOT NULL,
//           $textColumn TEXT NOT NULL,
//           $isSyncedWithCloudColumn INTEGER DEFAULT 0,
//           FOREIGN KEY ($userIdColumn) REFERENCES $userTable ($idColumn)
//         )
//       ''';
