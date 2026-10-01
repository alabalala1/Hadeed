import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:sqflite_common/sqlite_api.dart';
import 'package:uuid/uuid.dart';

import '../core/database/app_database.dart';
import '../domain/workout.dart';
import '../domain/training_plan.dart';
import '../domain/exercise.dart';
import 'exercise_image_store.dart';

class BackupPreview {
  BackupPreview(this.tables, this.images);
  final Map<String, List<DbRow>> tables;
  final Map<String, Uint8List> images;
  String get summary =>
      '${tables['training_days']!.length} أيام · ${tables['exercises']!.length} تمرين · ${tables['workout_sessions']!.length} جلسات · ${images.length} صور';
}

class BackupRepository {
  BackupRepository(this.db, this.images, this.factory);
  final Database db;
  final ExerciseImageStore images;
  final DatabaseFactory factory;
  static const tables = [
    'exercises',
    'training_days',
    'day_exercises',
    'planned_sets',
    'cycle_state',
    'app_meta',
    'workout_sessions',
    'session_exercises',
    'performed_sets',
    'calendar_events',
  ];
  static const limit = 64 * 1024 * 1024;
  Future<Uint8List> export() async {
    final data = await db.transaction((t) async {
      final result = <String, List<DbRow>>{};
      for (final name in tables) {
        result[name] = await t.query(name);
      }
      return result;
    });
    final pictures = <String, String>{};
    for (final row in [...data['exercises']!, ...data['session_exercises']!]) {
      final file = row['image_file'] as String?;
      if (file != null && !pictures.containsKey(file)) {
        final bytes = await File(images.resolve(file)).readAsBytes();
        pictures[file] = base64Encode(bytes);
      }
    }
    final json = utf8.encode(
      jsonEncode({
        'format': 'hadeed',
        'version': 1,
        'schema': AppDatabase.schemaVersion,
        'tables': data,
        'images': pictures,
      }),
    );
    if (json.length > limit) {
      throw StateError('النسخة أكبر من الحد المسموح 64 ميجابايت');
    }
    return Uint8List.fromList(gzip.encode(json));
  }

