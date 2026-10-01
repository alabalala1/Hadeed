import 'package:sqflite_common/sqlite_api.dart';

import '../domain/exercise.dart';

class ExerciseRepository {
  ExerciseRepository(this.database);
  final Database database;

  Future<List<Exercise>> list({bool includeArchived = false}) async {
    final rows = await database.query(
      'exercises',
      where: includeArchived ? null : 'archived = 0',
      orderBy: 'category COLLATE NOCASE, name COLLATE NOCASE, id',
    );
    return rows.map(Exercise.fromRow).toList(growable: false);
  }

  Future<Exercise?> find(String id) async {
    final rows = await database.query(
      'exercises',
      where: 'id = ?',
      whereArgs: [id],
    );
    return rows.isEmpty ? null : Exercise.fromRow(rows.single);
  }

  Future<void> save(Exercise exercise) async {
    exercise.validate();
    await database.transaction((txn) async {
      final rows = await txn.query(
        'exercises',
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [exercise.id],
      );
      if (rows.isEmpty) {
        await txn.insert('exercises', exercise.toRow());
      } else {
        final previous = await txn.query(
          'exercises',
          where: 'id=?',
          whereArgs: [exercise.id],
        );
        if (previous.single['measurement_type'] !=
            exercise.measurementType.name) {
          final plans = await txn.rawQuery(
            'SELECT p.id FROM planned_sets p JOIN day_exercises l ON l.id=p.day_exercise_id WHERE l.exercise_id=? LIMIT 1',
            [exercise.id],
          );
          if (plans.isNotEmpty) {
            throw StateError('أزل أهداف خطط هذا التمرين قبل تغيير نوع القياس');
          }
        }
        await txn.update(
          'exercises',
          exercise.toRow(),
          where: 'id = ?',
          whereArgs: [exercise.id],
        );
      }
    });
  }

  Future<void> setArchived(String id, bool archived) async {
    final changed = await database.update(
      'exercises',
      {'archived': archived ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
    if (changed != 1) throw StateError('التمرين غير موجود');
  }
}
