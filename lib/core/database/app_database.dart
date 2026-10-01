import 'package:sqflite_common/sqlite_api.dart';

class AppDatabase {
  static const schemaVersion = 2;

  // Factory injection lets repository checks use real SQLite on the host.
  static Future<Database> open(DatabaseFactory factory, String path) =>
      factory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: schemaVersion,
          onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
          onCreate: (db, _) async {
            await createV1(db);
            await createV2(db);
          },
          onUpgrade: (db, oldVersion, newVersion) async {
            if (newVersion > schemaVersion) {
              throw StateError('ترقية غير مدعومة');
            }
            if (oldVersion < 2) await createV2(db);
          },
        ),
      );

  static Future<void> createV1(DatabaseExecutor db) async {
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
  }

  static Future<void> createV2(DatabaseExecutor db) async {
    for (final sql in [
      '''CREATE TABLE training_days (
        id TEXT PRIMARY KEY NOT NULL, name TEXT NOT NULL CHECK(length(trim(name)) > 0),
        sort_order INTEGER NOT NULL, archived INTEGER NOT NULL DEFAULT 0 CHECK(archived IN (0,1))
      )''',
      '''CREATE TABLE day_exercises (
        id TEXT PRIMARY KEY NOT NULL, day_id TEXT NOT NULL REFERENCES training_days(id),
        exercise_id TEXT NOT NULL REFERENCES exercises(id), sort_order INTEGER NOT NULL,
        rest_seconds INTEGER NOT NULL DEFAULT 60 CHECK(rest_seconds > 0),
        group_id TEXT, group_type TEXT CHECK(group_type IS NULL OR group_type = 'superset'),
        per_leg INTEGER NOT NULL DEFAULT 0 CHECK(per_leg IN (0,1)),
        notes TEXT NOT NULL DEFAULT '',
        CHECK((group_id IS NULL AND group_type IS NULL) OR (group_id IS NOT NULL AND group_type = 'superset'))
      )''',
      '''CREATE TABLE planned_sets (
        id TEXT PRIMARY KEY NOT NULL,
        day_exercise_id TEXT NOT NULL REFERENCES day_exercises(id) ON DELETE CASCADE,
        sort_order INTEGER NOT NULL, reps_min INTEGER, reps_max INTEGER,
        duration_min INTEGER, duration_max INTEGER, target_weight REAL CHECK(target_weight >= 0),
        UNIQUE(day_exercise_id, sort_order),
        CHECK(reps_min IS NULL OR reps_min > 0),
        CHECK(reps_max IS NULL OR (reps_min IS NOT NULL AND reps_max >= reps_min)),
        CHECK(duration_min IS NULL OR duration_min > 0),
        CHECK(duration_max IS NULL OR (duration_min IS NOT NULL AND duration_max >= duration_min)),
        CHECK(reps_min IS NULL OR duration_min IS NULL)
      )''',
      '''CREATE TABLE cycle_state (
        id INTEGER PRIMARY KEY CHECK(id=1), current_day_id TEXT REFERENCES training_days(id),
        updated_at TEXT NOT NULL
      )''',
      '''CREATE TABLE app_meta (key TEXT PRIMARY KEY NOT NULL, value TEXT NOT NULL)''',
      'CREATE INDEX exercises_for_day ON day_exercises(day_id, sort_order)',
      'CREATE INDEX days_for_exercise ON day_exercises(exercise_id)',
      'CREATE INDEX ordered_days ON training_days(archived, sort_order)',
    ]) {
      await db.execute(sql);
    }
    await db.insert('cycle_state', {
      'id': 1,
      'current_day_id': null,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }
}
