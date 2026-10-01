import 'exercise.dart';

class TrainingDay {
  const TrainingDay({
    required this.id,
    required this.name,
    required this.order,
    required this.archived,
    this.exerciseCount = 0,
  });
  final String id, name;
  final int order, exerciseCount;
  final bool archived;
  factory TrainingDay.fromRow(Map<String, Object?> row) => TrainingDay(
    id: row['id'] as String,
    name: row['name'] as String,
    order: row['sort_order'] as int,
    archived: row['archived'] == 1,
    exerciseCount: (row['exercise_count'] as int?) ?? 0,
  );
}

class PlannedSet {
  const PlannedSet({
    required this.id,
    this.repsMin,
    this.repsMax,
    this.durationMin,
    this.durationMax,
    this.weight,
  });
  final String id;
  final int? repsMin, repsMax, durationMin, durationMax;
  final double? weight;
  factory PlannedSet.fromRow(Map<String, Object?> row) => PlannedSet(
    id: row['id'] as String,
    repsMin: row['reps_min'] as int?,
    repsMax: row['reps_max'] as int?,
    durationMin: row['duration_min'] as int?,
    durationMax: row['duration_max'] as int?,
    weight: (row['target_weight'] as num?)?.toDouble(),
  );
  Map<String, Object?> toRow(String linkId, int order) => {
    'id': id,
    'day_exercise_id': linkId,
    'sort_order': order,
    'reps_min': repsMin,
    'reps_max': repsMax,
    'duration_min': durationMin,
    'duration_max': durationMax,
    'target_weight': weight,
  };
  void validate(MeasurementType type) {
    bool range(int? lo, int? hi) =>
        (lo == null && hi == null) ||
        (lo != null && lo > 0 && (hi == null || hi >= lo));
    if (id.isEmpty ||
        !range(repsMin, repsMax) ||
        !range(durationMin, durationMax) ||
        (weight != null && (!weight!.isFinite || weight! < 0))) {
      throw ArgumentError('أهداف الجولة غير صالحة');
    }
    if (type == MeasurementType.reps &&
        (durationMin != null || durationMax != null)) {
      throw ArgumentError('تمرين العدات لا يقبل هدف مدة');
    }
    if (type == MeasurementType.duration &&
        (repsMin != null || repsMax != null || weight != null)) {
      throw ArgumentError('تمرين المدة لا يقبل وزنًا أو عدات');
    }
  }

  String describe(MeasurementType type) {
    String range(int? lo, int? hi, String unit) => lo == null
        ? 'الهدف غير محدد'
        : '$lo${hi != null && hi != lo ? '–$hi' : ''} $unit';
    if (type == MeasurementType.duration) {
      return durationMin == null
          ? 'المدة غير محددة'
          : '${_minutes(durationMin!)}${durationMax != null && durationMax != durationMin ? '–${_minutes(durationMax!)}' : ''} دقيقة';
    }
    return '${range(repsMin, repsMax, 'عدة')}${weight == null ? '' : ' · $weight كجم'}';
  }

  String _minutes(int seconds) => seconds % 60 == 0
      ? '${seconds ~/ 60}'
      : (seconds / 60).toStringAsFixed(2);
}

class DayExercise {
  const DayExercise({
    required this.id,
    required this.dayId,
    required this.exercise,
    required this.order,
    required this.restSeconds,
    required this.sets,
    this.groupId,
    this.perLeg = false,
    this.notes = '',
  });
  final String id, dayId, notes;
  final Exercise exercise;
  final int order, restSeconds;
  final List<PlannedSet> sets;
  final String? groupId;
  final bool perLeg;
  String get summary {
    final targets = sets
        .map((s) => s.describe(exercise.measurementType))
        .toSet();
    final plan = sets.isEmpty
        ? 'الخطة غير محددة'
        : targets.length == 1
        ? '${sets.length} جولات × ${targets.single}'
        : '${sets.length} جولات بأهداف مختلفة';
    return '$plan${perLeg ? ' لكل رجل' : ''} · راحة $restSeconds ثانية${groupId == null ? '' : ' بعد المجموعة'}';
  }
}

String normalizeNumber(String input) {
  const digits = '٠١٢٣٤٥٦٧٨٩';
  const persian = '۰۱۲۳۴۵۶۷۸۹';
  var result = input.trim().replaceAll('٫', '.');
  for (var i = 0; i < 10; i++) {
    result = result.replaceAll(digits[i], '$i').replaceAll(persian[i], '$i');
  }
  return result;
}
