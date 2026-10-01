import 'package:sqflite_common/sqlite_api.dart';

class AppDatabase {
  static const schemaVersion = 1;

  // Factory injection lets repository checks use real SQLite on the host.
  static Future<Database> open(
    DatabaseFactory factory,
    String path,
  ) => factory.openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: schemaVersion,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, _) async {
        await db.execute('''
              CREATE TABLE exercises (
                id TEXT PRIMARY KEY NOT NULL,
                name TEXT NOT NULL CHECK(length(trim(name)) > 0),
                category TEXT NOT NULL CHECK(length(trim(category)) > 0),
                measurement_type TEXT NOT NULL
                  CHECK(measurement_type IN ('reps', 'duration')),
                image_file TEXT,
                notes TEXT NOT NULL DEFAULT '',
                archived INTEGER NOT NULL DEFAULT 0 CHECK(archived IN (0, 1))
              )
            ''');
        await db.execute(
          'CREATE INDEX active_exercises ON exercises(archived, category, name)',
        );
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // Never erase an unsupported schema or a user's data.
        throw StateError(
          'ترقية قاعدة البيانات غير مدعومة: $oldVersion → $newVersion',
        );
      },
    ),
  );
}
