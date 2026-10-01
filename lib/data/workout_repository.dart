import 'dart:convert';

import 'package:sqflite_common/sqlite_api.dart';
import 'package:uuid/uuid.dart';

import '../domain/workout.dart';
import 'training_repository.dart';

class WorkoutRepository {
  WorkoutRepository(this.db, {DateTime Function()? now})
    : now = now ?? DateTime.now;
  final Database db;
  final DateTime Function() now;
  String newId() => const Uuid().v4();
  Future<bool> needsOnboarding() async {
    final r = await db.query(
      'app_meta',
      where: 'key=? AND value=?',
      whereArgs: ['onboarding', 'pending'],
    );
    return r.isNotEmpty;
  }

  Future<void> onboarding({required bool useTemplate}) => db.transaction((
    t,
  ) async {
    final marker = await t.query(
      'app_meta',
      where: 'key=? AND value=?',
      whereArgs: ['onboarding', 'pending'],
    );
    if (marker.isEmpty) return;
    if (!useTemplate) {
      if ((await t.query('workout_sessions')).isNotEmpty) {
        throw StateError('لا يمكن تغيير البداية بعد تسجيل جلسة');
      }
      await t.update('training_days', {'archived': 1});
      await t.update('cycle_state', {'current_day_id': null}, where: 'id=1');
    }
    await t.update(
      'app_meta',
      {'value': 'ready'},
      where: 'key=?',
      whereArgs: ['onboarding'],
    );
  });
  Future<WorkoutSettings> settings() async {
    final r = await db.query(
      'app_meta',
      where: 'key=?',
      whereArgs: ['settings'],
    );
    return r.isEmpty
        ? const WorkoutSettings()
        : WorkoutSettings.fromJson(
            jsonDecode(r.single['value'] as String) as Map<String, dynamic>,
          );
  }

