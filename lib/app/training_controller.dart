import 'package:flutter/foundation.dart';

import '../data/training_repository.dart';
import '../domain/training_plan.dart';

class TrainingController extends ChangeNotifier {
  TrainingController(this.repository);
  final TrainingRepository repository;
  List<TrainingDay> days = const [], archivedDays = const [];
  Map<String, List<DayExercise>> entries = const {};
  String? currentDayId, error;
  String generalNote = '';
  bool busy = false, loading = true;

  Future<void> _read() async {
    days = await repository.days();
    archivedDays = await repository.days(archived: true);
    currentDayId = await repository.currentDay();
    generalNote = await repository.generalNote();
    final links = <String, List<DayExercise>>{};
    for (final day in [...days, ...archivedDays]) {
      links[day.id] = await repository.links(day.id);
    }
    entries = links;
  }

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      await _read();
    } catch (_) {
      error = 'تعذر قراءة الجدول. حاول مجددًا.';
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
      await _read();
      return true;
    } catch (e) {
      error = e is StateError
          ? e.message.toString()
          : 'تعذر حفظ التغيير. حاول مجددًا.';
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}
