import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:hadeed/core/database/app_database.dart';
import 'package:hadeed/data/backup_repository.dart';
import 'package:hadeed/data/exercise_image_store.dart';
import 'package:hadeed/data/exercise_repository.dart';
import 'package:hadeed/data/training_repository.dart';
import 'package:hadeed/data/workout_repository.dart';
import 'package:hadeed/domain/exercise.dart';
import 'package:hadeed/domain/training_plan.dart';
import 'package:hadeed/domain/workout.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

var checks = 0;
void check(bool value, String name) {
  checks++;
  if (!value) throw StateError(name);
}

Future<void> reject(Future<void> Function() f, String name) async {
  var failed = false;
  try {
    await f();
  } catch (_) {
    failed = true;
  }
  check(failed, name);
}

Future<void> main() async {
  sqfliteFfiInit();
  final factory = databaseFactoryFfiNoIsolate;
  final temp = await Directory.systemTemp.createTemp('hadeed_acceptance_');
  final path = '${temp.path}/db';
  var db = await AppDatabase.open(factory, path);
  var now = DateTime(2026, 10, 1, 18);
  var w = WorkoutRepository(db, now: () => now);
  final images = ExerciseImageStore('${temp.path}/documents');
  await File(
    images.resolve('exercise_images/test.png'),
  ).parent.create(recursive: true);
  final picture = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aX1kAAAAASUVORK5CYII=',
  );
  await File(images.resolve('exercise_images/test.png')).writeAsBytes(picture);
  try {
    check(await db.getVersion() == 3, 'schema v3');
    check(await w.needsOnboarding(), 'new installs have a choice');
    await w.onboarding(useTemplate: true);
    check(!await w.needsOnboarding(), 'onboarding persists');
    var t = TrainingRepository(db);
    var ex = ExerciseRepository(db);
    await t.saveDay('a', 'صدر');
    await t.saveDay('b', 'كارديو');
    await ex.save(
      const Exercise(
        id: 'bench',
        name: 'بنش',
        category: 'صدر',
        measurementType: MeasurementType.reps,
        imageFile: 'exercise_images/test.png',
      ),
    );
    await ex.save(
      const Exercise(
        id: 'cardio',
        name: 'كارديو',
        category: 'كارديو',
        measurementType: MeasurementType.duration,
      ),
    );
    await t.link('a', 'bench', 'link_a');
    await t.link('b', 'cardio', 'link_b');
    await t.savePlan(
      'link_a',
      sets: [
        for (var i = 0; i < 3; i++)
          PlannedSet(id: 'plan_$i', repsMin: 10, repsMax: 12),
      ],
      restSeconds: 60,
    );
    await t.savePlan(
      'link_b',
      sets: [
        const PlannedSet(
          id: 'cardio_plan',
          durationMin: 1800,
          durationMax: 2700,
        ),
      ],
      restSeconds: 60,
    );
    final id = await w.start();
    check(await w.start() == id, 'repeated start resumes');
    check(
      (await Future.wait([w.start(), w.start()])).every((x) => x == id),
      'concurrent starts are idempotent',
    );
    check(await t.currentDay() == 'a', 'start does not advance');
    var s = (await w.active())!;
    final e = s.exercises.single;
    final eid = e['id'] as String;
    final clockStart = now;
    await w.selectExercise(id, eid);
    now = now.add(const Duration(seconds: 30));
    check((await w.selectExercise(id, eid))['started'] == clockStart.millisecondsSinceEpoch, 'reselect does not reset exercise clock');
    await w.selectExercise(id, null);
    check(((await w.exerciseClock(id))['elapsed'] as Map)[eid] == 30000, 'exercise clock accrues on collapse');
    now = now.add(const Duration(seconds: 15));
    await w.selectExercise(id, eid);
    await reject(() => w.finish(id), 'empty completion rejected');
    await reject(() => w.rest(now, ''), 'active session blocks rest');
    await reject(w.resetCycle, 'active session blocks reset');
    await reject(
      () => w.saveSet(eid, 'invalid', reps: 0),
      'zero reps rejected',
    );
    await reject(
      () => w.saveSet(eid, 'invalid', reps: 10, weight: -1),
      'negative weight rejected',
    );
    await reject(
      () => w.saveSet(eid, 'invalid', duration: 20),
      'wrong measurement rejected',
    );
    await w.draft(eid, {
      'id': 'draft',
      'unit': 'kg',
      'reps': '١٠',
      'weight': '٧٫٥',
      'duration': '',
      'notes': 'مسودة',
    });
    check(
      jsonDecode(
            (await w.session(id)).exercises.single['draft_json'] as String,
          )['weight'] ==
          '٧٫٥',
      'draft stored',
    );
    await w.saveSet(eid, 'set1', reps: 10, weight: 5);
    await w.saveSet(eid, 'set1', reps: 10, weight: 5);
    await w.saveSet(eid, 'set2', reps: 10, weight: 5);
    await w.saveSet(eid, 'set3', reps: 12, weight: 7.5);
    s = await w.session(id);
    check(s.setCount == 3, 'save IDs prevent duplicates');
    check(s.volume == 190, 'independent weights and volume');
    check(s.plannedDone == 3, 'planned completion calculated');
    check(s.sets[eid]!.last['weight'] == 7.5, 'fraction preserved');
    check(s.exercises.single['draft_json'] == '{}', 'save clears draft');
    await w.deleteSet(eid, 'set2');
    s = await w.session(id);
    check(s.sets[eid]!.last['sort_order'] == 1, 'delete renumbers');
    await reject(
      () => w.finish(id),
      'partial completion requires confirmation',
    );
    await w.saveSet(eid, 'set3', reps: 11, weight: 0);
    check((await w.session(id)).setCount == 2, 'edit updates in place');
    check(
      (await w.session(id)).sets[eid]!.last['weight'] == 0,
      'bodyweight zero preserved',
    );
    await w.startTimer(eid);
    now = now.add(const Duration(seconds: 20));
    check(
      remainingSeconds((await w.timer())!, now) == 40,
      'timer uses deadline',
    );
    await w.timerAction('pause');
    now = now.add(const Duration(hours: 1));
    check(
      remainingSeconds((await w.timer())!, now) == 40,
      'pause survives time advance',
    );
    await w.timerAction('add');
    check(
      remainingSeconds((await w.timer())!, now) == 55,
      'add to paused timer',
    );
    await w.timerAction('resume');
    now = now.add(const Duration(seconds: 56));
    check(remainingSeconds((await w.timer())!, now) == 0, 'resume expiration');
    await w.timerAction('expire');
    check((await w.timer())!['status'] == 'finished', 'finished persisted');
    await w.timerAction('reset');
    check(
      remainingSeconds((await w.timer())!, now) == 75,
      'reset modified duration',
    );
    await w.timerAction('skip');
    check((await w.timer())!['status'] == 'skipped', 'skip timer');
    await w.skip(eid, 'سبب');
    check(
      (await w.session(id)).setCount == 2,
      'skip does not erase performed sets',
    );
    await w.skip(eid, '', skipped: false);
    await ex.save(
      const Exercise(
        id: 'bench',
        name: 'اسم جديد',
        category: 'صدر',
        measurementType: MeasurementType.reps,
      ),
    );
    await t.saveDay('a', 'يوم جديد');
    await t.unlink('link_a');
    s = await w.session(id);
    check(
      s.row['day_name'] == 'صدر' && s.exercises.single['name'] == 'بنش',
      'snapshot names survive edits',
    );
    check(
      s.exercises.single['image_file'] == 'exercise_images/test.png',
      'snapshot image kept',
    );
    check(
      (jsonDecode(s.exercises.single['plan_json'] as String) as List).length ==
          3,
      'snapshot plan survives unlink',
    );
    await db.close();
    db = await AppDatabase.open(factory, path);
    w = WorkoutRepository(db, now: () => now);
    t = TrainingRepository(db);
    ex = ExerciseRepository(db);
    check((await w.active())!.id == id, 'resume after reopen');
    check((await w.active())!.setCount == 2, 'performance survives reopen');
    check((await w.exerciseClock(id))['current'] == eid, 'exercise selection survives database reopen');
    check(
      (await w.active())!.elapsed(now) >= 3600,
      'session duration includes pause',
    );
    await w.finish(id, allowPartial: true);
    check((await w.exerciseClock(id))['current'] == null, 'completion stops exercise clock');
    final finishedClock = jsonEncode(await w.exerciseClock(id));
    await w.finish(id, allowPartial: true);
    check(jsonEncode(await w.exerciseClock(id)) == finishedClock, 'repeated finish preserves elapsed exercise time');
    check(await t.currentDay() == 'b', 'completion moves once');
    check(await w.timer() == null, 'completion clears timer');
    await reject(() => w.start(), 'one event per date');
    await reject(() => w.rest(now, ''), 'completed session blocks rest');
    await reject(
      () => w.saveSet(eid, 'late', reps: 10),
      'closed session rejects live writes',
    );
    await w.saveSet(eid, 'set1', reps: 9, weight: 5, correction: true);
    check(await t.currentDay() == 'b', 'correction does not move cycle');
    now = DateTime(2026, 10, 2, 18);
    await w.rest(now, 'راحة');
    await w.rest(now, 'تكرار');
    check(
      (await w.history()).where((h) => h['kind'] == 'rest').length == 1,
      'duplicate rest avoided',
    );
    check(await t.currentDay() == 'b', 'rest keeps due day');
    await reject(
      () => w.rest(DateTime(2026, 10, 3), ''),
      'future rest rejected',
    );
    await w.rest(DateTime(2026, 9, 30), 'قديم');
    check(
      (await w.history()).length == 3,
      'backdated rest accepted; missing days not synthesized',
    );
    now = DateTime(2026, 10, 3, 23, 59);
    final cardioId = await w.start();
    final cardio = (await w.active())!.exercises.single;
    await reject(
      () => w.saveSet(cardio['id'] as String, 'badcardio', reps: 10, weight: 1),
      'cardio has no reps or weight',
    );
    await w.saveSet(
      cardio['id'] as String,
      'cardioSet',
      duration: 1800,
      notes: 'سير',
    );
    now = now.add(const Duration(minutes: 5));
    check(
      (await w.active())!.row['date_local'] == '2026-10-03',
      'midnight retains start date',
    );
    await w.finish(cardioId);
    check(await t.currentDay() == 'a', 'cycle wraps');
    await t.link('a', 'bench', 'relink');
    final next = await w.start();
    final n = (await w.active())!.exercises.single;
    final previous = await w.previous(n, 'a');
    check(previous!['session_id'] == id, 'previous by ID despite rename');
    check(
      (previous['sets'] as List).length == 2,
      'all previous rounds returned',
    );
    await w.saveSet(n['id'] as String, 'abandonSet', reps: 10);
    await w.finish(next, abandon: true);
    check(await t.currentDay() == 'a', 'abandon does not advance');
    now = DateTime(2026, 10, 5, 18);
    final skipped = await w.start();
    final sk = (await w.active())!.exercises.single;
    await w.skip(sk['id'] as String, 'تخطي');
    await reject(
      () => w.finish(skipped, allowPartial: true),
      'skip alone cannot complete',
    );
    await w.finish(skipped, abandon: true);
    now = DateTime(2026, 10, 6, 18);
    final activeId = await w.start();
    final activeEx = (await w.active())!.exercises.single;
    check(
      (await w.previous(activeEx, 'a'))!['session_id'] == id,
      'abandoned/skipped sessions excluded',
    );
    await w.startTimer(activeEx['id'] as String);
    await w.saveSettings(
      const WorkoutSettings(restSeconds: 90, autoRest: true, unit: 'lb'),
    );
    await t.link('b', 'bench', 'globalRest');
    check(
      (await t.links('b')).last.restSeconds == 90,
      'global rest applied to new links',
    );
    final backup = BackupRepository(db, images, factory);
    final bytes = await backup.export();
    final preview = await backup.preview(bytes);
    check(preview.images.length == 1, 'backup includes historical image');
    await reject(
      () => backup.preview(Uint8List.fromList([1, 2, 3])),
      'corrupt backup rejected',
    );
    final root =
        jsonDecode(utf8.decode(gzip.decode(bytes))) as Map<String, dynamic>;
    final wrong = Map<String, dynamic>.from(root)..['version'] = 2;
    await reject(
      () => backup.preview(
        Uint8List.fromList(gzip.encode(utf8.encode(jsonEncode(wrong)))),
      ),
      'unsupported backup version rejected',
    );
    final missing = Map<String, dynamic>.from(root)..['images'] = {};
    await reject(
      () => backup.preview(
        Uint8List.fromList(gzip.encode(utf8.encode(jsonEncode(missing)))),
      ),
      'missing image rejected',
    );
    final bad = jsonDecode(jsonEncode(root)) as Map<String, dynamic>;
    (bad['tables']['performed_sets'] as List).first['session_exercise_id'] =
        'missing';
    await reject(
      () => backup.preview(
        Uint8List.fromList(gzip.encode(utf8.encode(jsonEncode(bad)))),
      ),
      'invalid reference rejected',
    );
    check((await w.active())!.id == activeId, 'failed previews preserve data');
    await db.execute(
      "CREATE TRIGGER reject_restore BEFORE INSERT ON exercises BEGIN SELECT RAISE(ABORT,'simulated restore failure'); END",
    );
    await reject(
      () => backup.restore(preview),
      'failed transaction rolls back restore',
    );
    check(
      (await w.active())!.id == activeId && await w.timer() != null,
      'rollback preserves session and timer',
    );
    await db.execute('DROP TRIGGER reject_restore');
    await backup.restore(preview);
    check(await w.timer() == null, 'restored backup has no timer');
    check(
      (await w.active())!.id == activeId,
      'active session restored explicitly',
    );
    final restored =
        (await w.session(id)).exercises.single['image_file'] as String;
    check(
      restored.startsWith('restored_images/'),
      'images remapped to new paths',
    );
    check(
      base64Encode(await File(images.resolve(restored)).readAsBytes()) ==
          base64Encode(picture),
      'image bytes restored',
    );
    check((await w.settings()).unit == 'lb', 'settings restored');
    check(jsonEncode(await w.exerciseClock(id)) == finishedClock, 'exercise times survive backup restore');
    check((await w.history()).length == 7, 'all calendar history restored');
    check(normalizeNumber('٧٫٥') == '7.5', 'Arabic decimal supported');
    check(
      setText({'reps': 10, 'weight': 0}).contains('0 كجم'),
      'zero weight formatted',
    );
    stdout.writeln(
      'PASS: $checks session, cycle, timer and backup acceptance checks',
    );
  } finally {
    await db.close();
    await temp.delete(recursive: true);
  }
}
