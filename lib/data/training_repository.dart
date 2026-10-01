import 'dart:convert';

import 'package:sqflite_common/sqlite_api.dart';
import 'package:uuid/uuid.dart';

import '../domain/exercise.dart';
import '../domain/training_plan.dart';

class TrainingRepository {
  TrainingRepository(this.database);
  final Database database;
  String newId() => const Uuid().v4();

  Future<List<TrainingDay>> days({bool archived = false}) async =>
      (await database.rawQuery(
        '''
    SELECT d.*, (SELECT count(*) FROM day_exercises l JOIN exercises e ON e.id=l.exercise_id
      WHERE l.day_id=d.id AND e.archived=0) AS exercise_count
    FROM training_days d WHERE d.archived=? ORDER BY d.sort_order,d.id
  ''',
        [archived ? 1 : 0],
      )).map(TrainingDay.fromRow).toList();

  Future<String?> currentDay() async =>
      (await database.query(
            'cycle_state',
            where: 'id=1',
          )).single['current_day_id']
          as String?;
  Future<String> generalNote() async =>
      (await database.query(
            'app_meta',
            where: 'key=?',
            whereArgs: ['program_note'],
          )).firstOrNull?['value']
          as String? ??
      '';

  Future<List<DayExercise>> links(String dayId) async {
    final rows = await database.rawQuery(
      '''SELECT l.id AS link_id,l.day_id,l.sort_order AS link_order,
      l.rest_seconds,l.group_id,l.per_leg,l.notes AS link_notes,e.*
      FROM day_exercises l JOIN exercises e ON e.id=l.exercise_id
      WHERE l.day_id=? AND e.archived=0 ORDER BY l.sort_order,l.id''',
      [dayId],
    );
    final result = <DayExercise>[];
    for (final row in rows) {
      final id = row['link_id'] as String;
      result.add(
        DayExercise(
          id: id,
          dayId: dayId,
          exercise: Exercise.fromRow(row),
          order: row['link_order'] as int,
          restSeconds: row['rest_seconds'] as int,
          groupId: row['group_id'] as String?,
          perLeg: row['per_leg'] == 1,
          notes: row['link_notes'] as String,
          sets: (await database.query(
            'planned_sets',
            where: 'day_exercise_id=?',
            whereArgs: [id],
            orderBy: 'sort_order',
          )).map(PlannedSet.fromRow).toList(),
        ),
      );
    }
    return result;
  }

  Future<void> saveDay(String id, String name) async {
    if (id.isEmpty || name.trim().isEmpty) {
      throw ArgumentError('أدخل اسم اليوم');
    }
    await database.transaction((txn) async {
      final existing = await txn.query(
        'training_days',
        where: 'id=?',
        whereArgs: [id],
      );
      if (existing.isEmpty) {
        final count =
            (await txn.rawQuery(
                  'SELECT COALESCE(MAX(sort_order),-1)+1 AS n FROM training_days',
                )).single['n']
                as int;
        await txn.insert('training_days', {
          'id': id,
          'name': name.trim(),
          'sort_order': count,
        });
        if ((await txn.query('cycle_state')).single['current_day_id'] == null) {
          await _setCurrent(txn, id);
        }
      } else {
        await txn.update(
          'training_days',
          {'name': name.trim()},
          where: 'id=?',
          whereArgs: [id],
        );
      }
    });
  }

