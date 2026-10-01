import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:hadeed/core/database/app_database.dart';
import 'package:hadeed/data/exercise_image_store.dart';
import 'package:hadeed/data/exercise_repository.dart';
import 'package:hadeed/domain/exercise.dart';

void check(bool condition, String message) {
  if (!condition) throw StateError(message);
}

Future<void> main() async {
  sqfliteFfiInit();
  final directory = await Directory.systemTemp.createTemp('hadeed_repository_');
  final path = '${directory.path}/test.db';
  final factory = databaseFactoryFfiNoIsolate;
  var db = await AppDatabase.open(factory, path);
  try {
    var repository = ExerciseRepository(db);
    check(
      (await repository.list()).isEmpty,
      'Must not seed unconfirmed exercises',
    );
    const exercise = Exercise(
      id: 'one',
      name: '  تمرين اختبار  ',
      category: 'صدر',
      measurementType: MeasurementType.reps,
      notes: 'ملاحظة',
    );
    await repository.save(exercise);
    await repository.save(exercise);
    await Future.wait([repository.save(exercise), repository.save(exercise)]);
    check(
      (await repository.list()).length == 1,
      'Repeated save must keep one stable id',
    );
    check(
      (await repository.find('one'))!.name == 'تمرين اختبار',
      'Names must be normalized',
    );
    await db.close();
    db = await AppDatabase.open(factory, path);
    repository = ExerciseRepository(db);
    check(
      (await repository.find('one'))!.notes == 'ملاحظة',
      'Data must survive reopening SQLite',
    );
    await repository.save(
      const Exercise(
        id: 'one',
        name: 'اسم معدل',
        category: 'كارديو',
        measurementType: MeasurementType.duration,
      ),
    );
    check(
      (await repository.find('one'))!.measurementType ==
          MeasurementType.duration,
      'Type edits must persist',
    );
    await repository.setArchived('one', true);
    check(
      (await repository.list()).isEmpty &&
          (await repository.list(includeArchived: true)).length == 1,
      'Archive must preserve the row',
    );
    await repository.setArchived('one', false);
    check(
      (await repository.list()).length == 1,
      'Restore must keep the same row',
    );
    await repository.save(
      const Exercise(
        id: 'two',
        name: 'اسم معدل',
        category: 'كارديو',
        measurementType: MeasurementType.duration,
      ),
    );
    check((await repository.list()).length == 2, 'Names are not ids');
    var rejected = false;
    try {
      await repository.save(
        const Exercise(
          id: 'invalid',
          name: ' ',
          category: 'صدر',
          measurementType: MeasurementType.reps,
        ),
      );
    } catch (_) {
      rejected = true;
    }
    check(
      rejected && (await repository.list()).length == 2,
      'Invalid saves must preserve prior data',
    );
    check(
      (await db.rawQuery('PRAGMA foreign_keys')).single.values.single == 1,
      'Foreign keys enabled',
    );
    check(
      await db.getVersion() == AppDatabase.schemaVersion,
      'Schema version persisted',
    );
    final images = ExerciseImageStore(directory.path);
    final source = File('${directory.path}/temporary.png');
    await source.writeAsBytes([1, 2, 3]);
    final relative = await images.copy(source.path);
    await source.delete();
    check(
      await File(images.resolve(relative)).exists(),
      'App copy must survive temporary image deletion',
    );
    rejected = false;
    try {
      images.resolve('../outside.png');
    } catch (_) {
      rejected = true;
    }
    check(rejected, 'Image path must stay inside documents');
    await images.delete(relative);
    check(
      !await File(images.resolve(relative)).exists(),
      'Image cleanup works',
    );
    // ignore: avoid_print
    print(
      'PASS: 14 SQLite and local-image repository checks (including concurrent saves)',
    );
  } finally {
    await db.close();
    await directory.delete(recursive: true);
  }
}