  Future<BackupPreview> preview(Uint8List bytes) async {
    if (bytes.length > limit) throw const FormatException('ملف كبير جدًا');
    final output = BytesBuilder(copy: false);
    await for (final chunk in Stream<List<int>>.value(
      bytes,
    ).transform(gzip.decoder)) {
      if (output.length + chunk.length > limit) {
        throw const FormatException('ملف كبير جدًا');
      }
      output.add(chunk);
    }
    final root =
        jsonDecode(utf8.decode(output.takeBytes())) as Map<String, dynamic>;
    if (root['format'] != 'hadeed' ||
        root['version'] != 1 ||
        root['schema'] != AppDatabase.schemaVersion) {
      throw const FormatException('نسخة غير مدعومة');
    }
    final raw = root['tables'] as Map<String, dynamic>;
    if (raw.length != tables.length || !tables.every(raw.containsKey)) {
      throw const FormatException('جداول ناقصة');
    }
    final data = <String, List<DbRow>>{};
    for (final name in tables) {
      data[name] = (raw[name] as List)
          .map((r) => Map<String, Object?>.from(r as Map))
          .toList();
    }
    final photos = <String, Uint8List>{};
    final pictureData = root['images'] as Map<String, dynamic>;
    for (final key in pictureData.keys) {
      images.resolve(key);
      if (!key.startsWith('exercise_images/') &&
          !key.startsWith('restored_images/')) {
        throw const FormatException('مسار غير صالح');
      }
      final decoded = base64Decode(pictureData[key] as String);
      if (decoded.isEmpty) throw const FormatException('صورة فارغة');
      photos[key] = decoded;
    }
    for (final row in [...data['exercises']!, ...data['session_exercises']!]) {
      if (row['image_file'] != null && !photos.containsKey(row['image_file'])) {
        throw const FormatException('صورة مفقودة');
      }
    }
    final temp = await Directory.systemTemp.createTemp('hadeed_validate_');
    Database? check;
    try {
      check = await AppDatabase.open(factory, p.join(temp.path, 'check.db'));
      await check.transaction((t) async {
        await t.delete('cycle_state');
        await t.delete('app_meta');
        for (final name in tables) {
          for (final row in data[name]!) {
            await t.insert(name, row);
          }
        }
      });
      if ((await check.rawQuery('PRAGMA foreign_key_check')).isNotEmpty) {
        throw const FormatException('إحالات غير صالحة');
      }
      final cycle = await check.query('cycle_state');
      if (cycle.length != 1) throw const FormatException('حالة دورة ناقصة');
      if (cycle.single['current_day_id'] != null &&
          (await check.query(
            'training_days',
            where: 'id=? AND archived=0',
            whereArgs: [cycle.single['current_day_id']],
          )).isEmpty) {
        throw const FormatException('يوم الدورة مؤرشف');
      }
      for (final e in data['session_exercises']!) {
        if ((await check.query(
          'exercises',
          where: 'id=?',
          whereArgs: [e['exercise_id']],
        )).isEmpty) {
          throw const FormatException('تعريف تمرين مفقود');
        }
        if ((await check.query(
          'training_days',
          where: 'id=?',
          whereArgs: [
            data['workout_sessions']!.firstWhere(
              (s) => s['id'] == e['session_id'],
            )['day_id'],
          ],
        )).isEmpty) {
          throw const FormatException('تعريف يوم مفقود');
        }
        for (final plan in jsonDecode(e['plan_json'] as String) as List) {
          PlannedSet.fromRow(Map<String, Object?>.from(plan as Map)).validate(
            e['measurement_type'] == 'reps'
                ? MeasurementType.reps
                : MeasurementType.duration,
          );
        }
        final draft = jsonDecode(e['draft_json'] as String) as Map;
        for (final entry in draft.entries) {
          if (![
                'id',
                'unit',
                'reps',
                'weight',
                'duration',
                'notes',
              ].contains(entry.key) ||
              entry.value is! String) {
            throw const FormatException('مسودة غير صالحة');
          }
        }
      }
      for (final s in data['workout_sessions']!) {
        s['started_at'] as int;
        if (s['ended_at'] != null) s['ended_at'] as int;
        final event = await check.query(
          'calendar_events',
          where: "session_id=? AND date_local=? AND kind='session'",
          whereArgs: [s['id'], s['date_local']],
        );
        if (event.length != 1) {
          throw const FormatException('تاريخ جلسة غير متطابق');
        }
        if (localDate(DateTime.parse(s['date_local'] as String)) !=
            s['date_local']) {
          throw const FormatException('تاريخ غير صالح');
        }
      }
      for (final event in data['calendar_events']!) {
        if (localDate(DateTime.parse(event['date_local'] as String)) !=
            event['date_local']) {
          throw const FormatException('تاريخ غير صالح');
        }
      }
      final wrong = await check.rawQuery(
        '''SELECT p.id FROM performed_sets p JOIN session_exercises e ON e.id=p.session_exercise_id
        WHERE (e.measurement_type='reps' AND (p.reps IS NULL OR typeof(p.reps)!='integer'))
          OR (e.measurement_type='duration' AND (p.duration_seconds IS NULL OR typeof(p.duration_seconds)!='integer'))''',
      );
      if (wrong.isNotEmpty) throw const FormatException('نوع أداء غير مطابق');
      final settings = await check.query(
        'app_meta',
        where: 'key=?',
        whereArgs: ['settings'],
      );
      if (settings.isNotEmpty) {
        WorkoutSettings.fromJson(
          jsonDecode(settings.single['value'] as String)
              as Map<String, dynamic>,
        );
      }
      return BackupPreview(data, photos);
    } finally {
      await check?.close();
      await temp.delete(recursive: true);
    }
  }

  Future<void> restore(BackupPreview preview) async {
    // Revalidate the exact payload to avoid trusting a caller-constructed preview.
    final safe = await this.preview(
      Uint8List.fromList(
        gzip.encode(
          utf8.encode(
            jsonEncode({
              'format': 'hadeed',
              'version': 1,
              'schema': AppDatabase.schemaVersion,
              'tables': preview.tables,
              'images': preview.images.map(
                (k, v) => MapEntry(k, base64Encode(v)),
              ),
            }),
          ),
        ),
      ),
    );
    final dir = 'restored_images/${const Uuid().v4()}';
    final staged = Directory(images.resolve(dir));
    final paths = <String, String>{};
    var committed = false;
    try {
      await staged.create(recursive: true);
      var n = 0;
      for (final image in safe.images.entries) {
        final relative = '$dir/${n++}${p.extension(image.key)}';
        await File(
          images.resolve(relative),
        ).writeAsBytes(image.value, flush: true);
        paths[image.key] = relative;
      }
      await db.transaction((t) async {
        await t.delete('timer_state');
        for (final name in tables.reversed) {
          await t.delete(name);
        }
        for (final name in tables) {
          for (final original in safe.tables[name]!) {
            final row = Map<String, Object?>.from(original);
            if (row['image_file'] != null) {
              row['image_file'] = paths[row['image_file']];
            }
            await t.insert(name, row);
          }
        }
      });
      committed = true;
    } finally {
      if (!committed && await staged.exists()) {
        await staged.delete(recursive: true);
      }
    }
  }
}
