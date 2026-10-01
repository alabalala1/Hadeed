import 'package:flutter/foundation.dart';

import '../data/exercise_repository.dart';
import '../domain/exercise.dart';

class ExerciseController extends ChangeNotifier {
  ExerciseController(this.repository, {this.onChanged});
  final ExerciseRepository repository;
  final Future<void> Function()? onChanged;
  List<Exercise> exercises = const [];
  bool busy = false;
  bool loading = true;
  String? error;

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      exercises = await repository.list(includeArchived: true);
    } catch (_) {
      error = 'تعذر تحميل المكتبة. حاول مجددًا.';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> change(Future<void> Function() action) async {
    if (busy) return false;
    busy = true;
    error = null;
    notifyListeners();
    try {
      await action();
      // Reload from SQLite, not a speculative in-memory edit.
      exercises = await repository.list(includeArchived: true);
      return true;
    } catch (e) {
      error = e is StateError
          ? e.message.toString()
          : 'تعذر حفظ التغيير. بياناتك السابقة محفوظة؛ حاول مجددًا.';
      return false;
    } finally {
      busy = false;
      notifyListeners();
      await onChanged?.call();
    }
  }
}
