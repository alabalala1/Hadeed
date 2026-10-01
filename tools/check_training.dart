import 'dart:convert';
import 'dart:io';

import 'package:hadeed/core/database/app_database.dart';
import 'package:hadeed/data/exercise_repository.dart';
import 'package:hadeed/data/training_repository.dart';
import 'package:hadeed/domain/exercise.dart';
import 'package:hadeed/domain/training_plan.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

var count = 0;
void check(bool condition, String message) {
  count++;
  if (!condition) throw StateError(message);
}

Future<void> reject(Future<void> Function() action, String message) async {
  var rejected = false;
  try {
    await action();
  } catch (_) {
    rejected = true;
  }
  check(rejected, message);
}

Future<void> main() async {
  sqfliteFfiInit();
  final folder = await Directory.systemTemp.createTemp('hadeed_training_');
  final factory = databaseFactoryFfiNoIsolate;
  final path = '${folder.path}/migration.db';
  var db = await factory.openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: 1,
      onCreate: (db, _) => AppDatabase.createV1(db),
    ),
  );
  await db.insert(
    'exercises',
    const Exercise(
      id: 'legacy_bench',
      name: 'بنش صدر مستوي',
      category: 'صدر',
      measurementType: MeasurementType.reps,
      notes: 'ملاحظات المستخدم',
      imageFile: 'exercise_images/existing.png',
    ).toRow(),
  );
  await db.close();
  db = await AppDatabase.open(factory, path);
  try {
    var repository = TrainingRepository(db);
    var exercises = ExerciseRepository(db);
    check(await db.getVersion() == AppDatabase.schemaVersion, 'Upgrade to v2');
    check(
      (await exercises.find('legacy_bench'))!.notes == 'ملاحظات المستخدم',
      'Upgrade preserves notes',
    );
    check(
      (await exercises.find('legacy_bench'))!.imageFile ==
          'exercise_images/existing.png',
      'Upgrade preserves image reference',
    );
    check(
      (await repository.days()).isEmpty,
      'Migration must not fabricate a program',
    );
    final program =
        jsonDecode(
              await File(
                'assets/templates/user_program_v1.json',
              ).readAsString(),
            )
            as Map<String, dynamic>;
    await repository.installTemplate(program);
    final days = await repository.days();
    check(days.length == 6, 'Six user days');
    check(
      days.map((d) => d.exerciseCount).join(',') == '10,8,6,1,6,10',
      'Exact split-superset day counts',
    );
    check(
      (await exercises.list()).length == 40,
      '40 definitions with matching legacy definition reused',
    );
    check((await db.query('day_exercises')).length == 41, '41 day links');
    check(
      (await exercises.find('user_ex_bench')) == null,
      'Do not duplicate the exact legacy definition',
    );
    check(
      (await exercises.find('legacy_bench'))!.notes == 'ملاحظات المستخدم',
      'Seed does not rewrite existing notes',
    );
    final first = await repository.links('user_day_1');
    check(
      first.first.exercise.id == 'legacy_bench',
      'Seed links to preserved definition',
    );
    check(
      first.first.sets.length == 4 &&
          first.first.sets.every(
            (s) => s.repsMin == 10 && s.repsMax == 12 && s.weight == null,
          ),
      'Preserve 4 × 10–12 without invented weights',
    );
    check(
      first[2].groupId == first[3].groupId &&
          first[2].groupId != null &&
          first[2].sets.length == 3,
      'Day 1 superset has independent component plans',
    );
    final last = await repository.links('user_day_6');
    check(
      last[3].groupId == last[4].groupId &&
          last[8].groupId == last[9].groupId &&
          last[3].groupId != last[8].groupId,
      'Two distinct day 6 supersets',
    );
    final second = await repository.links('user_day_2');
    check(
      second[6].exercise.id == last[5].exercise.id,
      'Shared triceps definition across two days',
    );
    check(
      second[6].id != last[5].id &&
          second[6].sets.first.id != last[5].sets.first.id,
      'Day plans are independent',
    );
    final cardio = (await repository.links('user_day_4')).single;
    check(
      cardio.exercise.measurementType == MeasurementType.duration &&
          cardio.sets.length == 1,
      'Cardio alternatives are one timed activity',
    );
    check(
      cardio.sets.single.durationMin == 1800 &&
          cardio.sets.single.durationMax == 2700,
      '30–45 minute range preserved',
    );
    check(
      cardio.exercise.notes.contains('الدراجة') &&
          cardio.exercise.notes.contains('الأوبتيجال'),
      'Keep all supplied cardio alternatives',
    );
    final legs = await repository.links('user_day_3');
    check(
      legs[2].perLeg &&
          legs[2].sets.length == 3 &&
          legs[2].sets.first.repsMin == 10,
      'Lunges target is per leg',
    );
    check(
      (await repository.generalNote()).contains('الإحماء'),
      'General note persisted',
    );
    final current = await repository.currentDay();
    await repository.reorderDays(days.reversed.map((d) => d.id).toList());
    check(
      await repository.currentDay() == current,
      'Reordering preserves due day identity',
    );
    await reject(
      () => repository.reorderDays([days.first.id]),
      'Reject incomplete reorder',
    );
    check(
      (await repository.days()).first.id == days.last.id,
      'Rejected reorder preserves order',
    );
    await repository.saveDay(days.first.id, 'اسم معدل');
    await repository.installTemplate(program);
    check(
      (await repository.days()).firstWhere((d) => d.id == days.first.id).name ==
          'اسم معدل',
      'Reopening template never resets renamed day',
    );
    check(
      (await db.query('day_exercises')).length == 41,
      'Repeated seed adds no links',
    );
    check(
      (await exercises.list()).length == 40,
      'Repeated seed adds no definitions',
    );
    await repository.savePlan(
      second[6].id,
      sets: const [
        PlannedSet(id: 'changed_set1', repsMin: 8, repsMax: 10, weight: 7.5),
        PlannedSet(id: 'changed_set2', repsMin: 12, repsMax: 12, weight: 0),
      ],
      restSeconds: 75,
      notes: 'خطة خاصة',
    );
    var changed = (await repository.links('user_day_2'))[6];
    check(
      changed.sets.length == 2 &&
          changed.sets.first.weight == 7.5 &&
          changed.sets.last.weight == 0,
      'Per-set fractional and zero planned weights',
    );
    check(
      changed.restSeconds == 75 && changed.notes == 'خطة خاصة',
      'Link rest and notes persisted',
    );
    check(
      (await repository.links('user_day_6'))[5].sets.length == 4,
      'Editing one day does not rewrite another',
    );
    await reject(
      () => repository.savePlan(
        changed.id,
        sets: const [PlannedSet(id: 'invalid', repsMin: 12, repsMax: 10)],
        restSeconds: 90,
      ),
      'Reject inverted ranges',
    );
    check(
      (await repository.links('user_day_2'))[6].sets.length == 2,
      'Invalid plan preserves prior sets',
    );
    await reject(
      () => repository.savePlan(
        changed.id,
        sets: [PlannedSet(id: first.first.sets.first.id, repsMin: 10)],
        restSeconds: 99,
      ),
      'Conflicting set IDs roll back transaction',
    );
    changed = (await repository.links('user_day_2'))[6];
    check(
      changed.restSeconds == 75 && changed.sets.length == 2,
      'Rollback preserves rest and planned sets',
    );
    await reject(
      () => repository.savePlan(
        changed.id,
        sets: const [PlannedSet(id: 'duration_in_reps', durationMin: 60)],
        restSeconds: 60,
      ),
      'Reject duration goals for reps',
    );
    await reject(
      () => repository.savePlan(
        cardio.id,
        sets: const [PlannedSet(id: 'reps_in_cardio', repsMin: 10, weight: 0)],
        restSeconds: 60,
      ),
      'Reject reps/weight for cardio',
    );
    await reject(
      () => repository.savePlan(cardio.id, sets: [], restSeconds: 0),
      'Reject zero rest',
    );
    await reject(
      () => exercises.save(
        Exercise(
          id: changed.exercise.id,
          name: changed.exercise.name,
          category: changed.exercise.category,
          measurementType: MeasurementType.duration,
        ),
      ),
      'Block type changes while referenced plans exist',
    );
    await repository.installTemplate(program);
    check(
      (await repository.links('user_day_2'))[6].sets.length == 2,
      'Template never resets edited plans',
    );
    await exercises.setArchived(first.first.exercise.id, true);
    check(
      (await repository.links('user_day_1')).length == 9,
      'Archived exercise excluded from active plan',
    );
    check(
      (await db.query(
        'day_exercises',
        where: 'exercise_id=?',
        whereArgs: [first.first.exercise.id],
      )).isNotEmpty,
      'Archive retains link',
    );
    await exercises.setArchived(first.first.exercise.id, false);
    check(
      (await repository.links('user_day_1')).length == 10,
      'Restore returns same plan',
    );
    await reject(
      () => repository.archiveDay(current!),
      'Require replacement for due day',
    );
    check(
      await repository.currentDay() == current,
      'Rejected archive preserves current day',
    );
    await repository.archiveDay(current!, replacement: days[1].id);
    check(
      await repository.currentDay() == days[1].id &&
          (await repository.days(archived: true)).single.id == current,
      'Archive selects explicit replacement',
    );
    await repository.restoreDay(current);
    check(
      (await repository.days()).length == 6 &&
          await repository.currentDay() == days[1].id,
      'Restore keeps chosen due day',
    );
    await repository.link(
      'user_day_2',
      first.first.exercise.id,
      'additional_link',
    );
    await repository.link(
      'user_day_2',
      first.first.exercise.id,
      'additional_link',
    );
    check(
      (await db.query(
            'day_exercises',
            where: 'id=?',
            whereArgs: ['additional_link'],
          )).length ==
          1,
      'Repeated link command is idempotent',
    );
    check(
      (await repository.links('user_day_2')).last.sets.isEmpty,
      'New link does not fabricate targets',
    );
    await repository.savePlan(
      'additional_link',
      sets: const [PlannedSet(id: 'additional_set', repsMin: 5, repsMax: 6)],
      restSeconds: 60,
    );
    await repository.unlink('additional_link');
    check(
      (await db.query(
        'planned_sets',
        where: 'id=?',
        whereArgs: ['additional_set'],
      )).isEmpty,
      'Unlink cascades only its plan',
    );
    check(
      await exercises.find(first.first.exercise.id) != null,
      'Unlink retains shared definition',
    );
    final original = await repository.links('user_day_3');
    await repository.reorderLinks(
      'user_day_3',
      original.reversed.map((l) => l.id).toList(),
    );
    check(
      (await repository.links('user_day_3')).first.id == original.last.id,
      'Exercise ordering persists',
    );
    await db.close();
    db = await AppDatabase.open(factory, path);
    repository = TrainingRepository(db);
    exercises = ExerciseRepository(db);
    check(
      (await repository.links('user_day_2'))[6].sets.first.weight == 7.5,
      'Goals survive process-style reopen',
    );
    check(
      await repository.currentDay() == days[1].id,
      'Due day survives reopening',
    );
    check(
      normalizeNumber('٧٫٥') == '7.5' && normalizeNumber('۱۲') == '12',
      'Arabic/Persian numeric input',
    );
    // ignore: avoid_print
    print('PASS: $count migration, template and training-plan checks');
  } finally {
    await db.close();
    await folder.delete(recursive: true);
  }
}
