import 'package:sqflite_common/sqlite_api.dart';

class AppDatabase {
  static const schemaVersion = 3;

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
            await createV3(db);
            await db.insert('app_meta', {
              'key': 'onboarding',
              'value': 'pending',
            });
          },
          onUpgrade: (db, oldVersion, newVersion) async {
            if (newVersion > schemaVersion) {
              throw StateError('ترقية غير مدعومة');
            }
            if (oldVersion < 2) await createV2(db);
            if (oldVersion < 3) await createV3(db);
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

  static Future<void> createV3(DatabaseExecutor db) async {
    for (final sql in [
      '''CREATE TABLE workout_sessions (
        id TEXT PRIMARY KEY NOT NULL, day_id TEXT NOT NULL,
        day_name TEXT NOT NULL, date_local TEXT NOT NULL UNIQUE,
        started_at INTEGER NOT NULL, ended_at INTEGER,
        status TEXT NOT NULL CHECK(status IN ('active','completed','abandoned')),
        CHECK((status='active' AND ended_at IS NULL) OR (status!='active' AND ended_at>=started_at))
      )''',
      "CREATE UNIQUE INDEX one_active_session ON workout_sessions(status) WHERE status='active'",
      '''CREATE TABLE session_exercises (
        id TEXT PRIMARY KEY NOT NULL, session_id TEXT NOT NULL REFERENCES workout_sessions(id) ON DELETE CASCADE,
        source_link_id TEXT NOT NULL, exercise_id TEXT NOT NULL, name TEXT NOT NULL,
        category TEXT NOT NULL, measurement_type TEXT NOT NULL CHECK(measurement_type IN ('reps','duration')),
        image_file TEXT, notes TEXT NOT NULL, sort_order INTEGER NOT NULL,
        plan_json TEXT NOT NULL, rest_seconds INTEGER NOT NULL CHECK(rest_seconds>0),
        group_id TEXT, per_leg INTEGER NOT NULL CHECK(per_leg IN (0,1)),
        skipped INTEGER NOT NULL DEFAULT 0 CHECK(skipped IN (0,1)),
        skip_reason TEXT NOT NULL DEFAULT '', draft_json TEXT NOT NULL DEFAULT '{}',
        UNIQUE(session_id,sort_order)
      )''',
      '''CREATE TABLE performed_sets (
        id TEXT PRIMARY KEY NOT NULL, session_exercise_id TEXT NOT NULL REFERENCES session_exercises(id) ON DELETE CASCADE,
        sort_order INTEGER NOT NULL, reps INTEGER CHECK(reps>0), weight REAL CHECK(weight>=0),
        duration_seconds INTEGER CHECK(duration_seconds>0), notes TEXT NOT NULL DEFAULT '',
        saved_at INTEGER NOT NULL,
        CHECK((reps IS NOT NULL AND duration_seconds IS NULL) OR
          (duration_seconds IS NOT NULL AND reps IS NULL AND weight IS NULL))
      )''',
      '''CREATE TABLE calendar_events (
        date_local TEXT PRIMARY KEY NOT NULL, kind TEXT NOT NULL CHECK(kind IN ('rest','session')),
        session_id TEXT UNIQUE REFERENCES workout_sessions(id), day_id TEXT,
        day_name TEXT NOT NULL, reason TEXT NOT NULL DEFAULT '',
        CHECK((kind='rest' AND session_id IS NULL) OR (kind='session' AND session_id IS NOT NULL))
      )''',
      '''CREATE TABLE timer_state (
        id INTEGER PRIMARY KEY CHECK(id=1), session_id TEXT NOT NULL REFERENCES workout_sessions(id),
        session_exercise_id TEXT NOT NULL REFERENCES session_exercises(id),
        status TEXT NOT NULL CHECK(status IN ('running','paused','finished','skipped')),
        deadline INTEGER, remaining_seconds INTEGER NOT NULL CHECK(remaining_seconds>=0),
        duration_seconds INTEGER NOT NULL CHECK(duration_seconds>0)
      )''',
      'CREATE INDEX session_history ON workout_sessions(status,started_at)',
      'CREATE INDEX previous_exercise ON session_exercises(exercise_id,session_id)',
      'CREATE INDEX actual_sets ON performed_sets(session_exercise_id,sort_order)',
    ]) {
      await db.execute(sql);
    }
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
