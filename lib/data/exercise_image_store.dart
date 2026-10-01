import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

class ExerciseImageStore {
  ExerciseImageStore(this.documentsPath);
  final String documentsPath;

  String resolve(String relative) {
    final absolute = p.normalize(p.join(documentsPath, relative));
    if (!p.isWithin(documentsPath, absolute)) {
      throw ArgumentError('مسار الصورة غير صالح');
    }
    return absolute;
  }

  Future<String> copy(String source) async {
    final relative = p.join(
      'exercise_images',
      '${const Uuid().v4()}${p.extension(source)}',
    );
    final target = File(resolve(relative));
    await target.parent.create(recursive: true);
    try {
      await File(source).copy(target.path);
      return relative;
    } catch (_) {
      if (await target.exists()) await target.delete();
      rethrow;
    }
  }

  Future<void> delete(String relative) async {
    final file = File(resolve(relative));
    if (await file.exists()) await file.delete();
  }
}