  Future<void> _setCurrent(DatabaseExecutor txn, String? id) =>
      txn.update('cycle_state', {
        'current_day_id': id,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, where: 'id=1');

  Future<void> archiveDay(String id, {String? replacement}) async {
    await database.transaction((txn) async {
      final current = (await txn.query('cycle_state')).single['current_day_id'];
      if (current == id) {
        if (replacement == null ||
            replacement == id ||
            (await txn.query(
              'training_days',
              where: 'id=? AND archived=0',
              whereArgs: [replacement],
            )).isEmpty) {
          throw StateError('اختر يومًا نشطًا بديلًا قبل أرشفة اليوم المستحق');
        }
        await _setCurrent(txn, replacement);
      }
      if (await txn.update(
            'training_days',
            {'archived': 1},
            where: 'id=? AND archived=0',
            whereArgs: [id],
          ) !=
          1) {
        throw StateError('اليوم غير موجود');
      }
    });
  }

  Future<void> restoreDay(String id) async {
    await database.transaction((txn) async {
      if (await txn.update(
            'training_days',
            {'archived': 0},
            where: 'id=? AND archived=1',
            whereArgs: [id],
          ) !=
          1) {
        throw StateError('اليوم غير موجود');
      }
      if ((await txn.query('cycle_state')).single['current_day_id'] == null) {
        await _setCurrent(txn, id);
      }
    });
  }

  Future<void> reorderDays(List<String> ids) async {
    await database.transaction((txn) async {
      final existing = (await txn.query(
        'training_days',
        columns: ['id'],
        where: 'archived=0',
      )).map((r) => r['id'] as String).toSet();
      if (ids.length != existing.length ||
          ids.toSet().length != ids.length ||
          !existing.containsAll(ids)) {
        throw StateError('الجدول تغير. أعد تحميله قبل الترتيب.');
      }
      for (var i = 0; i < ids.length; i++) {
        await txn.update(
          'training_days',
          {'sort_order': i},
          where: 'id=?',
          whereArgs: [ids[i]],
        );
      }
    });
  }

  Future<void> link(String dayId, String exerciseId, String id) async {
    await database.transaction((txn) async {
      if ((await txn.query(
        'day_exercises',
        where: 'id=?',
        whereArgs: [id],
      )).isNotEmpty) {
        return;
      }
      if ((await txn.query(
            'training_days',
            where: 'id=? AND archived=0',
            whereArgs: [dayId],
          )).isEmpty ||
          (await txn.query(
            'exercises',
            where: 'id=? AND archived=0',
            whereArgs: [exerciseId],
          )).isEmpty) {
        throw StateError('اليوم أو التمرين غير نشط');
      }
      final order =
          (await txn.rawQuery(
                'SELECT COALESCE(MAX(sort_order),-1)+1 AS n FROM day_exercises WHERE day_id=?',
                [dayId],
              )).single['n']
              as int;
      await txn.insert('day_exercises', {
        'id': id,
        'day_id': dayId,
        'exercise_id': exerciseId,
        'sort_order': order,
        'rest_seconds': await _defaultRest(txn),
      });
    });
  }

  Future<void> unlink(String id) async {
    await database.delete('day_exercises', where: 'id=?', whereArgs: [id]);
  }

  Future<int> _defaultRest(DatabaseExecutor txn) async {
    final settings = await txn.query(
      'app_meta',
      where: 'key=?',
      whereArgs: ['settings'],
    );
    return settings.isEmpty
        ? 60
        : (jsonDecode(settings.single['value'] as String)
                  as Map<String, dynamic>)['rest_seconds']
              as int;
  }

  Future<void> reorderLinks(String dayId, List<String> ids) async {
    await database.transaction((txn) async {
      final rows = await txn.rawQuery(
        'SELECT l.id FROM day_exercises l JOIN exercises e ON e.id=l.exercise_id WHERE l.day_id=? AND e.archived=0',
        [dayId],
      );
      final existing = rows.map((r) => r['id'] as String).toSet();
      if (ids.length != existing.length ||
          ids.toSet().length != ids.length ||
          !existing.containsAll(ids)) {
        throw StateError('الخطة تغيرت. أعد تحميلها قبل الترتيب.');
      }
      for (var i = 0; i < ids.length; i++) {
        await txn.update(
          'day_exercises',
          {'sort_order': i},
          where: 'id=? AND day_id=?',
          whereArgs: [ids[i], dayId],
        );
      }
    });
  }

  Future<void> savePlan(
    String linkId, {
    required List<PlannedSet> sets,
    required int restSeconds,
    String? groupId,
    bool perLeg = false,
    String notes = '',
  }) async {
    if (restSeconds <= 0) throw ArgumentError('مدة الراحة يجب أن تكون موجبة');
    if (sets.map((s) => s.id).toSet().length != sets.length) {
      throw ArgumentError('معرفات الجولات مكررة');
    }
    await database.transaction((txn) async {
      final rows = await txn.rawQuery(
        'SELECT e.measurement_type FROM day_exercises l JOIN exercises e ON e.id=l.exercise_id WHERE l.id=?',
        [linkId],
      );
      if (rows.isEmpty) throw StateError('التمرين غير مربوط');
      final type = MeasurementType.values.byName(
        rows.single['measurement_type'] as String,
      );
      for (final s in sets) {
        s.validate(type);
      }
      final group = groupId?.trim();
      final resolved = group == null || group.isEmpty ? null : group;
      await txn.update(
        'day_exercises',
        {
          'rest_seconds': restSeconds,
          'group_id': resolved,
          'group_type': resolved == null ? null : 'superset',
          'per_leg': perLeg ? 1 : 0,
          'notes': notes.trim(),
        },
        where: 'id=?',
        whereArgs: [linkId],
      );
      await txn.delete(
        'planned_sets',
        where: 'day_exercise_id=?',
        whereArgs: [linkId],
      );
      for (var i = 0; i < sets.length; i++) {
        await txn.insert('planned_sets', sets[i].toRow(linkId, i));
      }
    });
  }

  // Add this authorized user template once, atomically; never reset later edits.
  Future<void> installTemplate(Map<String, dynamic> program) async {
    final template = program['template_id'] as String;
    final data = program['days'] as List;
    await database.transaction((txn) async {
      if ((await txn.query(
        'app_meta',
        where: 'key=?',
        whereArgs: [template],
      )).isNotEmpty) {
        return;
      }
      final mapping = <String, String>{};
      final definitions = <String, Map<String, dynamic>>{};
      for (final d in data) {
        for (final raw in d['exercises'] as List) {
          final ex = Map<String, dynamic>.from(raw as Map);
          final id = ex['id'] as String;
          final method = ex['method'] as String;
          final goal = ex['goal'] as String;
          final note =
              'طريقة العمل: $method${goal.isEmpty ? '' : '\nالهدف: $goal'}';
          if (!definitions.containsKey(id)) {
            definitions[id] = {
              ...ex,
              'all_notes': <String>[note],
            };
          } else {
            final notes = definitions[id]!['all_notes'] as List<String>;
            if (!notes.contains(note)) notes.add(note);
          }
        }
      }
      for (final entry in definitions.entries) {
        final ex = entry.value;
        final type = ex.containsKey('duration_min') ? 'duration' : 'reps';
        final exact = await txn.query(
          'exercises',
          where: 'id=?',
          whereArgs: [entry.key],
        );
        if (exact.isNotEmpty) {
          mapping[entry.key] = entry.key;
          continue;
        }
        // Reuse a unique existing exact definition without rewriting its notes/images.
        final same = await txn.query(
          'exercises',
          where: 'name=? AND category=? AND measurement_type=? AND archived=0',
          whereArgs: [ex['name'], ex['category'], type],
        );
        if (same.length == 1) {
          mapping[entry.key] = same.single['id'] as String;
          continue;
        }
        mapping[entry.key] = entry.key;
        await txn.insert('exercises', {
          'id': entry.key,
          'name': ex['name'],
          'category': ex['category'],
          'measurement_type': type,
          'notes': (ex['all_notes'] as List<String>).join('\n\n'),
        });
      }
      var start =
          (await txn.rawQuery(
                'SELECT COALESCE(MAX(sort_order),-1)+1 AS n FROM training_days',
              )).single['n']
              as int;
      for (final rawDay in data) {
        final day = Map<String, dynamic>.from(rawDay as Map);
        final dayId = day['id'] as String;
        await txn.insert('training_days', {
          'id': dayId,
          'name': day['name'],
          'sort_order': start++,
        });
        final exercises = day['exercises'] as List;
        for (var i = 0; i < exercises.length; i++) {
          final ex = Map<String, dynamic>.from(exercises[i] as Map);
          final linkId = '${dayId}_link_$i';
          final group = ex['group'] as String?;
          await txn.insert('day_exercises', {
            'id': linkId,
            'day_id': dayId,
            'exercise_id': mapping[ex['id']],
            'sort_order': i,
            'rest_seconds': 60,
            'group_id': group,
            'group_type': group == null ? null : 'superset',
            'per_leg': ex['per_leg'] == true ? 1 : 0,
          });
          for (var j = 0; j < (ex['sets'] as int); j++) {
            final set = PlannedSet(
              id: '${linkId}_set_$j',
              repsMin: ex['reps_min'] as int?,
              repsMax: ex['reps_max'] as int?,
              durationMin: ex['duration_min'] as int?,
              durationMax: ex['duration_max'] as int?,
            );
            set.validate(
              ex.containsKey('duration_min')
                  ? MeasurementType.duration
                  : MeasurementType.reps,
            );
            await txn.insert('planned_sets', set.toRow(linkId, j));
          }
        }
      }
      if ((await txn.query('cycle_state')).single['current_day_id'] == null) {
        await _setCurrent(txn, (data.first as Map)['id'] as String);
      }
      await txn.insert('app_meta', {'key': template, 'value': 'installed'});
      await txn.insert('app_meta', {
        'key': 'program_note',
        'value': program['general_note'] as String,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    });
  }
}