  Future<void> saveSettings(WorkoutSettings value) async {
    WorkoutSettings.fromJson(value.toJson());
    await db.insert('app_meta', {
      'key': 'settings',
      'value': jsonEncode(value.toJson()),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<SessionRecord?> active() async {
    final r = await db.query('workout_sessions', where: "status='active'");
    return r.isEmpty ? null : session(r.single['id'] as String);
  }

  Future<SessionRecord> session(String id) async {
    final r = await db.query(
      'workout_sessions',
      where: 'id=?',
      whereArgs: [id],
    );
    if (r.isEmpty) throw StateError('الجلسة غير موجودة');
    final ex = await db.query(
      'session_exercises',
      where: 'session_id=?',
      whereArgs: [id],
      orderBy: 'sort_order',
    );
    final sets = <String, List<DbRow>>{};
    for (final e in ex) {
      sets[e['id'] as String] = await db.query(
        'performed_sets',
        where: 'session_exercise_id=?',
        whereArgs: [e['id']],
        orderBy: 'sort_order, saved_at, id',
      );
    }
    return SessionRecord(r.single, ex, sets);
  }

  Future<String> start() async {
    final moment = now();
    return db.transaction((t) async {
      final open = await t.query('workout_sessions', where: "status='active'");
      if (open.isNotEmpty) return open.single['id'] as String;
      final date = localDate(moment);
      if ((await t.query(
        'calendar_events',
        where: 'date_local=?',
        whereArgs: [date],
      )).isNotEmpty) {
        throw StateError('يوجد حدث مسجل لهذا التاريخ. راجعه في السجل.');
      }
      final cycle = (await t.query('cycle_state')).single['current_day_id'];
      final day = await t.query(
        'training_days',
        where: 'id=? AND archived=0',
        whereArgs: [cycle],
      );
      if (day.isEmpty) throw StateError('أضف يوم تدريب أولًا');
      final links = await t.rawQuery(
        'SELECT l.*,e.name,e.category,e.measurement_type,e.image_file,e.notes AS exercise_notes FROM day_exercises l JOIN exercises e ON e.id=l.exercise_id WHERE l.day_id=? AND e.archived=0 ORDER BY l.sort_order',
        [cycle],
      );
      if (links.isEmpty) throw StateError('أضف تمرينًا لهذا اليوم أولًا');
      final id = newId();
      await t.insert('workout_sessions', {
        'id': id,
        'day_id': cycle,
        'day_name': day.single['name'],
        'date_local': date,
        'started_at': moment.millisecondsSinceEpoch,
        'status': 'active',
      });
      await t.insert('calendar_events', {
        'date_local': date,
        'kind': 'session',
        'session_id': id,
        'day_id': cycle,
        'day_name': day.single['name'],
      });
      for (var i = 0; i < links.length; i++) {
        final l = links[i];
        final plan = await t.query(
          'planned_sets',
          where: 'day_exercise_id=?',
          whereArgs: [l['id']],
          orderBy: 'sort_order',
        );
        await t.insert('session_exercises', {
          'id': newId(),
          'session_id': id,
          'source_link_id': l['id'],
          'exercise_id': l['exercise_id'],
          'name': l['name'],
          'category': l['category'],
          'measurement_type': l['measurement_type'],
          'image_file': l['image_file'],
          'notes': '${l['exercise_notes']}\n${l['notes']}'.trim(),
          'sort_order': i,
          'plan_json': jsonEncode(plan),
          'rest_seconds': l['rest_seconds'],
          'group_id': l['group_id'],
          'per_leg': l['per_leg'],
        });
      }
      return id;
    });
  }

  Future<DbRow> _exercise(
    DatabaseExecutor t,
    String id, {
    bool correction = false,
  }) async {
    final r = await t.rawQuery(
      'SELECT e.*,s.status AS session_status FROM session_exercises e JOIN workout_sessions s ON s.id=e.session_id WHERE e.id=?',
      [id],
    );
    if (r.isEmpty) throw StateError('التمرين غير موجود');
    if (!correction && r.single['session_status'] != 'active') {
      throw StateError('الجلسة مغلقة');
    }
    if (correction && r.single['session_status'] == 'active') {
      throw StateError('عدّل الجلسة من شاشة التمرين');
    }
    return r.single;
  }

  Future<void> draft(String exerciseId, Map<String, dynamic> value) async {
    await db.transaction((t) async {
      await _exercise(t, exerciseId);
      await t.update(
        'session_exercises',
        {'draft_json': jsonEncode(value)},
        where: 'id=?',
        whereArgs: [exerciseId],
      );
    });
  }

  Future<void> saveSet(
    String exerciseId,
    String id, {
    int? reps,
    double? weight,
    int? duration,
    String notes = '',
    bool correction = false,
  }) async {
    if (id.isEmpty || (weight != null && (!weight.isFinite || weight < 0))) {
      throw ArgumentError('الوزن غير صالح');
    }
    await db.transaction((t) async {
      final e = await _exercise(t, exerciseId, correction: correction);
      if (e['measurement_type'] == 'reps'
          ? reps == null || reps <= 0 || duration != null
          : duration == null ||
                duration <= 0 ||
                reps != null ||
                weight != null) {
        throw ArgumentError('أدخل قيمة أداء موجبة وصحيحة');
      }
      final old = await t.query(
        'performed_sets',
        where: 'id=?',
        whereArgs: [id],
      );
      if (old.isNotEmpty && old.single['session_exercise_id'] != exerciseId) {
        throw StateError('معرّف الجولة مستخدم');
      }
      final count = await t.rawQuery(
        'SELECT COALESCE(MAX(sort_order),-1)+1 AS n FROM performed_sets WHERE session_exercise_id=?',
        [exerciseId],
      );
      final row = {
        'id': id,
        'session_exercise_id': exerciseId,
        'sort_order': old.isEmpty
            ? count.single['n']
            : old.single['sort_order'],
        'reps': reps,
        'weight': weight,
        'duration_seconds': duration,
        'notes': notes.trim(),
        'saved_at': now().millisecondsSinceEpoch,
      };
      if (old.isEmpty) {
        await t.insert('performed_sets', row);
      } else {
        await t.update('performed_sets', row, where: 'id=?', whereArgs: [id]);
      }
      await t.update(
        'session_exercises',
        {'skipped': 0, 'skip_reason': '', 'draft_json': '{}'},
        where: 'id=?',
        whereArgs: [exerciseId],
      );
    });
  }

  Future<void> deleteSet(
    String exerciseId,
    String id, {
    bool correction = false,
  }) => db.transaction((t) async {
    await _exercise(t, exerciseId, correction: correction);
    await t.delete(
      'performed_sets',
      where: 'id=? AND session_exercise_id=?',
      whereArgs: [id, exerciseId],
    );
    final rows = await t.query(
      'performed_sets',
      where: 'session_exercise_id=?',
      whereArgs: [exerciseId],
      orderBy: 'sort_order,saved_at,id',
    );
    for (var i = 0; i < rows.length; i++) {
      await t.update(
        'performed_sets',
        {'sort_order': i},
        where: 'id=?',
        whereArgs: [rows[i]['id']],
      );
    }
  });
  Future<void> skip(String exerciseId, String reason, {bool skipped = true}) =>
      db.transaction((t) async {
        await _exercise(t, exerciseId);
        await t.update(
          'session_exercises',
          {'skipped': skipped ? 1 : 0, 'skip_reason': reason.trim()},
          where: 'id=?',
          whereArgs: [exerciseId],
        );
      });
  Future<void> finish(
    String id, {
    bool abandon = false,
    bool allowPartial = false,
  }) => db.transaction((t) async {
    final rows = await t.query(
      'workout_sessions',
      where: 'id=?',
      whereArgs: [id],
    );
    if (rows.isEmpty) throw StateError('الجلسة غير موجودة');
    final s = rows.single;
    if (s['status'] != 'active') return;
    final ex = await t.query(
      'session_exercises',
      where: 'session_id=?',
      whereArgs: [id],
    );
    var total = 0, partial = false;
    for (final e in ex) {
      final actual = await t.query(
        'performed_sets',
        where: 'session_exercise_id=?',
        whereArgs: [e['id']],
      );
      total += actual.length;
      final targets = (jsonDecode(e['plan_json'] as String) as List).length;
      if (e['skipped'] == 1 || actual.isEmpty || actual.length < targets) {
        partial = true;
      }
    }
    if (!abandon && total == 0) {
      throw StateError('سجّل جولة أو نشاطًا قبل إنهاء الجلسة');
    }
    if (!abandon && partial && !allowPartial) {
      throw StateError('الجلسة جزئية؛ راجع الملخص وأكد الإنهاء');
    }
    final ended = now().millisecondsSinceEpoch;
    await t.update(
      'workout_sessions',
      {
        'status': abandon ? 'abandoned' : 'completed',
        'ended_at': ended < (s['started_at'] as int) ? s['started_at'] : ended,
      },
      where: 'id=?',
      whereArgs: [id],
    );
    await t.delete('timer_state', where: 'session_id=?', whereArgs: [id]);
    if (!abandon) {
      final current = (await t.query('cycle_state')).single['current_day_id'];
      if (current == s['day_id']) {
        final days = await t.query(
          'training_days',
          where: 'archived=0',
          orderBy: 'sort_order,id',
        );
        final index = days.indexWhere((d) => d['id'] == current);
        if (days.isNotEmpty) {
          await t.update('cycle_state', {
            'current_day_id': days[(index + 1) % days.length]['id'],
            'updated_at': now().toUtc().toIso8601String(),
          }, where: 'id=1');
        }
      }
    }
  });
  Future<void> rest(DateTime date, String reason) async {
    final d = localDate(date);
    if (d.compareTo(localDate(now())) > 0) {
      throw StateError('لا يمكن تسجيل راحة مستقبلية');
    }
    await db.transaction((t) async {
      if ((await t.query(
        'workout_sessions',
        where: "status='active'",
      )).isNotEmpty) {
        throw StateError('استكمل أو اترك الجلسة الجارية أولًا');
      }
      final old = await t.query(
        'calendar_events',
        where: 'date_local=?',
        whereArgs: [d],
      );
      if (old.isNotEmpty) {
        if (old.single['kind'] == 'rest') return;
        throw StateError('يوجد تدريب لهذا التاريخ');
      }
      final current = (await t.query('cycle_state')).single['current_day_id'];
      final day = await t.query(
        'training_days',
        where: 'id=?',
        whereArgs: [current],
      );
      await t.insert('calendar_events', {
        'date_local': d,
        'kind': 'rest',
        'day_id': current,
        'day_name': day.isEmpty ? 'غير محدد' : day.single['name'],
        'reason': reason.trim(),
      });
    });
  }

  Future<void> resetCycle() => db.transaction((t) async {
    if ((await t.query(
      'workout_sessions',
      where: "status='active'",
    )).isNotEmpty) {
      throw StateError('أغلق الجلسة الجارية قبل ضبط الدورة');
    }
    final days = await t.query(
      'training_days',
      where: 'archived=0',
      orderBy: 'sort_order,id',
      limit: 1,
    );
    await t.update('cycle_state', {
      'current_day_id': days.isEmpty ? null : days.single['id'],
      'updated_at': now().toUtc().toIso8601String(),
    }, where: 'id=1');
  });
  Future<DbRow?> previous(DbRow exercise, String dayId) async {
    final r = await db.rawQuery(
      '''SELECT e.id,s.id AS session_id,s.day_name,s.date_local FROM session_exercises e
      JOIN workout_sessions s ON s.id=e.session_id WHERE e.exercise_id=? AND s.status='completed'
      AND s.id!=? AND s.started_at<(SELECT started_at FROM workout_sessions WHERE id=?)
      AND EXISTS(SELECT 1 FROM performed_sets p WHERE p.session_exercise_id=e.id)
      ORDER BY CASE WHEN s.day_id=? THEN 0 ELSE 1 END,s.started_at DESC,e.sort_order LIMIT 1''',
      [
        exercise['exercise_id'],
        exercise['session_id'],
        exercise['session_id'],
        dayId,
      ],
    );
    if (r.isEmpty) return null;
    return {
      ...r.single,
      'sets': await db.query(
        'performed_sets',
        where: 'session_exercise_id=?',
        whereArgs: [r.single['id']],
        orderBy: 'sort_order,saved_at,id',
      ),
    };
  }

  Future<List<DbRow>> history() => db.rawQuery(
    '''SELECT c.*,s.status,s.started_at,s.ended_at,
    (SELECT GROUP_CONCAT(e.name,' · ') FROM session_exercises e WHERE e.session_id=s.id) AS exercise_names,
    (SELECT COUNT(*) FROM performed_sets p JOIN session_exercises e ON e.id=p.session_exercise_id WHERE e.session_id=s.id) AS set_count
    FROM calendar_events c LEFT JOIN workout_sessions s ON s.id=c.session_id ORDER BY c.date_local DESC''',
  );
  Future<DbRow?> timer() async {
    final r = await db.query('timer_state');
    return r.isEmpty ? null : r.single;
  }

  Future<void> startTimer(String exerciseId, {int? seconds}) => db.transaction((
    t,
  ) async {
    final e = await _exercise(t, exerciseId);
    final duration = seconds ?? e['rest_seconds'] as int;
    if (duration <= 0 || duration > 86400) throw ArgumentError('مدة غير صالحة');
    await t.insert('timer_state', {
      'id': 1,
      'session_id': e['session_id'],
      'session_exercise_id': exerciseId,
      'status': 'running',
      'deadline': now().millisecondsSinceEpoch + duration * 1000,
      'remaining_seconds': duration,
      'duration_seconds': duration,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  });
  Future<void> timerAction(String action) => db.transaction((t) async {
    final rows = await t.query('timer_state');
    if (rows.isEmpty) return;
    final v = Map<String, Object?>.from(rows.single);
    await _exercise(t, v['session_exercise_id'] as String);
    final left = remainingSeconds(v, now());
    switch (action) {
      case 'pause':
        v['status'] = 'paused';
        v['remaining_seconds'] = left;
        v['deadline'] = null;
      case 'resume':
        if (v['status'] != 'paused' || left == 0) return;
        v['status'] = 'running';
        v['deadline'] = now().millisecondsSinceEpoch + left * 1000;
      case 'add':
        if (!['paused', 'running'].contains(v['status'])) return;
        v['remaining_seconds'] = left + 15;
        if (v['status'] == 'running') {
          v['deadline'] = now().millisecondsSinceEpoch + (left + 15) * 1000;
        }
        v['duration_seconds'] = (v['duration_seconds'] as int) + 15;
      case 'reset':
        v['status'] = 'running';
        v['remaining_seconds'] = v['duration_seconds'];
        v['deadline'] =
            now().millisecondsSinceEpoch +
            (v['duration_seconds'] as int) * 1000;
      case 'skip':
        v['status'] = 'skipped';
        v['remaining_seconds'] = 0;
        v['deadline'] = null;
      case 'expire':
        if (v['status'] != 'running' || left > 0) return;
        v['status'] = 'finished';
        v['remaining_seconds'] = 0;
      default:
        throw ArgumentError('عملية مؤقت غير معروفة');
    }
    await t.update('timer_state', v, where: 'id=1');
  });
  Future<void> maybeAutoRest(DbRow exercise) async {
    if (!(await settings()).autoRest) return;
    if (exercise['group_id'] != null) {
      final group = await db.query(
        'session_exercises',
        where: 'session_id=? AND group_id=?',
        whereArgs: [exercise['session_id'], exercise['group_id']],
        orderBy: 'sort_order',
      );
      if (group.last['id'] != exercise['id']) return;
    }
    await startTimer(exercise['id'] as String);
  }

  TrainingRepository get training => TrainingRepository(db);
}
